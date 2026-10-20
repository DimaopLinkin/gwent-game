-- Комнаты игры через интернет (ADR 0025).
--
-- Комната нужна, чтобы гость нашёл хоста по короткому коду и чтобы Realtime знал, кого пускать в канал комнаты.
-- Сама партия идёт между телефонами, в базе её нет. Клиенты читают таблицу только через RLS (участники комнаты)
-- и меняют её только функциями из следующей миграции: прямых прав на запись нет ни у кого.

-- Служебная схема без доступа для клиентов: Data API отдаёт только public, а права ниже убирают и остальное.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  -- Код комнаты: 6 символов из алфавита без похожих (нет 0, 1, I, O). Живёт, пока комната не закрыта.
  code text not null check (code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ2-9]{6}$'),
  host_uid uuid not null references auth.users (id) on delete cascade,
  guest_uid uuid references auth.users (id) on delete set null,
  -- Объявление хоста (GameAd, ADR 0007): по нему гость заранее видит несовместимую партию.
  host_name text not null check (char_length(host_name) between 1 and 64),
  protocol integer not null check (protocol between 1 and 32767),
  ruleset_id text not null check (char_length(ruleset_id) between 1 and 64),
  ruleset_hash text not null check (char_length(ruleset_hash) between 1 and 128),
  engine_version integer not null check (engine_version between 0 and 32767),
  -- Принимает ли хост нового гостя. Вернуться в комнату тому, кто в ней уже гость, можно и при open = false.
  open boolean not null default true,
  created_at timestamptz not null default now(),
  -- Ожидание гостя живёт 30 минут, комната с гостем — 6 часов; сдвигает срок только сервер (join/leave/kick).
  expires_at timestamptz not null default now() + interval '30 minutes',
  -- null, пока комната жива. Закрытые комнаты удаляются через час при очередном create_room.
  closed_at timestamptz,
  check (host_uid is distinct from guest_uid),
  check (closed_at is null or not open)
);

-- Код однозначно называет живую комнату; у игрока не больше одной живой комнаты как у хоста и как у гостя.
create unique index rooms_alive_code_key on public.rooms (code) where closed_at is null;
create unique index rooms_alive_host_key on public.rooms (host_uid) where closed_at is null;
create unique index rooms_alive_guest_key on public.rooms (guest_uid) where closed_at is null;
create index rooms_closed_at_idx on public.rooms (closed_at) where closed_at is not null;

alter table public.rooms enable row level security;

-- Видят комнату только её участники. Анонимный вход Supabase даёт роль authenticated, роль anon не нужна совсем.
create policy rooms_select_participants on public.rooms
  for select to authenticated
  using ((select auth.uid()) in (host_uid, guest_uid));

-- Supabase по умолчанию выдаёт ролям Data API все права на новые таблицы; оставляем только чтение.
revoke all on public.rooms from public, anon, authenticated;
grant select on public.rooms to authenticated;

-- Журнал действий для лимитов (см. create_room и join_room): kind = 'create_room' или 'join_failure'.
-- Нужен для защиты от перебора кодов и от заваливания базы комнатами; старые записи чистит create_room.
create table private.attempts (
  uid uuid not null,
  kind text not null,
  at timestamptz not null default now()
);
create index attempts_uid_kind_at_idx on private.attempts (uid, kind, at);
revoke all on private.attempts from public, anon, authenticated;
