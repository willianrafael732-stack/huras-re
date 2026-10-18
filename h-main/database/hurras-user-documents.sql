create table public.hf_user_documents (
 user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 kind text not null check (kind in ('mixtures','theme','reading','favorites','notes')),
 payload jsonb not null check (jsonb_typeof(payload)='object' and octet_length(payload::text)<1048576),
 revision bigint not null default 1 check(revision>0),
 updated_at timestamptz not null default now(),
 primary key(user_id,kind)
);
alter table public.hf_user_documents enable row level security;
revoke all on public.hf_user_documents from anon;
grant select,insert,update,delete on public.hf_user_documents to authenticated;
create policy hf_documents_select on public.hf_user_documents for select to authenticated using ((select auth.uid())=user_id);
create policy hf_documents_insert on public.hf_user_documents for insert to authenticated with check ((select auth.uid())=user_id);
create policy hf_documents_update on public.hf_user_documents for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy hf_documents_delete on public.hf_user_documents for delete to authenticated using ((select auth.uid())=user_id);
