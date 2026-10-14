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


-- SEGURANÇA DE ANÚNCIOS: vendedor não pode autoaprovar/burlar moderação.
create or replace function public.vendaai_guard_listing_write()
returns trigger
language plpgsql
set search_path=public
as $$
declare
  v_admin boolean := public.vendaai_is_marketplace_admin();
begin
  if v_admin then
    return NEW;
  end if;

  if TG_OP='INSERT' then
    if NEW.seller_id is distinct from auth.uid() then
      raise exception 'Vendedor inválido.';
    end if;
    if NEW.status not in ('draft','review') then
      raise exception 'Novo anúncio precisa passar por revisão.';
    end if;
    if NEW.store_id is not null and not exists (
      select 1 from marketplace_stores s
      where s.id=NEW.store_id and s.owner_id=auth.uid()
    ) then
      raise exception 'Loja inválida.';
    end if;
    NEW.risk_level := 'low';
    NEW.risk_reason := null;
    NEW.authenticity_status := 'not_required';
    return NEW;
  end if;

  if NEW.seller_id is distinct from OLD.seller_id
     or NEW.store_id is distinct from OLD.store_id then
    raise exception 'Vendedor e loja do anúncio não podem ser alterados.';
  end if;

  NEW.risk_level := OLD.risk_level;
  NEW.risk_reason := OLD.risk_reason;
  NEW.authenticity_status := OLD.authenticity_status;

  if OLD.status='review' and NEW.status not in ('review','draft') then
    raise exception 'Anúncio em revisão só pode ser aprovado pelo administrador.';
  elsif OLD.status='blocked' and NEW.status<>'blocked' then
    raise exception 'Anúncio bloqueado só pode ser liberado pelo administrador.';
  elsif OLD.status='active' and NEW.status not in ('active','review','paused','sold') then
    raise exception 'Mudança de status inválida.';
  elsif OLD.status='paused' and NEW.status not in ('paused','active','review','sold') then
    raise exception 'Mudança de status inválida.';
  elsif OLD.status='sold' and NEW.status not in ('sold','review') then
    raise exception 'Para republicar um vendido, envie novamente para revisão.';
  elsif OLD.status='draft' and NEW.status not in ('draft','review') then
    raise exception 'Rascunho precisa passar por revisão.';
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_mp_guard_listing_write on marketplace_listings;
create trigger trg_mp_guard_listing_write
before insert or update on marketplace_listings
for each row execute function public.vendaai_guard_listing_write();

-- SEGURANÇA DA LOJA: campos de confiança só podem ser controlados pelo sistema/admin.
create or replace function public.vendaai_guard_store_write()
returns trigger
language plpgsql
set search_path=public
as $$
declare
  v_admin boolean := public.vendaai_is_marketplace_admin();
  v_store_count integer;
begin
  if v_admin then
    return NEW;
  end if;

  if TG_OP='INSERT' then
    if NEW.owner_id is distinct from auth.uid() then
      raise exception 'Proprietário inválido.';
    end if;

    select count(*) into v_store_count from marketplace_stores;

    NEW.verified := false;
    NEW.followers_count := 0;
    NEW.rating := 0;
    NEW.sales_count := 0;
    NEW.founder_badge := (v_store_count < 100);
    return NEW;
  end if;

  if NEW.owner_id is distinct from OLD.owner_id then
    raise exception 'O proprietário da loja não pode ser alterado.';
  end if;

  NEW.verified := OLD.verified;
  NEW.followers_count := OLD.followers_count;
  NEW.rating := OLD.rating;
  NEW.sales_count := OLD.sales_count;
  NEW.founder_badge := OLD.founder_badge;

  return NEW;
end;
$$;

drop trigger if exists trg_mp_guard_store_write on marketplace_stores;
create trigger trg_mp_guard_store_write
before insert or update on marketplace_stores
for each row execute function public.vendaai_guard_store_write();
