-- Extensão aditiva: sessão, sinalização privada de voz e dano validado no servidor.
alter table public.hf_rooms add column if not exists session_status text not null default 'lobby' check(session_status in ('lobby','active','paused','ended'));
alter table public.hf_rooms add column if not exists session_updated_at timestamptz not null default now();
create table if not exists public.hf_voice_presence(
 room_id uuid not null references public.hf_rooms(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 connection_id uuid not null, muted boolean not null default false,
 heartbeat timestamptz not null default now(), primary key(room_id,user_id));
create table if not exists public.hf_voice_signals(
 id bigint generated always as identity primary key,
 room_id uuid not null references public.hf_rooms(id) on delete cascade,
 sender uuid not null default auth.uid() references auth.users(id) on delete cascade,
 recipient uuid not null references auth.users(id) on delete cascade,
 sender_connection uuid not null,recipient_connection uuid not null,
 kind text not null check(kind in ('offer','answer','ice')),
 payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=16000),
 created_at timestamptz not null default now(),check(sender<>recipient));
create index if not exists hf_voice_signal_recipient on public.hf_voice_signals(recipient,room_id,id);
create index if not exists hf_voice_signal_sender on public.hf_voice_signals(sender);
create index if not exists hf_voice_signal_room on public.hf_voice_signals(room_id);
create index if not exists hf_voice_presence_user on public.hf_voice_presence(user_id);
alter table public.hf_voice_presence enable row level security;
alter table public.hf_voice_signals enable row level security;
create policy hf_voice_presence_read on public.hf_voice_presence for select to authenticated using(hf_private.member(room_id));
create policy hf_voice_presence_add on public.hf_voice_presence for insert to authenticated with check(user_id=(select auth.uid()) and hf_private.member(room_id));
create policy hf_voice_presence_edit on public.hf_voice_presence for update to authenticated using(user_id=(select auth.uid()) and hf_private.member(room_id)) with check(user_id=(select auth.uid()) and hf_private.member(room_id));
create policy hf_voice_presence_remove on public.hf_voice_presence for delete to authenticated using(user_id=(select auth.uid()) or hf_private.owner(room_id));
create policy hf_voice_signal_read on public.hf_voice_signals for select to authenticated using(recipient=(select auth.uid()) and hf_private.member(room_id) and exists(select 1 from public.hf_members m where m.room_id=hf_voice_signals.room_id and m.user_id=hf_voice_signals.sender and not m.blocked));
create policy hf_voice_signal_add on public.hf_voice_signals for insert to authenticated with check(sender=(select auth.uid()) and hf_private.member(room_id) and exists(select 1 from public.hf_members m where m.room_id=hf_voice_signals.room_id and m.user_id=hf_voice_signals.recipient and not m.blocked));
create policy hf_voice_signal_remove on public.hf_voice_signals for delete to authenticated using(sender=(select auth.uid()) or recipient=(select auth.uid()));
grant select,insert,update,delete on public.hf_voice_presence to authenticated;
grant select,insert,delete on public.hf_voice_signals to authenticated;
grant usage,select on sequence public.hf_voice_signals_id_seq to authenticated;
revoke all on public.hf_voice_presence,public.hf_voice_signals from anon;
-- These invoker triggers stamp server time and validate both endpoints; never trust client roles.
create or replace function hf_private.voice_stamp() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entre na conta';end if;
 if TG_TABLE_NAME='hf_voice_presence' then
  new.heartbeat=clock_timestamp();
  if not exists(select 1 from public.hf_voice_presence where room_id=new.room_id and user_id=auth.uid()) and (select count(*) from public.hf_voice_presence where room_id=new.room_id and heartbeat>now()-interval '45 seconds')>=8 then raise exception 'Limite de oito pessoas na voz';end if;
 else
  new.created_at=clock_timestamp();new.sender=auth.uid();
  if not exists(select 1 from public.hf_voice_presence where room_id=new.room_id and user_id=new.sender and connection_id=new.sender_connection and heartbeat>now()-interval '45 seconds') or not exists(select 1 from public.hf_voice_presence where room_id=new.room_id and user_id=new.recipient and connection_id=new.recipient_connection and heartbeat>now()-interval '45 seconds') then raise exception 'Conexão de voz inativa';end if;
 end if;return new;
end $$;
revoke all on function hf_private.voice_stamp() from public,anon;
grant execute on function hf_private.voice_stamp() to authenticated;
create trigger hf_voice_presence_stamp before insert or update on public.hf_voice_presence for each row execute function hf_private.voice_stamp();
create trigger hf_voice_signal_stamp before insert on public.hf_voice_signals for each row execute function hf_private.voice_stamp();
create or replace function hf_private.session_status(p_room uuid,p_status text) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not hf_private.owner(p_room) or not hf_private.member(p_room) then raise exception 'Somente o mestre pode controlar a sessão';end if;
 if p_status is null or p_status not in ('lobby','active','paused','ended') then raise exception 'Estado inválido';end if;
 update public.hf_rooms set session_status=p_status,session_updated_at=clock_timestamp() where id=p_room and not is_direct;
