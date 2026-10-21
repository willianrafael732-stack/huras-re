-- Cofre privado por conta. O acesso autorizado ao mestre é restrito à mesa.
alter policy hf_sheets_read on public.hf_sheets using(owner_id=(select auth.uid()));
alter policy hf_shares_read on public.hf_sheet_shares using(hf_private.member(room_id) and (hf_private.owner(room_id) or exists(select 1 from public.hf_sheets s where s.id=sheet_id and s.owner_id=(select auth.uid()))));
create or replace function hf_private.room_sheets(p_room uuid) returns setof public.hf_sheets language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not hf_private.member(p_room) then raise exception 'Entre na mesa para consultar fichas';end if;
 return query select s.* from public.hf_sheets s where s.owner_id=auth.uid() or (hf_private.owner(p_room) and exists(select 1 from public.hf_sheet_shares sh where sh.sheet_id=s.id and sh.room_id=p_room)) order by s.updated_at desc;
end $$;
create or replace function public.hf_room_sheets(p_room uuid) returns setof public.hf_sheets language sql stable security invoker set search_path='' as $$select * from hf_private.room_sheets(p_room)$$;
revoke all on function hf_private.room_sheets(uuid),public.hf_room_sheets(uuid) from public,anon;
grant execute on function hf_private.room_sheets(uuid),public.hf_room_sheets(uuid) to authenticated;
