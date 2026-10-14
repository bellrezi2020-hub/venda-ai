-- VendaAI V19 — perfis automáticos para todas as contas
-- Execute depois da V18.

-- Cria perfis faltantes para usuários que já existem no Supabase Auth.
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
  coalesce(u.created_at, now()),
  now()
from auth.users u
where not exists (
  select 1
  from public.marketplace_profiles p
  where p.user_id=u.id
);

-- Cria o perfil automaticamente para novas contas.
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
    coalesce(NEW.created_at, now()),
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

-- Garante que a checagem só bloqueie contas realmente marcadas como restritas.
create or replace function public.vendaai_account_can_transact(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select coalesce((
    select risk_status='normal'
    from marketplace_profiles
    where user_id=p_user
  ),false);
$$;

revoke all on function public.vendaai_account_can_transact(uuid) from public;
grant execute on function public.vendaai_account_can_transact(uuid) to authenticated;
