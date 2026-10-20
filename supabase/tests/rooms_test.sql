-- Тесты политик и функций комнат (supabase/migrations), см. tools/scripts/test_supabase.sh.
-- Проверка идёт от лица ролей Data API: t.login(uid) входит как authenticated, t.logout() как anon.
-- Каждый сценарий в своей транзакции с откатом. Первая неудачная проверка роняет прогон.

\set ON_ERROR_STOP on
set client_min_messages = notice;

create schema t;
grant usage on schema t to public;

create function t.ok(p_cond boolean, p_label text) returns void
language plpgsql as $$
begin
  if p_cond is not true then
    raise exception 'FAIL: %', p_label;
  end if;
  raise notice 'ok - %', p_label;
end;
$$;

-- Новый игрок (как после signInAnonymously). Выполняется с правами владельца, из любой роли.
create function t.new_user() returns uuid
language sql security definer as $$
  insert into auth.users default values returning id
$$;

-- Произвольный SQL с правами владельца: подготовка и проверка состояния из-под роли игрока.
create function t.admin(p_sql text) returns void
language plpgsql security definer as $$
begin
  execute p_sql;
end;
$$;

create function t.admin_int(p_sql text) returns bigint
language plpgsql security definer as $$
declare
  v bigint;
begin
  execute p_sql into v;
  return v;
end;
$$;

create function t.login(p_uid uuid) returns void
language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;

-- Роль authenticated без игрока в токене.
create function t.login_nobody() returns void
language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '{"role":"authenticated"}', true);
  execute 'set local role authenticated';
end;
$$;

create function t.logout() returns void
language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  execute 'set local role anon';
end;
$$;

create function t.topic(p_room uuid) returns void
language plpgsql as $$
begin
  perform set_config('realtime.topic', 'room:' || p_room::text, true);
end;
$$;

-- Выполняет p_sql и проверяет, что он упал с кодом p_state (SQLSTATE).
create function t.throws(p_sql text, p_state text, p_label text) returns void
language plpgsql as $$
declare
  v_state text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    perform t.ok(v_state = p_state, p_label || ' (' || v_state || ')');
    return;
  end;
  raise exception 'FAIL: % (ошибки не было)', p_label;
end;
$$;

create function t.create_room(p_name text default 'Алиса') returns jsonb
language sql as $$
  select public.create_room(p_name, 1, 'standard', 'hash0', 1)
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- Права и RLS
-- ---------------------------------------------------------------------------------------------------------------
begin;
do $$
declare
  v_host uuid := t.new_user();
begin
  perform t.ok((select relrowsecurity from pg_class where oid = 'public.rooms'::regclass), 'RLS на public.rooms включён');

  perform t.logout();
  perform t.throws('select * from public.rooms', '42501', 'anon не читает rooms');
  perform t.throws('select public.create_room(''A'', 1, ''r'', ''h'', 1)', '42501', 'anon не вызывает create_room');
  perform t.throws('select public.join_room(''ABCDEF'')', '42501', 'anon не вызывает join_room');
  perform t.throws('select public.set_room_open(gen_random_uuid(), true)', '42501', 'anon не вызывает set_room_open');
  perform t.throws('select public.kick_guest(gen_random_uuid())', '42501', 'anon не вызывает kick_guest');
  perform t.throws('select public.leave_room(gen_random_uuid())', '42501', 'anon не вызывает leave_room');
  perform t.throws('select public.close_room(gen_random_uuid())', '42501', 'anon не вызывает close_room');

  perform t.login(v_host);
  perform t.throws(
    'insert into public.rooms (code, host_uid, host_name, protocol, ruleset_id, ruleset_hash, engine_version)
     values (''ABCDEF'', ''' || v_host || ''', ''x'', 1, ''r'', ''h'', 1)',
    '42501', 'authenticated не вставляет в rooms');
  perform t.throws('update public.rooms set open = true', '42501', 'authenticated не обновляет rooms');
  perform t.throws('delete from public.rooms', '42501', 'authenticated не удаляет из rooms');
  perform t.throws('select * from private.attempts', '42501', 'authenticated не читает журнал лимитов');
  perform t.throws('select private.new_room_code()', '42501', 'authenticated не вызывает private-функции');
end
$$;
rollback;

-- ---------------------------------------------------------------------------------------------------------------
-- create_room
-- ---------------------------------------------------------------------------------------------------------------
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_first jsonb;
  v_second jsonb;
