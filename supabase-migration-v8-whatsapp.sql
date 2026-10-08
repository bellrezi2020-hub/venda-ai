-- VendaAI V8 - base segura para WhatsApp Cloud API
-- Não apaga dados existentes e não armazena token secreto no Supabase.

alter table leads
  add column if not exists phone text,
  add column if not exists whatsapp_contact_id text,
  add column if not exists source text not null default 'manual';

alter table messages
  add column if not exists channel text not null default 'web',
  add column if not exists direction text,
  add column if not exists external_id text,
  add column if not exists delivery_status text;

create index if not exists leads_company_whatsapp_contact_idx
  on leads(company_id, whatsapp_contact_id);

create unique index if not exists messages_external_id_unique
  on messages(external_id)
  where external_id is not null;

create table if not exists whatsapp_connections (
  company_id uuid primary key references companies(id) on delete cascade,
  phone_number_id text not null unique,
  waba_id text,
  display_phone_number text,
  enabled boolean not null default false,
  auto_reply boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table whatsapp_connections enable row level security;

drop policy if exists whatsapp_connections_owner_select on whatsapp_connections;
create policy whatsapp_connections_owner_select
on whatsapp_connections
for select
using (public.is_company_owner(company_id));

drop policy if exists whatsapp_connections_owner_insert on whatsapp_connections;
create policy whatsapp_connections_owner_insert
on whatsapp_connections
for insert
with check (public.is_company_owner(company_id));

drop policy if exists whatsapp_connections_owner_update on whatsapp_connections;
create policy whatsapp_connections_owner_update
on whatsapp_connections
for update
using (public.is_company_owner(company_id))
with check (public.is_company_owner(company_id));

drop policy if exists whatsapp_connections_owner_delete on whatsapp_connections;
create policy whatsapp_connections_owner_delete
on whatsapp_connections
for delete
using (public.is_company_owner(company_id));
