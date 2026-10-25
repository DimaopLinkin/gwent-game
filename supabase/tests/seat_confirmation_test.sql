-- Тесты подтверждения места гостя (миграция guest_seat_confirmation, ADR 0028).
-- Помощники t.* создаёт rooms_test.sql, который запускается раньше по имени файла.

\set ON_ERROR_STOP on
set client_min_messages = notice;

-- Комната хоста с протоколом 2 (сборки с подтверждением) или 1 (прежние).
create function t.create_room_v(p_protocol integer) returns jsonb
language sql as $$
  select public.create_room('Алиса', p_protocol, 'standard', 'hash0', 1)
$$;

-- Права.
begin;
do $$
begin
  perform t.logout();
  perform t.throws('select public.confirm_guest(gen_random_uuid())', '42501', 'anon не вызывает confirm_guest');
  perform t.login_nobody();
  perform t.throws('select public.confirm_guest(gen_random_uuid())', '28000', 'без входа confirm_guest не вызывается');
  perform t.ok(
    t.admin_int(
      'select (not has_function_privilege(''authenticated'', ''private.guest_seat_free(public.rooms)'', ''execute''))::int'
    ) = 1,
    'служебная функция места гостя клиентам закрыта');
end
$$;
rollback;

-- Гость, которого хост не видел, уступает место через минуту.
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
  v_room := t.create_room_v(2);
  v_code := v_room -> 'room' ->> 'code';
  v_id := (v_room -> 'room' ->> 'id')::uuid;

  perform t.login(v_guest);
  perform t.ok((public.join_room(v_code) ->> 'ok')::boolean, 'первый гость занимает место');

  perform t.login(v_other);
  perform t.ok(public.join_room(v_code) ->> 'reason' = 'full', 'сразу после входа первого гостя место занято');

  perform t.admin('update public.rooms set guest_joined_at = now() - interval ''59 seconds''');
  perform t.ok(public.join_room(v_code) ->> 'reason' = 'full', 'до конца минуты место занято');

  perform t.admin('update public.rooms set guest_joined_at = now() - interval ''61 seconds''');
  v_result := public.join_room(v_code);
  perform t.ok((v_result ->> 'ok')::boolean, 'гость, которого хост не видел, уступил место');
  perform t.ok((select guest_uid from public.rooms where id = v_id) = v_other, 'место записано на нового гостя');

  perform t.login(v_guest);
  perform t.ok(public.join_room(v_code) ->> 'reason' = 'full', 'прежний гость больше не в комнате');
  perform t.ok(t.admin_int('select count(*) from public.rooms where id = ''' || v_id || ''' and guest_uid = ''' || v_guest || '''') = 0,
    'прежний гость стёрт из комнаты');
end
$$;
rollback;

-- Подтверждённый гость держит место, пока комната жива.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_other uuid := t.new_user();
  v_room jsonb;
  v_code text;
  v_id uuid;
begin
  perform t.login(v_host);
  v_room := t.create_room_v(2);
  v_code := v_room -> 'room' ->> 'code';
  v_id := (v_room -> 'room' ->> 'id')::uuid;
  perform t.ok(public.confirm_guest(v_id) ->> 'reason' = 'not_found', 'в комнате без гостя подтверждать некого');

  perform t.login(v_guest);
  perform public.join_room(v_code);
  perform t.login(v_host);
  perform t.ok((public.confirm_guest(v_id) ->> 'ok')::boolean, 'хост подтверждает гостя');
  perform t.ok((public.confirm_guest(v_id) ->> 'ok')::boolean, 'повторное подтверждение ничего не ломает');

  perform t.admin('update public.rooms set guest_joined_at = now() - interval ''1 hour''');
  perform t.login(v_other);
  perform t.ok(public.join_room(v_code) ->> 'reason' = 'full', 'подтверждённый гость держит место и через час');

  perform t.login(v_guest);
  perform t.ok((public.join_room(v_code) ->> 'ok')::boolean, 'подтверждённый гость возвращается');
end
$$;
rollback;

-- Подтверждает только хост своей комнаты.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_other uuid := t.new_user();
  v_room jsonb;
  v_id uuid;
begin
  perform t.login(v_host);
  v_room := t.create_room_v(2);
  v_id := (v_room -> 'room' ->> 'id')::uuid;
  perform t.login(v_guest);
  perform public.join_room(v_room -> 'room' ->> 'code');
  perform t.ok(public.confirm_guest(v_id) ->> 'reason' = 'not_found', 'гость не подтверждает сам себя');
  perform t.login(v_other);
  perform t.ok(public.confirm_guest(v_id) ->> 'reason' = 'not_found', 'посторонний не подтверждает чужого гостя');
  perform t.ok(
    t.admin_int('select count(*) from public.rooms where guest_seen_at is not null') = 0, 'подтверждение не записано');
end
$$;
rollback;

-- Комнаты прежних сборок (протокол 1): место гостя не уступается никогда.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_other uuid := t.new_user();
  v_room jsonb;
  v_code text;
begin
  perform t.login(v_host);
  v_room := t.create_room_v(1);
  v_code := v_room -> 'room' ->> 'code';
  perform t.login(v_guest);
  perform public.join_room(v_code);
  perform t.admin('update public.rooms set guest_joined_at = now() - interval ''1 hour''');
  perform t.login(v_other);
  perform t.ok(public.join_room(v_code) ->> 'reason' = 'full', 'у прежних сборок живого гостя не выгнать');
end
$$;
rollback;

-- Уступленное место не продлевает комнату и не обходит запрет хоста.
begin;
do $$
declare
  v_host uuid := t.new_user();
  v_guest uuid := t.new_user();
  v_other uuid := t.new_user();
  v_room jsonb;
  v_code text;
  v_id uuid;
  v_expires timestamptz;
begin
  perform t.login(v_host);
  v_room := t.create_room_v(2);
  v_code := v_room -> 'room' ->> 'code';
  v_id := (v_room -> 'room' ->> 'id')::uuid;
  perform t.login(v_guest);
  perform public.join_room(v_code);
  select expires_at into v_expires from public.rooms where id = v_id;
  perform t.admin('update public.rooms set guest_joined_at = now() - interval ''2 minutes''');

  perform t.login(v_host);
  perform public.set_room_open(v_id, false);
  perform t.login(v_other);
  perform t.ok(public.join_room(v_code) ->> 'reason' = 'closed', 'хост закрыл приём: уступленное место не занять');

  perform t.login(v_host);
  perform public.set_room_open(v_id, true);
  perform t.login(v_other);
  perform t.ok((public.join_room(v_code) ->> 'ok')::boolean, 'приём открыт: место занято');
  perform t.ok((select expires_at from public.rooms where id = v_id) = v_expires, 'смена гостя срок комнаты не продлевает');
end
$$;
rollback;

select 'seat_confirmation_test: готово' as result;