begin
  perform t.login_nobody();
  perform t.throws('select t.create_room()', '28000', 'без входа create_room отказывает');

  perform t.login(v_host);
  v_first := t.create_room('  Алиса  ');
  perform t.ok((v_first ->> 'ok')::boolean, 'create_room: ok');
  perform t.ok(v_first -> 'room' ->> 'code' ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ2-9]{6}$', 'код: 6 символов без 0, 1, I, O');
  perform t.ok(v_first -> 'room' ->> 'host_name' = 'Алиса', 'имя хоста обрезано по краям');
  perform t.ok((v_first -> 'room' ->> 'open')::boolean, 'комната открыта');
  perform t.ok(
    (v_first -> 'room' ->> 'expires_at')::timestamptz between now() + interval '29 minutes' and now() + interval '31 minutes',
    'ожидание гостя живёт 30 минут');

  v_second := t.create_room('Алиса');
  perform t.ok((v_second -> 'room' ->> 'id') <> (v_first -> 'room' ->> 'id'), 'вторая комната другая');
  perform t.ok(
    (select count(*) from public.rooms where closed_at is null) = 1 and
    (select count(*) from public.rooms where id = (v_first -> 'room' ->> 'id')::uuid and closed_at is not null) = 1,
    'новая комната закрывает прежнюю');

  perform t.throws('select public.create_room('''', 1, ''r'', ''h'', 1)', '22023', 'пустое имя');
  perform t.throws('select public.create_room(null, 1, ''r'', ''h'', 1)', '22023', 'имя null');
  perform t.throws('select public.create_room(repeat(''я'', 65), 1, ''r'', ''h'', 1)', '22023', 'имя длиннее 64 символов');
  perform t.throws('select public.create_room(''A'', 0, ''r'', ''h'', 1)', '22023', 'версия протокола 0');
  perform t.throws('select public.create_room(''A'', 1, '''', ''h'', 1)', '22023', 'пустой id правил');
  perform t.throws('select public.create_room(''A'', 1, ''r'', repeat(''h'', 129), 1)', '22023', 'хеш правил слишком длинный');
  perform t.throws('select public.create_room(''A'', 1, ''r'', ''h'', -1)', '22023', 'версия движка -1');
  perform t.ok(
    (select count(*) from public.rooms where closed_at is null) = 1, 'ошибочные вызовы комнат не создают');
end
$$;
rollback;

-- Лимит создания: 20 в час.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_result jsonb;
begin
  perform t.login(v_host);
  for i in 1..20 loop
    v_result := t.create_room();
    perform t.ok((v_result ->> 'ok')::boolean, 'создание ' || i) where i in (1, 20);
  end loop;
  v_result := t.create_room();
  perform t.ok(v_result ->> 'reason' = 'too_many_rooms', '21-я комната за час отклонена');
  perform t.ok((select count(*) from public.rooms where closed_at is null) = 1, 'отказ не оставил лишней комнаты');

  perform t.admin('update private.attempts set at = now() - interval ''2 hours''');
  v_result := t.create_room();
  perform t.ok((v_result ->> 'ok')::boolean, 'через час лимит снимается');
end
$$;
rollback;

-- Коды разных комнат не повторяются.
begin;
do $$
declare
  v_codes int;
begin
  for i in 1..200 loop
    perform t.login(t.new_user());
    perform t.create_room();
  end loop;
  perform t.logout();
  perform t.login(t.new_user());
  v_codes := t.admin_int('select count(distinct code) from public.rooms');
  perform t.ok(v_codes = 200, '200 живых комнат — 200 разных кодов');
end
$$;
rollback;

-- Уборка: закрытые час назад комнаты и записи журнала старше суток.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_old jsonb;
begin
  perform t.login(v_host);
  v_old := t.create_room();
  perform public.close_room((v_old -> 'room' ->> 'id')::uuid);
  perform t.admin('update public.rooms set closed_at = now() - interval ''2 hours''');
  perform t.admin('insert into private.attempts (uid, kind, at) values (gen_random_uuid(), ''join_failure'', now() - interval ''2 days'')');
  perform t.create_room();
  perform t.ok(t.admin_int('select count(*) from public.rooms') = 1, 'закрытая час назад комната удалена');
  perform t.ok(t.admin_int('select count(*) from private.attempts where at < now() - interval ''1 day''') = 0, 'старый журнал убран');
end
$$;
rollback;

-- ---------------------------------------------------------------------------------------------------------------
-- join_room
-- ---------------------------------------------------------------------------------------------------------------
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_other uuid := t.new_user();
  v_room jsonb;
  v_code text;
  v_id uuid;
  v_result jsonb;
