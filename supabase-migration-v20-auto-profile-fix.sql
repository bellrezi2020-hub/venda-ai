-- VendaAI V20 — corrige criação automática de perfis
-- Execute depois da V18. Não precisa rodar a V19 novamente.

-- Ajusta a proteção para permitir criação interna disparada pelo Auth,
-- mas continua bloqueando usuário tentando criar perfil para outra pessoa.
create or replace function public.vendaai_guard_profile_write()
returns trigger
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_admin boolean := public.vendaai_is_marketplace_admin();
  v_internal_auth_trigger boolean := (
    TG_OP='INSERT'
    and pg_trigger_depth()>1
    and exists(select 1 from auth.users u where u.id=NEW.user_id)
  );
begin
  if v_admin then
    return NEW;
  end if;

  if TG_OP='INSERT' then
    if NEW.user_id is distinct from auth.uid() and not v_internal_auth_trigger then
      raise exception 'Perfil inválido.';
    end if;

    NEW.identity_status := 'pending';
    NEW.risk_status := 'normal';
    NEW.phone_verified := coalesce(
      (select phone_confirmed_at is not null from auth.users where id=NEW.user_id),
      false
    );
    NEW.email_verified := coalesce(
      (select email_confirmed_at is not null from auth.users where id=NEW.user_id),
      false
    );
    NEW.cpf_cnpj_hash := null;
    return NEW;
  end if;

  if NEW.user_id is distinct from OLD.user_id then
    raise exception 'Usuário do perfil não pode ser alterado.';
  end if;

  NEW.identity_status := OLD.identity_status;
  NEW.risk_status := OLD.risk_status;
  NEW.phone_verified := OLD.phone_verified;
  NEW.email_verified := OLD.email_verified;
  NEW.cpf_cnpj_hash := OLD.cpf_cnpj_hash;

  return NEW;
end;
$$;

-- Função usada somente pelo trigger de criação de usuário.
create or replace function public.vendaai_create_marketplace_profile()
returns trigger
language plpgsql
security definer
set search_path=public,auth
as $$
begin
  insert into public.marketplace_profiles (
    user_id,
    display_name,
    account_type,
    phone_verified,
    email_verified,
    identity_status,
    risk_status,
    created_at,
    updated_at
  )
  values (
    NEW.id,
    coalesce(
      nullif(NEW.raw_user_meta_data->>'full_name',''),
      nullif(NEW.raw_user_meta_data->>'name',''),
      split_part(coalesce(NEW.email,'usuario'), '@', 1)
    ),
    'person',
    (NEW.phone_confirmed_at is not null),
    (NEW.email_confirmed_at is not null),
    'pending',
    'normal',
    coalesce(NEW.created_at,now()),
    now()
  )
  on conflict (user_id) do nothing;

  return NEW;
end;
$$;

drop trigger if exists trg_vendaai_create_marketplace_profile on auth.users;
create trigger trg_vendaai_create_marketplace_profile
after insert on auth.users
for each row execute function public.vendaai_create_marketplace_profile();

-- Backfill seguro para contas antigas:
-- desativa apenas o trigger de proteção durante esta operação administrativa.
alter table public.marketplace_profiles disable trigger trg_mp_guard_profile_write;

insert into public.marketplace_profiles (
  user_id,
  display_name,
  account_type,
  phone_verified,
  email_verified,
  identity_status,
  risk_status,
  city,
  state,
  created_at,
  updated_at
)
select
  u.id,
  coalesce(
    nullif(u.raw_user_meta_data->>'full_name',''),
    nullif(u.raw_user_meta_data->>'name',''),
    split_part(coalesce(u.email,'usuario'), '@', 1)
  ),
  'person',
  (u.phone_confirmed_at is not null),
  (u.email_confirmed_at is not null),
  'pending',
  'normal',
  null,
  null,
  coalesce(u.created_at,now()),
  now()
from auth.users u
where not exists (
  select 1
  from public.marketplace_profiles p
  where p.user_id=u.id
);

alter table public.marketplace_profiles enable trigger trg_mp_guard_profile_write;

-- Mantém a checagem de transação.
create or replace function public.vendaai_account_can_transact(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select coalesce((
    select risk_status='normal'
    from public.marketplace_profiles
    where user_id=p_user
  ),false);
$$;

revoke all on function public.vendaai_account_can_transact(uuid) from public;
grant execute on function public.vendaai_account_can_transact(uuid) to authenticated;