end $$;
create or replace function public.hf_session_status(p_room uuid,p_status text) returns void language sql security invoker set search_path='' as $$select hf_private.session_status(p_room,p_status)$$;
revoke all on function hf_private.session_status(uuid,text),public.hf_session_status(uuid,text) from public,anon;
grant execute on function hf_private.session_status(uuid,text),public.hf_session_status(uuid,text) to authenticated;
create table if not exists public.hf_game_rules(id text primary key,payload jsonb not null check(jsonb_typeof(payload)='object'),updated_at timestamptz not null default now());
alter table public.hf_game_rules enable row level security;
create policy hf_rules_read on public.hf_game_rules for select to authenticated using(true);
grant select on public.hf_game_rules to authenticated;
revoke all on public.hf_game_rules from anon;
-- Private definer: necessary to append server-only roll results; every request checks room and sheet ownership.
create or replace function hf_private.roll_weapon(p_room uuid,p_sheet uuid,p_slot int,p_night boolean,p_target text) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.hf_sheets;rules jsonb;w jsonb;mat jsonb;ore jsonb;inputs jsonb;wn text;mn text;oname text;dice int;flat int;v int;vals int[]:='{}';total int:=0;result jsonb;cond boolean:=false;dtype text;parts jsonb;
begin
 if auth.uid() is null or not hf_private.member(p_room) then raise exception 'Entre na mesa';end if;
 if not exists(select 1 from public.hf_rooms where id=p_room and session_status='active') then raise exception 'O mestre precisa iniciar ou retomar a sessão';end if;
 if p_slot is null or p_slot not in(1,2) or p_target is null or p_target not in ('normal','shadow','sacred','profane') or p_night is null then raise exception 'Condições inválidas';end if;
 select * into s from public.hf_sheets where id=p_sheet;
 if s.id is null or s.kind<>'classic' or not(s.owner_id=auth.uid() or hf_private.owner(p_room)) or not exists(select 1 from public.hf_sheet_shares where sheet_id=p_sheet and room_id=p_room) then raise exception 'Compartilhe esta ficha Hurras com a mesa antes de rolar';end if;
 if exists(select 1 from public.hf_messages where room_id=p_room and user_id=auth.uid() and kind='roll' and created_at>clock_timestamp()-interval '1 second') then raise exception 'Aguarde um segundo entre rolagens';end if;
 select payload into rules from public.hf_game_rules where id='arsenal-v2';
 if rules is null then raise exception 'Catálogo de combate não configurado';end if;
 inputs=s.data#>'{data,inputs}';
 wn=inputs->>('weapon'||p_slot);mn=coalesce(inputs->>('weaponMaterial'||p_slot),'Padrão');oname=coalesce(inputs->>('weaponOre'||p_slot),'');
 w=rules->'weapons'->wn;mat=coalesce(rules->'materials'->mn,rules->'materials'->'Padrão');ore=rules->'ores'->oname;
 if w is null then raise exception 'Selecione uma arma na ficha e salve online';end if;
 dice=split_part(w->>'baseDamage','d',1)::int;if dice not between 1 and 10 then raise exception 'Dano inválido';end if;
 flat=coalesce((w->>'damageBonus')::int,0)+coalesce((mat->>'damageBonus')::int,0);
 cond=case oname when 'Minério Solar' then p_target='shadow' when 'Minério Profano' then p_target='sacred' when 'Minério Celestial' then p_target='profane' when 'Minério da Lua' then p_night else true end;
 parts=jsonb_build_array(jsonb_build_object('source','Arma','dice',w->>'baseDamage','type',w->>'damageType'),jsonb_build_object('source','Bônus da arma','flat',coalesce((w->>'damageBonus')::int,0),'type',w->>'damageType'),jsonb_build_object('source','Material','name',mat->>'name','flat',coalesce((mat->>'damageBonus')::int,0),'type','físico'),jsonb_build_object('source','Minério','name',coalesce(ore->>'name','Sem minério'),'flat',case when cond then coalesce((ore->>'damageBonus')::int,0) else 0 end,'type',coalesce(ore->>'damageType','físico'),'condition_met',cond));
 if cond then flat=flat+coalesce((ore->>'damageBonus')::int,0);end if;
 for i in 1..dice loop loop v=get_byte(extensions.gen_random_bytes(1),0);exit when v<250;end loop;v=v%10+1;vals=array_append(vals,v);total=total+v;end loop;
 result=jsonb_build_object('mode','damage','values',vals,'total',total+flat,'dice_total',total,'flat',flat,'label',s.name||' · '||wn,'parts',parts,'night',p_night,'target',p_target,'note','Dano bruto após acerto, antes de resistências. Técnicas e efeitos são resolvidos separadamente.');
 insert into public.hf_messages(room_id,user_id,kind,body,roll) values(p_room,auth.uid(),'roll',s.name||' · '||wn,result);return result;
end $$;
create or replace function public.hf_roll_weapon(p_room uuid,p_sheet uuid,p_slot int,p_night boolean default false,p_target text default 'normal') returns jsonb language sql security invoker set search_path='' as $$select hf_private.roll_weapon(p_room,p_sheet,p_slot,p_night,p_target)$$;
revoke all on function hf_private.roll_weapon(uuid,uuid,int,boolean,text),public.hf_roll_weapon(uuid,uuid,int,boolean,text) from public,anon;
grant execute on function hf_private.roll_weapon(uuid,uuid,int,boolean,text),public.hf_roll_weapon(uuid,uuid,int,boolean,text) to authenticated;
