-- VendaAI V6 - planos + teste grátis + taxa de sucesso
-- Não apaga dados existentes.

create table if not exists company_limits (
  company_id uuid primary key references companies(id) on delete cascade,
  plan text not null default 'trial',
  monthly_ai_limit integer not null default 3,
  max_members integer not null default 1,
  max_properties integer not null default 100,
  max_leads integer not null default 300,
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

alter table leads
  add column if not exists sale_value numeric(14,2),
  add column if not exists closed_at timestamptz;

create table if not exists sales (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  lead_id uuid not null unique references leads(id) on delete cascade,
  lead_name text,
  sale_value numeric(14,2) not null,
  success_fee numeric(14,2) not null default 0,
  plan_snapshot text not null default 'trial',
  closed_at timestamptz not null default now(),
  status text not null default 'active',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table company_limits enable row level security;
alter table ai_usage enable row level security;
alter table sales enable row level security;

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

drop policy if exists sales_owner_select on sales;
create policy sales_owner_select
on sales
for select
using (public.is_company_owner(company_id));

insert into company_limits (
  company_id,
  plan,
  monthly_ai_limit,
  max_members,
  max_properties,
  max_leads
)
select
  id,
  'trial',
  3,
  1,
  100,
  300
from companies
on conflict (company_id) do nothing;

create or replace function public.vendaai_sync_sale()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  current_plan text;
  fee_value numeric(14,2);
begin
  if NEW.status = 'Fechado' and coalesce(NEW.sale_value,0) > 0 then

    select coalesce(plan,'trial')
    into current_plan
    from company_limits
    where company_id = NEW.company_id;

    current_plan := coalesce(current_plan,'trial');

    fee_value :=
      case current_plan
        when 'starter' then 299
        when 'pro' then 199
        else 0
      end;

    if NEW.closed_at is null then
      NEW.closed_at := now();
    end if;

    insert into sales (
      company_id,
      lead_id,
      lead_name,
      sale_value,
      success_fee,
      plan_snapshot,
      closed_at,
      status,
      updated_at
    )
    values (
      NEW.company_id,
      NEW.id,
      NEW.name,
      NEW.sale_value,
      fee_value,
      current_plan,
      NEW.closed_at,
      'active',
      now()
    )
    on conflict (lead_id)
    do update set
      lead_name = excluded.lead_name,
      sale_value = excluded.sale_value,
      success_fee = excluded.success_fee,
      plan_snapshot = excluded.plan_snapshot,
      closed_at = excluded.closed_at,
      status = 'active',
      updated_at = now();

  elsif OLD.status = 'Fechado' and NEW.status <> 'Fechado' then

    update sales
    set
      status = 'cancelled',
      updated_at = now()
    where lead_id = NEW.id;

  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_vendaai_sync_sale on leads;

create trigger trg_vendaai_sync_sale
before insert or update on leads
for each row
execute function public.vendaai_sync_sale();

create index if not exists ai_usage_company_month_idx
on ai_usage(company_id,month);

create index if not exists sales_company_closed_idx
on sales(company_id,closed_at desc);

-- Exemplos para ativar plano manualmente durante o beta:
--
-- STARTER:
-- update company_limits
-- set
--   plan='starter',
--   monthly_ai_limit=300,
--   max_members=3,
--   max_properties=500,
--   max_leads=2000,
--   updated_at=now()
-- where company_id='UUID_DA_EMPRESA';
--
-- PRO:
-- update company_limits
-- set
--   plan='pro',
--   monthly_ai_limit=1500,
--   max_members=8,
--   max_properties=2000,
--   max_leads=10000,
--   updated_at=now()
-- where company_id='UUID_DA_EMPRESA';
