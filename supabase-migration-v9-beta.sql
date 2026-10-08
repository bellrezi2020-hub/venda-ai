-- VendaAI V9 - produção beta: limites, IA atômica, plano dev e taxa de sucesso congelada
-- Não apaga dados existentes.

-- 1) CAMPOS DE VENDAS
alter table sales
  add column if not exists payment_status text not null default 'pending',
  add column if not exists paid_at timestamptz;

-- 2) LIMITES PADRÃO PARA NOVAS EMPRESAS
create or replace function public.vendaai_init_company_limits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into company_limits(
    company_id, plan, monthly_ai_limit, max_members, max_properties, max_leads
  )
  values(NEW.id, 'trial', 3, 1, 100, 300)
  on conflict (company_id) do nothing;

  return NEW;
end;
$$;

drop trigger if exists trg_vendaai_init_company_limits on companies;
create trigger trg_vendaai_init_company_limits
after insert on companies
for each row
execute function public.vendaai_init_company_limits();

-- Garante linha de limite para empresas já existentes.
insert into company_limits(
  company_id, plan, monthly_ai_limit, max_members, max_properties, max_leads
)
select id, 'trial', 3, 1, 100, 300
from companies
on conflict (company_id) do nothing;

-- 3) PLANO INTERNO DE DESENVOLVIMENTO PARA A EMPRESA DE TESTE
-- Não é exibido ao público e não cobra taxa de sucesso.
update company_limits
set
  plan='dev',
  monthly_ai_limit=999999,
  max_members=100,
  max_properties=100000,
  max_leads=100000,
  updated_at=now()
where company_id='7a452f2a-d3c2-4f2f-acc1-d3f7b953fc57';

-- 4) LIMITES REAIS NO BANCO
create or replace function public.vendaai_enforce_company_limits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  lim company_limits%rowtype;
  used_count integer;
begin
  select *
  into lim
  from company_limits
  where company_id = NEW.company_id;

  if not found then
    return NEW;
  end if;

  if lower(coalesce(lim.plan,'trial')) = 'dev' then
    return NEW;
  end if;

  if TG_TABLE_NAME = 'company_members' then
    -- max_members inclui o proprietário.
    select count(*) into used_count
    from company_members
    where company_id = NEW.company_id;

    if used_count + 2 > lim.max_members then
      raise exception 'Limite de usuários atingido para este plano.';
    end if;

  elsif TG_TABLE_NAME = 'properties' then
    select count(*) into used_count
    from properties
    where company_id = NEW.company_id;

    if used_count + 1 > lim.max_properties then
      raise exception 'Limite de imóveis atingido para este plano.';
    end if;

  elsif TG_TABLE_NAME = 'leads' then
    select count(*) into used_count
    from leads
    where company_id = NEW.company_id;

    if used_count + 1 > lim.max_leads then
      raise exception 'Limite de leads atingido para este plano.';
    end if;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_vendaai_limit_members on company_members;
create trigger trg_vendaai_limit_members
before insert on company_members
for each row
execute function public.vendaai_enforce_company_limits();

drop trigger if exists trg_vendaai_limit_properties on properties;
create trigger trg_vendaai_limit_properties
before insert on properties
for each row
execute function public.vendaai_enforce_company_limits();

drop trigger if exists trg_vendaai_limit_leads on leads;
create trigger trg_vendaai_limit_leads
before insert on leads
for each row
execute function public.vendaai_enforce_company_limits();

