-- Место гостя, которого хост так и не увидел (ADR 0028).
--
-- Прежде место гостя держалось до конца жизни комнаты (ADR 0025). Если гость занял его вызовом join_room, а войти в
-- канал комнаты не смог (сеть оборвалась, приложение закрыли), хост о нём не узнавал, и другой телефон получал full
-- до самого срока комнаты. Теперь хост подтверждает гостя (confirm_guest), когда получает от него первый кадр. Место
-- гостя, которого хост не подтвердил, можно занять через минуту после его входа. Подтверждённое место по-прежнему
-- держится до конца жизни комнаты, поэтому канал не переходит от одного живого гостя к другому.
--
-- Работает только для комнат хостов с протоколом 2 и новее: прежние сборки подтверждать гостя не умеют, и живого
-- гостя у них заняли бы посреди партии.

alter table public.rooms
  -- Когда гость занял место (join_room); null у комнат без гостя и у комнат, созданных до этой миграции.
  add column guest_joined_at timestamptz,
  -- Когда хост подтвердил гостя (confirm_guest); null, пока хост его не видел.
  add column guest_seen_at timestamptz;

-- Можно ли отдать место гостя другому игроку: хост гостя не видел, а с его входа прошла минута.
create function private.guest_seat_free(p_room public.rooms) returns boolean
language sql stable
set search_path = ''
as $$
  select coalesce(
    p_room.protocol >= 2
      and p_room.guest_seen_at is null
      and p_room.guest_joined_at <= now() - interval '1 minute',
    false
  );
$$;

-- Занимает место гостя по коду. Всё как в ADR 0025, кроме одного: место гостя, которого хост не подтвердил,
-- через минуту после его входа переходит новому гостю. Отказы: not_found, own_room, full, closed, too_many_attempts.
create or replace function public.join_room(p_code text) returns jsonb
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
  if v_room.guest_uid is not null and not private.guest_seat_free(v_room) then
    return private.refuse('full');
  end if;
  if not v_room.open then
    return private.refuse('closed');
  end if;

  -- Срок комнаты с гостем отсчитывается от первого гостя: сменой гостей его не продлить.
  update public.rooms
     set guest_uid = v_uid,
         guest_joined_at = now(),
         guest_seen_at = null,
         expires_at = case when v_room.guest_uid is null then now() + interval '6 hours' else v_room.expires_at end
   where id = v_room.id
   returning * into v_room;

  return jsonb_build_object('ok', true, 'room', private.room_json(v_room));
end;
$$;

-- Хост подтверждает, что гость вошёл в канал и прислал первый кадр: место гостя больше никому не отдаётся.
-- Повторный вызов ничего не меняет. Отказ: not_found (нет такой комнаты у хоста или в ней нет гостя).
create function public.confirm_guest(p_room_id uuid) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  perform private.expire_rooms();
  update public.rooms set guest_seen_at = coalesce(guest_seen_at, now())
   where id = p_room_id and host_uid = v_uid and closed_at is null and guest_uid is not null;
  if not found then
    return private.refuse('not_found');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function private.guest_seat_free(public.rooms) from public, anon, authenticated;
revoke all on function public.confirm_guest(uuid) from public, anon, authenticated;
grant execute on function public.confirm_guest(uuid) to authenticated;
