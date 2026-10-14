-- VendaAI V14 — perfil, lojas seguidas e suporte administrativo
-- Execute depois da V13. Seguro para reexecutar.

-- Mantém a contagem pública de seguidores da loja sincronizada.
create or replace function public.vendaai_refresh_store_followers()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_store uuid;
begin
  if TG_OP='DELETE' then
    v_store := OLD.store_id;
  else
    v_store := NEW.store_id;
  end if;

  update marketplace_stores
  set followers_count=(
    select count(*) from marketplace_store_followers f
    where f.store_id=v_store
  ),
  updated_at=now()
  where id=v_store;

  if TG_OP='DELETE' then return OLD; end if;
  return NEW;
end;
$$;

drop trigger if exists trg_mp_refresh_store_followers on marketplace_store_followers;
create trigger trg_mp_refresh_store_followers
after insert or delete on marketplace_store_followers
for each row execute function public.vendaai_refresh_store_followers();

-- Admin: visão de suporte para usuários e negociações.
drop policy if exists mp_admin_profiles on marketplace_profiles;
create policy mp_admin_profiles
on marketplace_profiles for select
using (public.vendaai_is_marketplace_admin());

drop policy if exists mp_admin_stores on marketplace_stores;
create policy mp_admin_stores
on marketplace_stores for all
using (public.vendaai_is_marketplace_admin())
with check (public.vendaai_is_marketplace_admin());

drop policy if exists mp_admin_offers on marketplace_offers;
create policy mp_admin_offers
on marketplace_offers for select
using (public.vendaai_is_marketplace_admin());

drop policy if exists mp_admin_conversations on marketplace_conversations;
create policy mp_admin_conversations
on marketplace_conversations for select
using (public.vendaai_is_marketplace_admin());

drop policy if exists mp_admin_messages on marketplace_messages;
create policy mp_admin_messages
on marketplace_messages for select
using (public.vendaai_is_marketplace_admin());

-- Usuário pode ver as lojas que segue.
drop policy if exists mp_own_store_follow_select on marketplace_store_followers;
create policy mp_own_store_follow_select
on marketplace_store_followers for select
using (user_id=auth.uid());
