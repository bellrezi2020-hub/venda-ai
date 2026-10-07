create table if not exists company_limits (
  company_id uuid primary key references companies(id) on delete cascade,
  plan text not null default 'trial',
  monthly_ai_limit integer not null default 500,
  max_members integer not null default 3,
  max_properties integer not null default 500,
  max_leads integer not null default 2000,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists ai_usage (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  month text not null,
  requests integer not null default 0,
  updated_at timestamptz default now(),
  unique(company_id,month)
);

alter table company_limits enable row level security;
alter table ai_usage enable row level security;

drop policy if exists company_limits_owner_select on company_limits;
create policy company_limits_owner_select
on company_limits
for select
using (public.is_company_owner(company_id));

drop policy if exists ai_usage_owner_select on ai_usage;
create policy ai_usage_owner_select
on ai_usage
for select
using (public.is_company_owner(company_id));

insert into company_limits (company_id)
select id from companies
on conflict (company_id) do nothing;

create index if not exists ai_usage_company_month_idx
on ai_usage(company_id,month);
