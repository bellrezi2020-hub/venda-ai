-- VendaAI V16 — segurança de perfil e moderação de usuários
-- Execute depois da V15.

-- Admin pode atualizar estado de risco e verificação.
drop policy if exists mp_admin_profiles_update on marketplace_profiles;
create policy mp_admin_profiles_update
on marketplace_profiles for update
using (public.vendaai_is_marketplace_admin())
with check (public.vendaai_is_marketplace_admin());

-- Usuário comum não controla selo/verificação/risco por chamada direta.
create or replace function public.vendaai_guard_profile_write()
returns trigger
language plpgsql
set search_path=public
as $$
declare v_admin boolean := public.vendaai_is_marketplace_admin();
begin
  if v_admin then
    return NEW;
  end if;

  if TG_OP='INSERT' then
    if NEW.user_id is distinct from auth.uid() then
      raise exception 'Perfil inválido.';
    end if;

    NEW.identity_status := 'pending';
    NEW.risk_status := 'normal';
    NEW.phone_verified := false;
    NEW.cpf_cnpj_hash := null;

    -- O front-end não pode autodeclarar e-mail verificado.
    NEW.email_verified := coalesce(
      (select (email_confirmed_at is not null) from auth.users where id=auth.uid()),
      false
    );
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

drop trigger if exists trg_mp_guard_profile_write on marketplace_profiles;
create trigger trg_mp_guard_profile_write
before insert or update on marketplace_profiles
for each row execute function public.vendaai_guard_profile_write();

-- Bloqueia ações sensíveis para contas suspensas/banidas/limitadas.
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

-- Novas propostas só para conta normal.
drop policy if exists mp_offer_buyer_insert on marketplace_offers;
create policy mp_offer_buyer_insert
on marketplace_offers for insert
with check (
  buyer_id=auth.uid()
  and public.vendaai_account_can_transact(auth.uid())
);

-- Reservas só para conta normal.
drop policy if exists mp_booking_buyer_insert on marketplace_bookings;
create policy mp_booking_buyer_insert
on marketplace_bookings for insert
with check (
  buyer_id=auth.uid()
  and buyer_id<>seller_id
  and public.vendaai_account_can_transact(auth.uid())
  and exists (
    select 1 from marketplace_listings l
    where l.id=listing_id
      and l.seller_id=seller_id
      and l.category='services'
      and l.status='active'
  )
);

-- Admin pode consultar reservas no painel.
drop policy if exists mp_admin_bookings on marketplace_bookings;
create policy mp_admin_bookings
on marketplace_bookings for select
using (public.vendaai_is_marketplace_admin());
