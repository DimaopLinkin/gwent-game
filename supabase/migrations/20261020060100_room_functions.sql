-- Функции комнат (ADR 0025). Клиент меняет комнаты только ими: прямых прав на запись в public.rooms нет.
--
-- Все функции security definer с пустым search_path, исполнять их может только authenticated (анонимный вход
-- Supabase). Ожидаемые отказы (нет такой комнаты, занято) возвращаются как {"ok": false, "reason": "..."}, а не
-- исключением: иначе откатилась бы запись неудачной попытки в журнал лимитов. Исключения остаются для ошибок
-- клиента: нет входа (28000) и неверные параметры (22023).
--
-- Лимиты против злоупотреблений (репозиторий открыт, ключ публичный):
--   * у игрока одна живая комната-хост и одна живая комната-гость;
--   * не больше 20 созданий комнаты в час;
--   * не больше 8 неверных кодов за 10 минут;
--   * комната без гостя живёт 30 минут, с гостем 6 часов.

-- Игрок из JWT или исключение 28000.
create function private.require_user() returns uuid
language plpgsql stable
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return v_uid;
end;
$$;

-- Код комнаты: 6 символов из 32, каждый из пяти младших бит случайного байта (без смещения).
-- Первые шесть байт gen_random_uuid() целиком случайны (версия и вариант лежат в байтах 6 и 8).
create function private.new_room_code() returns text
language plpgsql volatile
set search_path = ''
as $$
declare
  c_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes bytea := uuid_send(gen_random_uuid());
  v_code text := '';
begin
  for i in 0..5 loop
    v_code := v_code || substr(c_alphabet, (get_byte(v_bytes, i) & 31) + 1, 1);
  end loop;
  return v_code;
end;
$$;

-- Закрывает комнаты, у которых вышел срок.
create function private.expire_rooms() returns void
language sql
set search_path = ''
as $$
  update public.rooms
     set open = false, closed_at = now()
   where closed_at is null and expires_at <= now();
$$;

-- Комната для ответа клиенту. Для гостя в ответе то же, что для хоста: код он и так знает.
create function private.room_json(p_room public.rooms) returns jsonb
language sql immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_room.id,
    'code', p_room.code,
    'host_name', p_room.host_name,
    'protocol', p_room.protocol,
    'ruleset_id', p_room.ruleset_id,
    'ruleset_hash', p_room.ruleset_hash,
    'engine_version', p_room.engine_version,
    'open', p_room.open,
    'expires_at', p_room.expires_at
  );
$$;

create function private.refuse(p_reason text) returns jsonb
language sql immutable
set search_path = ''
as $$
  select jsonb_build_object('ok', false, 'reason', p_reason);
$$;

-- Создаёт комнату хоста и возвращает её с кодом. Прежняя живая комната хоста закрывается.
-- Отказ: too_many_rooms (больше 20 созданий за час).
create function public.create_room(
  p_host_name text,
  p_protocol integer,
  p_ruleset_id text,
  p_ruleset_hash text,
  p_engine_version integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_name text := btrim(coalesce(p_host_name, ''));
  v_room public.rooms;
begin
  if char_length(v_name) not between 1 and 64
     or p_protocol is null or p_protocol not between 1 and 32767
     or p_ruleset_id is null or char_length(p_ruleset_id) not between 1 and 64
     or p_ruleset_hash is null or char_length(p_ruleset_hash) not between 1 and 128
     or p_engine_version is null or p_engine_version not between 0 and 32767 then
    raise exception 'invalid_room' using errcode = '22023';
  end if;

  -- Вызовы одного игрока идут по очереди: иначе два create_room разом пройдут проверку лимита.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  -- Уборка: закрытые час назад комнаты и старые записи журнала.
  perform private.expire_rooms();
  delete from public.rooms where closed_at < now() - interval '1 hour';
  delete from private.attempts where at < now() - interval '1 day';

  if (select count(*) from private.attempts
       where uid = v_uid and kind = 'create_room' and at > now() - interval '1 hour') >= 20 then
    return private.refuse('too_many_rooms');
  end if;
  insert into private.attempts (uid, kind) values (v_uid, 'create_room');

  update public.rooms set open = false, closed_at = now()
   where host_uid = v_uid and closed_at is null;

  -- Коды случайные, повтор живого кода почти невозможен (32^6 ≈ 10^9), но на всякий случай пробуем снова.
  for i in 1..20 loop
    begin
      insert into public.rooms (code, host_uid, host_name, protocol, ruleset_id, ruleset_hash, engine_version)
      values (private.new_room_code(), v_uid, v_name, p_protocol, p_ruleset_id, p_ruleset_hash, p_engine_version)
      returning * into v_room;
      exit;
    exception when unique_violation then
      v_room := null;
    end;
  end loop;
  if v_room.id is null then
    raise exception 'code_unavailable' using errcode = '53000';
  end if;

  return jsonb_build_object('ok', true, 'room', private.room_json(v_room));
end;
$$;

-- Занимает место гостя по коду. Код принимается в любом регистре, пробелы и дефисы игнорируются.
-- Тот, кто уже гость этой комнаты, получает её снова (возвращение после обрыва) даже при open = false.
-- Отказы: not_found (нет живой комнаты с таким кодом), own_room, full (место занято другим гостем),
-- closed (хост не принимает гостей), too_many_attempts (8 неверных кодов за 10 минут).
-- Если игрок был гостем другой живой комнаты, он уходит из неё.
create function public.join_room(p_code text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_code text := upper(regexp_replace(coalesce(p_code, ''), '[\s-]', '', 'g'));
  v_room public.rooms;
begin
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));
  perform private.expire_rooms();

  if (select count(*) from private.attempts
       where uid = v_uid and kind = 'join_failure' and at > now() - interval '10 minutes') >= 8 then
    return private.refuse('too_many_attempts');
  end if;

  select * into v_room from public.rooms where code = v_code and closed_at is null for update;
  if not found then
    insert into private.attempts (uid, kind) values (v_uid, 'join_failure');
    return private.refuse('not_found');
  end if;

  if v_room.host_uid = v_uid then
    return private.refuse('own_room');
  end if;
  if v_room.guest_uid = v_uid then
    return jsonb_build_object('ok', true, 'room', private.room_json(v_room));
  end if;
  if v_room.guest_uid is not null then
    return private.refuse('full');
  end if;
  if not v_room.open then
    return private.refuse('closed');
  end if;

  update public.rooms set guest_uid = null, expires_at = now() + interval '30 minutes'
   where guest_uid = v_uid and closed_at is null;

  update public.rooms set guest_uid = v_uid, expires_at = now() + interval '6 hours'
   where id = v_room.id
   returning * into v_room;

  return jsonb_build_object('ok', true, 'room', private.room_json(v_room));