begin
  perform t.login(v_host);
  v_room := t.create_room();
  v_code := v_room -> 'room' ->> 'code';
  v_id := (v_room -> 'room' ->> 'id')::uuid;

  v_result := public.join_room(v_code);
  perform t.ok(v_result ->> 'reason' = 'own_room', 'хост не входит в свою комнату');

  perform t.login(v_guest);
  v_result := public.join_room(lower(substr(v_code, 1, 3)) || ' - ' || substr(v_code, 4));
  perform t.ok((v_result ->> 'ok')::boolean, 'гость входит: регистр, пробел и дефис не важны');
  perform t.ok(
    v_result -> 'room' ->> 'host_name' = 'Алиса' and v_result -> 'room' ->> 'protocol' = '1' and
    v_result -> 'room' ->> 'ruleset_id' = 'standard' and v_result -> 'room' ->> 'ruleset_hash' = 'hash0' and
    v_result -> 'room' ->> 'engine_version' = '1' and (v_result -> 'room' ->> 'id')::uuid = v_id,
    'гость получает объявление хоста');
  perform t.ok(
    (select guest_uid from public.rooms where id = v_id) = v_guest, 'место гостя записано');
  perform t.ok(
    (v_result -> 'room' ->> 'expires_at')::timestamptz > now() + interval '5 hours', 'комната с гостем живёт 6 часов');

  v_result := public.join_room(v_code);
  perform t.ok((v_result ->> 'ok')::boolean, 'тот же гость входит повторно');

  perform t.login(v_other);
  v_result := public.join_room(v_code);
  perform t.ok(v_result ->> 'reason' = 'full', 'второй гость получает full');

  perform t.login(v_host);
  perform public.set_room_open(v_id, false);
  perform t.login(v_guest);
  v_result := public.join_room(v_code);
  perform t.ok((v_result ->> 'ok')::boolean, 'гость возвращается и при open = false');
end
$$;
rollback;

begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_room jsonb;
  v_code text;
  v_id uuid;
  v_result jsonb;
begin
  perform t.login(v_host);
  v_room := t.create_room();
  v_code := v_room -> 'room' ->> 'code';
  v_id := (v_room -> 'room' ->> 'id')::uuid;

  perform public.set_room_open(v_id, false);
  perform t.login(v_guest);
  v_result := public.join_room(v_code);
  perform t.ok(v_result ->> 'reason' = 'closed', 'хост не принимает гостей: closed');

  perform t.login(v_host);
  perform public.set_room_open(v_id, true);
  perform public.close_room(v_id);
  perform t.login(v_guest);
  v_result := public.join_room(v_code);
  perform t.ok(v_result ->> 'reason' = 'not_found', 'закрытая комната: not_found');
end
$$;
rollback;

-- Срок жизни.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_room jsonb;
  v_result jsonb;
begin
  perform t.login(v_host);
  v_room := t.create_room();
  perform t.admin('update public.rooms set expires_at = now() - interval ''1 minute''');
  perform t.login(v_guest);
  v_result := public.join_room(v_room -> 'room' ->> 'code');
  perform t.ok(v_result ->> 'reason' = 'not_found', 'просроченная комната: not_found');
  perform t.ok(t.admin_int('select count(*) from public.rooms where closed_at is not null') = 1, 'просроченная комната закрыта');
  perform t.ok(t.admin_int('select count(*) from public.rooms where open') = 0, 'просроченная комната не открыта');
end
$$;
rollback;

-- Перебор кодов: 8 неверных за 10 минут блокируют вход, даже с верным кодом.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_room jsonb;
  v_result jsonb;
begin
  perform t.login(v_host);
  v_room := t.create_room();
  perform t.login(v_guest);
  for i in 1..8 loop
    v_result := public.join_room('AAAAA' || i);
    perform t.ok(v_result ->> 'reason' = 'not_found', 'неверный код ' || i) where i in (1, 8);
  end loop;
  v_result := public.join_room(v_room -> 'room' ->> 'code');
  perform t.ok(v_result ->> 'reason' = 'too_many_attempts', 'после 8 неверных кодов вход заблокирован');
  perform t.ok(
    t.admin_int('select count(*) from public.rooms where guest_uid is not null') = 0, 'заблокированный не занял место');

  perform t.admin('update private.attempts set at = now() - interval ''11 minutes''');
  v_result := public.join_room(v_room -> 'room' ->> 'code');
  perform t.ok((v_result ->> 'ok')::boolean, 'через 10 минут вход снова работает');
end
$$;
rollback;

-- Гость уходит из прежней комнаты, когда входит в новую.
begin;
do $$
declare
  v_host_a uuid := t.new_user();
  v_host_b uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_room_a jsonb;
  v_room_b jsonb;
