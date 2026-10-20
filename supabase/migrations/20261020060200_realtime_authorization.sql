-- Доступ к приватному каналу комнаты в Realtime (ADR 0025).
--
-- Канал комнаты называется `room:<rooms.id>` и открывается как приватный (`private: true`). Realtime проверяет
-- политики таблицы realtime.messages при входе в канал и при обновлении токена: читать (select) и писать (insert)
-- в канал может только хост или гость живой комнаты. Для всего остального (presence, другие каналы, роль anon)
-- политик нет, значит доступ закрыт. Сообщения идут через Broadcast и в таблицу не пишутся.

create policy "gwent: участники комнаты читают её канал" on realtime.messages
  for select to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and exists (
      select 1
        from public.rooms r
       where 'room:' || r.id::text = (select realtime.topic())
         and r.closed_at is null
         and r.expires_at > now()
         and (select auth.uid()) in (r.host_uid, r.guest_uid)
    )
  );

create policy "gwent: участники комнаты пишут в её канал" on realtime.messages
  for insert to authenticated
  with check (
    realtime.messages.extension = 'broadcast'
    and exists (
      select 1
        from public.rooms r
       where 'room:' || r.id::text = (select realtime.topic())
         and r.closed_at is null
         and r.expires_at > now()
         and (select auth.uid()) in (r.host_uid, r.guest_uid)
    )
  );
