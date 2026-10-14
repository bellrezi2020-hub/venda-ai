-- VendaAI V17 — correção atômica de reservas
-- Execute depois da V16.

create or replace function public.vendaai_create_booking(
  p_listing_id uuid,
  p_slot_id uuid,
  p_buyer_note text default null
) returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user uuid := auth.uid();
  v_listing marketplace_listings%rowtype;
  v_slot marketplace_availability_slots%rowtype;
  v_booking_id uuid;
begin
  if v_user is null then
    raise exception 'Faça login para reservar.';
  end if;

  if not public.vendaai_account_can_transact(v_user) then
    raise exception 'Sua conta está temporariamente restrita para esta ação.';
  end if;

  select * into v_listing
  from marketplace_listings
  where id=p_listing_id
    and status='active'
    and category='services';

  if v_listing.id is null then
    raise exception 'Serviço indisponível.';
  end if;

  if v_listing.seller_id=v_user then
    raise exception 'Você não pode reservar o próprio serviço.';
  end if;

  select * into v_slot
  from marketplace_availability_slots
  where id=p_slot_id
  for update;

  if v_slot.id is null
     or v_slot.listing_id<>v_listing.id
     or v_slot.seller_id<>v_listing.seller_id
     or v_slot.status<>'available'
     or v_slot.starts_at<=now() then
    raise exception 'Horário indisponível.';
  end if;

  -- Reserva primeiro o slot dentro da mesma transação.
  update marketplace_availability_slots
  set status='reserved'
  where id=v_slot.id;

  insert into marketplace_bookings(
    listing_id,buyer_id,seller_id,slot_id,starts_at,
    buyer_note,total_amount,deposit_amount,status
  ) values (
    v_listing.id,v_user,v_listing.seller_id,v_slot.id,v_slot.starts_at,
    nullif(btrim(coalesce(p_buyer_note,'')),''),
    0,0,'pending'
  )
  returning id into v_booking_id;

  return v_booking_id;
end;
$$;

revoke all on function public.vendaai_create_booking(uuid,uuid,text) from public;
grant execute on function public.vendaai_create_booking(uuid,uuid,text) to authenticated;

-- A criação pelo navegador passa a ser feita apenas pela função acima.
drop policy if exists mp_booking_buyer_insert on marketplace_bookings;

-- Ajusta o trigger para aceitar a reserva atômica feita pela função.
create or replace function public.vendaai_guard_booking_write()
returns trigger
language plpgsql
set search_path=public
as $$
declare
  v_admin boolean := public.vendaai_is_marketplace_admin();
  v_slot marketplace_availability_slots%rowtype;
begin
  if TG_OP='INSERT' then
    if NEW.buyer_id is distinct from auth.uid() and not v_admin then
      raise exception 'Comprador inválido.';
    end if;

    select * into v_slot
    from marketplace_availability_slots
    where id=NEW.slot_id;

    if NEW.slot_id is not null then
      if v_slot.id is null
         or v_slot.listing_id<>NEW.listing_id
         or v_slot.seller_id<>NEW.seller_id
         or v_slot.status not in ('available','reserved') then
        raise exception 'Horário indisponível.';
      end if;
      NEW.starts_at := v_slot.starts_at;
    end if;

    NEW.status := 'pending';
    NEW.total_amount := 0;
    NEW.deposit_amount := 0;
    return NEW;
  end if;

  if v_admin then return NEW; end if;

  if NEW.buyer_id is distinct from OLD.buyer_id
     or NEW.seller_id is distinct from OLD.seller_id
     or NEW.listing_id is distinct from OLD.listing_id
     or NEW.slot_id is distinct from OLD.slot_id
     or NEW.starts_at is distinct from OLD.starts_at
     or NEW.total_amount is distinct from OLD.total_amount
     or NEW.deposit_amount is distinct from OLD.deposit_amount then
    raise exception 'Campos protegidos da reserva não podem ser alterados.';
  end if;

  if auth.uid()=OLD.buyer_id then
    if OLD.status in ('pending','confirmed')
       and NEW.status not in (OLD.status,'cancelled_buyer') then
      raise exception 'O comprador só pode cancelar a própria reserva.';
    end if;
  elsif auth.uid()=OLD.seller_id then
    if OLD.status='pending'
       and NEW.status not in ('pending','confirmed','cancelled_seller') then
      raise exception 'Resposta de reserva inválida.';
    elsif OLD.status='confirmed'
       and NEW.status not in ('confirmed','completed','cancelled_seller','no_show') then
      raise exception 'Atualização de reserva inválida.';
    elsif OLD.status not in ('pending','confirmed') and NEW.status<>OLD.status then
      raise exception 'Reserva encerrada não pode ser reaberta.';
    end if;
  else
    raise exception 'Usuário não participa desta reserva.';
  end if;

  if NEW.status like 'cancelled_%' and OLD.status not like 'cancelled_%' then
    NEW.cancelled_at := now();
  end if;
  if NEW.status='completed' and OLD.status<>'completed' then
    NEW.completed_at := now();
  end if;

  return NEW;
end;
$$;
