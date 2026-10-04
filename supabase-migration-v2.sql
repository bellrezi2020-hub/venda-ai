create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  created_at timestamptz default now()
);
create table if not exists company_members (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'corretor',
  created_at timestamptz default now(),
  unique(company_id,user_id)
);
alter table leads add column if not exists assigned_to uuid references auth.users(id) on delete set null;
alter table leads add column if not exists last_activity_at timestamptz default now();
alter table leads add column if not exists visit_confirmed_at timestamptz;
alter table profiles enable row level security;
alter table company_members enable row level security;
drop policy if exists profiles_self_select on profiles;
create policy profiles_self_select on profiles for select using (id=auth.uid());
drop policy if exists profiles_self_update on profiles;
create policy profiles_self_update on profiles for update using (id=auth.uid()) with check (id=auth.uid());
drop policy if exists members_company_select on company_members;
create policy members_company_select on company_members for select using (
  exists(select 1 from companies c where c.id=company_members.company_id and c.owner_id=auth.uid()) or user_id=auth.uid()
);
drop policy if exists companies_members_select on companies;
create policy companies_members_select on companies for select using (
  owner_id=auth.uid() or exists(select 1 from company_members cm where cm.company_id=companies.id and cm.user_id=auth.uid())
);
create index if not exists leads_company_status_idx on leads(company_id,status);
create index if not exists leads_company_temperature_idx on leads(company_id,temperature);
create index if not exists properties_company_idx on properties(company_id);
