begin;
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('11111111-1000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','hurras-master-test@example.invalid','',now(),'{}','{}',now(),now()),
('11111111-1000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','hurras-player-test@example.invalid','',now(),'{}','{}',now(),now()),
('11111111-1000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','hurras-outsider-test@example.invalid','',now(),'{}','{}',now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('hurras.test_room',(public.hf_create_room('QA rollback','Mestre QA')->>'room_id'),true);
select set_config('hurras.test_invite',public.hf_rotate_invite(current_setting('hurras.test_room')::uuid),true);
select public.hf_session_status(current_setting('hurras.test_room')::uuid,'active');
select set_config('request.jwt.claims','{"sub":"11111111-1000-4000-8000-000000000002","role":"authenticated"}',true);
select public.hf_join_room(current_setting('hurras.test_invite'),'Jogador QA');
insert into public.hf_sheets(id,owner_id,kind,local_id,name,data) values('11111111-2000-4000-8000-000000000001',auth.uid(),'classic','qa','Teste QA','{"data":{"inputs":{"level":"5","weapon1":"Espada","weaponMaterial1":"Aço Temperado","weaponOre1":"Aço Rubro"},"state":{"wounds":0,"mana":25}}}');
insert into public.hf_sheet_shares(sheet_id,room_id) values('11111111-2000-4000-8000-000000000001',current_setting('hurras.test_room')::uuid);
do $$declare r jsonb;begin
r=public.hf_roll_weapon(current_setting('hurras.test_room')::uuid,'11111111-2000-4000-8000-000000000001',1,false,'normal');
assert (r->>'flat')::int=3,'Bônus incorreto';assert (r->>'total')::int between 4 and 13,'Dano fora do intervalo';
begin perform public.hf_session_status(current_setting('hurras.test_room')::uuid,'ended');raise exception 'QA_PLAYER_ALLOWED';exception when others then if sqlerrm='QA_PLAYER_ALLOWED' then raise;end if;end;
end$$;
insert into public.hf_voice_presence(room_id,user_id,connection_id) values(current_setting('hurras.test_room')::uuid,auth.uid(),'11111111-3000-4000-8000-000000000002');
select set_config('request.jwt.claims','{"sub":"11111111-1000-4000-8000-000000000001","role":"authenticated"}',true);
insert into public.hf_voice_presence(room_id,user_id,connection_id) values(current_setting('hurras.test_room')::uuid,auth.uid(),'11111111-3000-4000-8000-000000000001');
insert into public.hf_voice_signals(room_id,sender,recipient,sender_connection,recipient_connection,kind,payload) values(current_setting('hurras.test_room')::uuid,auth.uid(),'11111111-1000-4000-8000-000000000002','11111111-3000-4000-8000-000000000001','11111111-3000-4000-8000-000000000002','offer','{"type":"offer","sdp":"qa-only"}');
select set_config('request.jwt.claims','{"sub":"11111111-1000-4000-8000-000000000003","role":"authenticated"}',true);
do $$begin
assert not exists(select 1 from public.hf_rooms where id=current_setting('hurras.test_room')::uuid),'Mesa vazou';
assert not exists(select 1 from public.hf_voice_presence where room_id=current_setting('hurras.test_room')::uuid),'Voz vazou';
assert not exists(select 1 from public.hf_voice_signals where room_id=current_setting('hurras.test_room')::uuid),'Sinal vazou';
begin perform public.hf_roll_weapon(current_setting('hurras.test_room')::uuid,'11111111-2000-4000-8000-000000000001',1,false,'normal');raise exception 'QA_OUTSIDER_ALLOWED';exception when others then if sqlerrm='QA_OUTSIDER_ALLOWED' then raise;end if;end;
end$$;
select set_config('request.jwt.claims','{"sub":"11111111-1000-4000-8000-000000000002","role":"authenticated"}',true);
do $$begin assert (select count(*)=1 from public.hf_voice_signals where room_id=current_setting('hurras.test_room')::uuid),'Sinal não recebido';end$$;
select set_config('request.jwt.claims','{"sub":"11111111-1000-4000-8000-000000000001","role":"authenticated"}',true);
do $$begin
 assert not exists(select 1 from public.hf_sheets where id='11111111-2000-4000-8000-000000000001'),'Ficha do jogador apareceu no cofre do mestre';
 assert exists(select 1 from public.hf_room_sheets(current_setting('hurras.test_room')::uuid) where id='11111111-2000-4000-8000-000000000001'),'Mestre perdeu a autorização na mesa';
end$$;
select set_config('request.jwt.claims','{"sub":"11111111-1000-4000-8000-000000000003","role":"authenticated"}',true);
select public.hf_join_room(current_setting('hurras.test_invite'),'Outro jogador QA');
do $$begin
 assert not exists(select 1 from public.hf_sheets where id='11111111-2000-4000-8000-000000000001'),'Ficha vazou para outro jogador';
 assert not exists(select 1 from public.hf_room_sheets(current_setting('hurras.test_room')::uuid) where id='11111111-2000-4000-8000-000000000001'),'Ficha vazou dentro da mesa';
 assert not exists(select 1 from public.hf_sheet_shares where sheet_id='11111111-2000-4000-8000-000000000001'),'Compartilhamento vazou para outro jogador';
end$$;
select set_config('request.jwt.claims','{"sub":"11111111-1000-4000-8000-000000000002","role":"authenticated"}',true);
do $$begin assert exists(select 1 from public.hf_sheets where id='11111111-2000-4000-8000-000000000001'),'Dono perdeu acesso';end$$;
select 'PASS: cofre privado, isolamento entre jogadores e mestre autorizado somente na mesa' as resultado;
rollback;