end;
$$;

-- Хост открывает или закрывает приём гостей (GameAd.open, ADR 0007). Отказ: not_found (нет такой комнаты у хоста).
create function public.set_room_open(p_room_id uuid, p_open boolean) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_room public.rooms;
begin
  perform private.expire_rooms();
  update public.rooms set open = coalesce(p_open, false)
   where id = p_room_id and host_uid = v_uid and closed_at is null
   returning * into v_room;
  if not found then
    return private.refuse('not_found');
  end if;
  return jsonb_build_object('ok', true, 'room', private.room_json(v_room));
end;
$$;

-- Хост освобождает место гостя. Гость теряет доступ к каналу комнаты при следующей проверке Realtime
-- (вход в канал и обновление токена); хост разрывает его соединение протоколом сам. Отказ: not_found.
create function public.kick_guest(p_room_id uuid) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_room public.rooms;
begin
  perform private.expire_rooms();
  update public.rooms set guest_uid = null, expires_at = now() + interval '30 minutes'
   where id = p_room_id and host_uid = v_uid and closed_at is null
   returning * into v_room;
  if not found then
    return private.refuse('not_found');
  end if;
  return jsonb_build_object('ok', true, 'room', private.room_json(v_room));
end;
$$;

-- Гость уходит из комнаты. Отказ: not_found (он не гость живой комнаты).
create function public.leave_room(p_room_id uuid) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_room public.rooms;
begin
  perform private.expire_rooms();
  update public.rooms set guest_uid = null, expires_at = now() + interval '30 minutes'
   where id = p_room_id and guest_uid = v_uid and closed_at is null
   returning * into v_room;
  if not found then
    return private.refuse('not_found');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Хост закрывает комнату. Повторное закрытие и чужая комната дают not_found.
create function public.close_room(p_room_id uuid) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  update public.rooms set open = false, closed_at = now()
   where id = p_room_id and host_uid = v_uid and closed_at is null;
  if not found then
    return private.refuse('not_found');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Права: Supabase по умолчанию выдаёт ролям Data API исполнение новых функций, а PostgreSQL выдаёт его PUBLIC.
revoke all on function private.require_user() from public, anon, authenticated;
revoke all on function private.new_room_code() from public, anon, authenticated;
revoke all on function private.expire_rooms() from public, anon, authenticated;
revoke all on function private.room_json(public.rooms) from public, anon, authenticated;
revoke all on function private.refuse(text) from public, anon, authenticated;

revoke all on function public.create_room(text, integer, text, text, integer) from public, anon, authenticated;
revoke all on function public.join_room(text) from public, anon, authenticated;
revoke all on function public.set_room_open(uuid, boolean) from public, anon, authenticated;
revoke all on function public.kick_guest(uuid) from public, anon, authenticated;
revoke all on function public.leave_room(uuid) from public, anon, authenticated;
revoke all on function public.close_room(uuid) from public, anon, authenticated;

grant execute on function public.create_room(text, integer, text, text, integer) to authenticated;
grant execute on function public.join_room(text) to authenticated;
grant execute on function public.set_room_open(uuid, boolean) to authenticated;
grant execute on function public.kick_guest(uuid) to authenticated;
grant execute on function public.leave_room(uuid) to authenticated;
grant execute on function public.close_room(uuid) to authenticated;