begin
  perform t.login(v_host_a);
  v_room_a := t.create_room('A');
  perform t.login(v_host_b);
  v_room_b := t.create_room('B');
  perform t.login(v_guest);
  perform public.join_room(v_room_a -> 'room' ->> 'code');
  perform public.join_room(v_room_b -> 'room' ->> 'code');
  perform t.ok(
    t.admin_int('select count(*) from public.rooms where guest_uid = ''' || v_guest || '''') = 1 and
    (select guest_uid from public.rooms where id = (v_room_b -> 'room' ->> 'id')::uuid) = v_guest,
    'гость сидит только в новой комнате');
end
$$;
rollback;

-- ---------------------------------------------------------------------------------------------------------------
-- set_room_open, kick_guest, leave_room, close_room
-- ---------------------------------------------------------------------------------------------------------------
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_stranger uuid := t.new_user();
  v_room jsonb;
  v_id uuid;
  v_code text;
  v_result jsonb;
begin
  perform t.login(v_host);
  v_room := t.create_room();
  v_id := (v_room -> 'room' ->> 'id')::uuid;
  v_code := v_room -> 'room' ->> 'code';
  perform t.login(v_guest);
  perform public.join_room(v_code);

  -- Чужие вызовы
  for who in 1..2 loop
    perform t.login(case who when 1 then v_guest else v_stranger end);
    perform t.ok(public.set_room_open(v_id, false) ->> 'reason' = 'not_found', 'set_room_open: не хост, ' || who);
    perform t.ok(public.kick_guest(v_id) ->> 'reason' = 'not_found', 'kick_guest: не хост, ' || who);
    perform t.ok(public.close_room(v_id) ->> 'reason' = 'not_found', 'close_room: не хост, ' || who);
  end loop;
  perform t.login(v_stranger);
  perform t.ok(public.leave_room(v_id) ->> 'reason' = 'not_found', 'leave_room: не гость');
  perform t.login(v_host);
  perform t.ok(public.leave_room(v_id) ->> 'reason' = 'not_found', 'leave_room: хост не гость');
  perform t.ok(t.admin_int('select count(*) from public.rooms where closed_at is null and open') = 1, 'чужие вызовы ничего не изменили');

  -- Выгнать гостя
  perform t.login(v_host);
  perform t.ok((public.kick_guest(v_id) ->> 'ok')::boolean, 'хост выгоняет гостя');
  perform t.ok(t.admin_int('select count(*) from public.rooms where guest_uid is not null') = 0, 'место свободно');
  perform t.login(v_guest);
  perform t.ok((select count(*) from public.rooms) = 0, 'выгнанный не видит комнату');
  perform t.login(v_stranger);
  perform t.ok((public.join_room(v_code) ->> 'ok')::boolean, 'на освободившееся место входит другой');

  -- Гость уходит сам
  perform t.ok((public.leave_room(v_id) ->> 'ok')::boolean, 'гость уходит');
  perform t.login(v_guest);
  perform t.ok((public.join_room(v_code) ->> 'ok')::boolean, 'и место снова свободно');
  perform t.ok(
    (select expires_at from public.rooms) > now() + interval '5 hours', 'с гостем срок снова 6 часов');

  -- Закрыть комнату
  perform t.login(v_host);
  perform t.ok((public.close_room(v_id) ->> 'ok')::boolean, 'хост закрывает комнату');
  perform t.ok(public.close_room(v_id) ->> 'reason' = 'not_found', 'повторное закрытие: not_found');
  perform t.ok(public.set_room_open(v_id, true) ->> 'reason' = 'not_found', 'закрытую нельзя открыть');
  perform t.login(v_guest);
  perform t.ok(public.leave_room(v_id) ->> 'reason' = 'not_found', 'из закрытой не уйти: not_found');
end
$$;
rollback;

-- Видимость комнат.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_stranger uuid := t.new_user();
  v_room jsonb;
begin
  perform t.login(v_host);
  v_room := t.create_room();
  perform t.ok((select count(*) from public.rooms) = 1, 'хост видит свою комнату');
  perform t.login(v_guest);
  perform t.ok((select count(*) from public.rooms) = 0, 'до входа гость комнату не видит');
  perform public.join_room(v_room -> 'room' ->> 'code');
  perform t.ok((select count(*) from public.rooms) = 1, 'гость видит комнату');
  perform t.login(v_stranger);
  perform t.ok((select count(*) from public.rooms) = 0, 'посторонний не видит комнату');
end
$$;
rollback;

-- Удаление игрока: комнаты хоста уходят, у чужой комнаты место гостя освобождается.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_room jsonb;
begin
  perform t.login(v_host);
  v_room := t.create_room();
  perform t.login(v_guest);
  perform public.join_room(v_room -> 'room' ->> 'code');
  perform t.admin('delete from auth.users where id = ''' || v_guest || '''');
  perform t.ok(t.admin_int('select count(*) from public.rooms where guest_uid is null') = 1, 'удалённый гость освободил место');
  perform t.admin('delete from auth.users where id = ''' || v_host || '''');
  perform t.ok(t.admin_int('select count(*) from public.rooms') = 0, 'комнаты удалённого хоста ушли');
end
$$;
rollback;

-- ---------------------------------------------------------------------------------------------------------------
-- Realtime: доступ к каналу комнаты
-- ---------------------------------------------------------------------------------------------------------------
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_stranger uuid := t.new_user();
  v_room jsonb;
  v_id uuid;
  v_other_id uuid;
  v_send text := 'insert into realtime.messages (topic, extension) values (current_setting(''realtime.topic''), ''broadcast'')';
begin
  perform t.login(v_host);
  v_room := t.create_room();
  v_id := (v_room -> 'room' ->> 'id')::uuid;
  perform t.login(v_guest);
  perform public.join_room(v_room -> 'room' ->> 'code');
  perform t.login(v_stranger);
  v_other_id := (t.create_room('Чужая') -> 'room' ->> 'id')::uuid;

  -- Запись
  perform t.topic(v_id);
  perform t.login(v_host);
  execute v_send;
  perform t.ok(true, 'хост пишет в канал комнаты');
  perform t.login(v_guest);
  execute v_send;
  perform t.ok(true, 'гость пишет в канал комнаты');
  perform t.login(v_stranger);
  perform t.throws(v_send, '42501', 'посторонний не пишет в канал чужой комнаты');
  perform t.logout();
  perform t.throws(v_send, '42501', 'anon не пишет в канал комнаты');

  perform t.login(v_host);
  perform t.throws(
    'insert into realtime.messages (topic, extension) values (current_setting(''realtime.topic''), ''presence'')',
    '42501', 'presence в канале комнаты закрыт');
  perform set_config('realtime.topic', 'room:' || v_other_id::text, true);
  perform t.throws(v_send, '42501', 'канал чужой комнаты закрыт для хоста другой комнаты');
  perform set_config('realtime.topic', 'room:не-uuid', true);
  perform t.throws(v_send, '42501', 'канал с неверным именем закрыт');
  perform set_config('realtime.topic', 'lobby', true);
  perform t.throws(v_send, '42501', 'канал вне room: закрыт');
  perform set_config('realtime.topic', '', true);
  perform t.throws(v_send, '42501', 'без имени канала закрыто');

  -- Чтение: сообщение лежит в таблице, видимость определяет политика.
  perform t.admin('insert into realtime.messages (topic, extension) values (''room:' || v_id || ''', ''broadcast'')');
  perform t.topic(v_id);
  perform t.login(v_host);
  perform t.ok((select count(*) from realtime.messages) > 0, 'хост читает канал комнаты');
  perform t.login(v_guest);
  perform t.ok((select count(*) from realtime.messages) > 0, 'гость читает канал комнаты');
  perform t.login(v_stranger);
  perform t.ok((select count(*) from realtime.messages) = 0, 'посторонний не читает канал');
  perform t.logout();
  perform t.ok((select count(*) from realtime.messages) = 0, 'anon не читает канал');

  -- Выгнанный и закрытая комната теряют доступ.
  perform t.login(v_host);
  perform public.kick_guest(v_id);
  perform t.login(v_guest);
  perform t.throws(v_send, '42501', 'выгнанный гость не пишет в канал');
  perform t.ok((select count(*) from realtime.messages) = 0, 'выгнанный гость не читает канал');

  perform t.login(v_host);
  perform t.ok((select count(*) from realtime.messages) > 0, 'хост всё ещё в канале');
  perform public.close_room(v_id);
  perform t.throws(v_send, '42501', 'после закрытия хост не пишет в канал');
  perform t.ok((select count(*) from realtime.messages) = 0, 'после закрытия хост не читает канал');
end
$$;
rollback;

-- Просроченная комната закрывает канал и без вызова функций.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_room jsonb;
begin
  perform t.login(v_host);
  v_room := t.create_room();
  perform t.topic((v_room -> 'room' ->> 'id')::uuid);
  perform t.admin('update public.rooms set expires_at = now() - interval ''1 second''');
  perform t.throws(
    'insert into realtime.messages (topic, extension) values (current_setting(''realtime.topic''), ''broadcast'')',
    '42501', 'просроченная комната закрыта для канала');
end
$$;
rollback;

select 'rooms_test: готово' as result;