-- 5) CONSUMO DE IA ATÔMICO
-- Evita duas requisições simultâneas ultrapassarem a cota.
create or replace function public.vendaai_consume_ai(
  p_company_id uuid,
  p_amount integer default 1
)
returns table(
  plan text,
  used integer,
  limit_value integer,
  remaining integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan text;
  v_limit integer;
  v_month text;
  v_month_used integer;
  v_lifetime_used integer;
begin
  if p_amount is null or p_amount < 1 then
    raise exception 'Quantidade inválida.';
  end if;

  -- Serializa consumo por empresa.
  perform pg_advisory_xact_lock(hashtext(p_company_id::text)::bigint);

  insert into company_limits(
    company_id, plan, monthly_ai_limit, max_members, max_properties, max_leads
  )
  values(p_company_id, 'trial', 3, 1, 100, 300)
  on conflict (company_id) do nothing;

  select lower(coalesce(cl.plan,'trial')),
         coalesce(cl.monthly_ai_limit,3)
  into v_plan, v_limit
  from company_limits cl
  where cl.company_id = p_company_id
  for update;

  if v_plan = 'dev' then
    v_limit := greatest(v_limit,999999);
  elsif v_plan = 'trial' then
    v_limit := 3;
  elsif v_plan = 'starter' then
    v_limit := 300;
  elsif v_plan = 'pro' then
    v_limit := 1500;
  end if;

  v_month := to_char(timezone('UTC', now()), 'YYYY-MM');

  if v_plan = 'trial' then
    select coalesce(sum(requests),0)::integer
    into v_lifetime_used
    from ai_usage
    where company_id = p_company_id;

    if v_lifetime_used + p_amount > 3 then
      raise exception 'Os 3 usos grátis da IA foram utilizados.';
    end if;
  end if;

  insert into ai_usage(company_id,month,requests,updated_at)
  values(p_company_id,v_month,p_amount,now())
  on conflict (company_id,month)
  do update set
    requests = ai_usage.requests + excluded.requests,
    updated_at = now();

  select requests
  into v_month_used
  from ai_usage
  where company_id = p_company_id
    and month = v_month;

  if v_plan <> 'trial' and v_plan <> 'dev' and v_month_used > v_limit then
    raise exception 'Limite mensal de IA atingido para este plano.';
  end if;

  if v_plan = 'trial' then
    select coalesce(sum(requests),0)::integer
    into v_lifetime_used
    from ai_usage
    where company_id = p_company_id;

    return query
    select v_plan, v_lifetime_used, 3, greatest(3-v_lifetime_used,0);
  else
    return query
    select v_plan, v_month_used, v_limit, greatest(v_limit-v_month_used,0);
  end if;
end;
$$;

revoke all on function public.vendaai_consume_ai(uuid,integer)
from public, anon, authenticated;

grant execute on function public.vendaai_consume_ai(uuid,integer)
to service_role;

-- 6) TAXA DE SUCESSO CONGELADA
-- closed_at é definido antes; a venda é sincronizada depois.
drop trigger if exists trg_vendaai_sync_sale on leads;
drop function if exists public.vendaai_sync_sale();

create or replace function public.vendaai_set_closed_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if NEW.status = 'Fechado'
     and coalesce(NEW.sale_value,0) > 0
     and NEW.closed_at is null then
    NEW.closed_at := now();
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_vendaai_set_closed_at on leads;
create trigger trg_vendaai_set_closed_at
before insert or update on leads
for each row
execute function public.vendaai_set_closed_at();

create or replace function public.vendaai_sync_sale()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  current_plan text;
  fee_value numeric(14,2);
  existing_sale uuid;
begin
  if NEW.status = 'Fechado' and coalesce(NEW.sale_value,0) > 0 then

    select id
    into existing_sale
    from sales
    where lead_id = NEW.id;

    if existing_sale is null then
      select lower(coalesce(plan,'trial'))
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

      insert into sales(
        company_id,
        lead_id,
        lead_name,
        sale_value,
        success_fee,
        plan_snapshot,
        closed_at,
        status,
        payment_status,
        updated_at
      )
      values(
        NEW.company_id,
        NEW.id,
        NEW.name,
        NEW.sale_value,
        fee_value,
        current_plan,
        coalesce(NEW.closed_at,now()),
        'active',
        case when fee_value = 0 then 'waived' else 'pending' end,
        now()
      );

    else
      -- Atualiza os dados comerciais, mas NUNCA recalcula
      -- success_fee nem plan_snapshot.
      update sales
      set
        lead_name = NEW.name,
        sale_value = NEW.sale_value,
        closed_at = coalesce(NEW.closed_at,closed_at),
        status = 'active',
        updated_at = now()
      where id = existing_sale;
    end if;

  elsif TG_OP='UPDATE'
        and OLD.status='Fechado'
        and NEW.status <> 'Fechado' then

    update sales
    set
      status='cancelled',
      updated_at=now()
    where lead_id=NEW.id;
  end if;

  return NEW;
end;
$$;

create trigger trg_vendaai_sync_sale
after insert or update on leads
for each row
execute function public.vendaai_sync_sale();

-- 7) ÍNDICES DE APOIO
create index if not exists leads_company_status_idx
on leads(company_id,status);

create index if not exists properties_company_idx
on properties(company_id);

create index if not exists company_members_company_idx
on company_members(company_id);
