create extension if not exists "pgcrypto";

create table if not exists companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text,
  region text,
  differentials text,
  notes text,
  created_at timestamptz default now(),
  unique(owner_id)
);

create table if not exists properties (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  title text not null,
  type text,
  purpose text,
  price numeric,
  neighborhood text,
  city text,
  bedrooms int default 0,
  garage boolean default false,
  description text,
  created_at timestamptz default now()
);

create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  name text,
  original_message text,
  temperature text,
  intent text,
  suggested_reply text,
  next_step text,
  status text default 'Novo',
  notes text,
  match_count int default 0,
  matches jsonb default '[]'::jsonb,
  created_at timestamptz default now()
);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references leads(id) on delete cascade,
  role text not null check (role in ('user','assistant')),
  content text not null,
  created_at timestamptz default now()
);

alter table companies enable row level security;
alter table properties enable row level security;
alter table leads enable row level security;
alter table messages enable row level security;

drop policy if exists companies_owner_all on companies;
create policy companies_owner_all on companies
for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists properties_owner_all on properties;
create policy properties_owner_all on properties
for all using (
  exists(select 1 from companies c where c.id=properties.company_id and c.owner_id=auth.uid())
) with check (
  exists(select 1 from companies c where c.id=properties.company_id and c.owner_id=auth.uid())
);

drop policy if exists leads_owner_all on leads;
create policy leads_owner_all on leads
for all using (
  exists(select 1 from companies c where c.id=leads.company_id and c.owner_id=auth.uid())
) with check (
  exists(select 1 from companies c where c.id=leads.company_id and c.owner_id=auth.uid())
);

drop policy if exists messages_owner_all on messages;
create policy messages_owner_all on messages
for all using (
  exists(
    select 1 from leads l
    join companies c on c.id=l.company_id
    where l.id=messages.lead_id and c.owner_id=auth.uid()
  )
) with check (
  exists(
    select 1 from leads l
    join companies c on c.id=l.company_id
    where l.id=messages.lead_id and c.owner_id=auth.uid()
  )
);
