-- VendaAI V15 — retenção, nome de vitrine e agendamentos
-- Execute depois da V14. Pagamentos continuam DESLIGADOS.

-- Nome de vitrine: usado nas telas públicas para reduzir busca externa pelo nome empresarial.
alter table marketplace_stores
  add column if not exists public_name text,
  add column if not exists service_region text;

update marketplace_stores
set public_name = coalesce(
  nullif(public_name,''),
  case
    when city is not null and btrim(city)<>'' then 'Loja local • ' || city
    else 'Vendedor local'
  end
)
where public_name is null or btrim(public_name)='';

-- Disponibilidade para serviços.
create table if not exists marketplace_availability_slots (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references marketplace_listings(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'available'
    check (status in ('available','reserved','blocked')),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists mp_slots_listing_time_idx
on marketplace_availability_slots(listing_id,starts_at);

alter table marketplace_availability_slots enable row level security;

drop policy if exists mp_slots_public_read on marketplace_availability_slots;
create policy mp_slots_public_read
on marketplace_availability_slots for select
using (
  status='available'
  or seller_id=auth.uid()
  or public.vendaai_is_marketplace_admin()
);

drop policy if exists mp_slots_seller_write on marketplace_availability_slots;
create policy mp_slots_seller_write
on marketplace_availability_slots for all
using (seller_id=auth.uid() or public.vendaai_is_marketplace_admin())
with check (
  (seller_id=auth.uid() and exists (
    select 1 from marketplace_listings l
    where l.id=listing_id and l.seller_id=auth.uid() and l.category='services'
  ))
  or public.vendaai_is_marketplace_admin()
);

-- Campos extras da reserva.
alter table marketplace_bookings
  add column if not exists slot_id uuid references marketplace_availability_slots(id) on delete set null,
  add column if not exists buyer_note text,
  add column if not exists seller_note text,
  add column if not exists cancelled_at timestamptz,
  add column if not exists completed_at timestamptz;

create unique index if not exists mp_booking_active_slot_unique
on marketplace_bookings(slot_id)
where slot_id is not null
  and status in ('pending','confirmed');

-- RLS das reservas.
drop policy if exists mp_booking_participant_select on marketplace_bookings;
create policy mp_booking_participant_select
on marketplace_bookings for select
using (
  buyer_id=auth.uid()
  or seller_id=auth.uid()
  or public.vendaai_is_marketplace_admin()
);

drop policy if exists mp_booking_buyer_insert on marketplace_bookings;
create policy mp_booking_buyer_insert
on marketplace_bookings for insert
with check (
  buyer_id=auth.uid()
  and buyer_id<>seller_id
  and exists (
    select 1 from marketplace_listings l
    where l.id=listing_id
      and l.seller_id=seller_id
      and l.category='services'
      and l.status='active'
  )
);

drop policy if exists mp_booking_participant_update on marketplace_bookings;
create policy mp_booking_participant_update
on marketplace_bookings for update
using (
  buyer_id=auth.uid()
  or seller_id=auth.uid()
  or public.vendaai_is_marketplace_admin()
)
with check (
  buyer_id is not null
  and seller_id is not null
);

-- Impede manipulação de identidade/horário/status.
create or replace function public.vendaai_guard_booking_write()
returns trigger
language plpgsql
set search_path=public
as $$
declare
  v_slot marketplace_availability_slots%rowtype;
  v_admin boolean := public.vendaai_is_marketplace_admin();
begin
  if TG_OP='INSERT' then
    if NEW.buyer_id is distinct from auth.uid() and not v_admin then
      raise exception 'Comprador inválido.';
    end if;

    select * into v_slot
    from marketplace_availability_slots
    where id=NEW.slot_id
    for update;

    if NEW.slot_id is not null then
      if v_slot.id is null
         or v_slot.listing_id<>NEW.listing_id
         or v_slot.seller_id<>NEW.seller_id
         or v_slot.status<>'available' then
        raise exception 'Horário indisponível.';
      end if;
      NEW.starts_at := v_slot.starts_at;
    end if;

    NEW.status := 'pending';
    NEW.total_amount := 0;
    NEW.deposit_amount := 0;
    return NEW;
  end if;

  if v_admin then
    return NEW;
  end if;

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

drop trigger if exists trg_mp_guard_booking_write on marketplace_bookings;
create trigger trg_mp_guard_booking_write
before insert or update on marketplace_bookings
for each row execute function public.vendaai_guard_booking_write();

-- Reserva de horário e liberação automática do slot.
create or replace function public.vendaai_sync_booking_slot()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if NEW.slot_id is null then return NEW; end if;

  if NEW.status in ('pending','confirmed') then
    update marketplace_availability_slots
    set status='reserved'
    where id=NEW.slot_id;
  elsif NEW.status in ('cancelled_buyer','cancelled_seller') then
    update marketplace_availability_slots
    set status='available'
    where id=NEW.slot_id;
  elsif NEW.status in ('completed','no_show') then
    update marketplace_availability_slots
    set status='blocked'
    where id=NEW.slot_id;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_mp_sync_booking_slot on marketplace_bookings;
create trigger trg_mp_sync_booking_slot
after insert or update of status on marketplace_bookings
for each row execute function public.vendaai_sync_booking_slot();

-- Notificações de reserva.
create or replace function public.vendaai_booking_notify()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_title text;
begin
  select title into v_title from marketplace_listings where id=NEW.listing_id;

  if TG_OP='INSERT' then
    perform public.vendaai_notify(
      NEW.seller_id,'booking','Nova solicitação de reserva',
      coalesce(v_title,'Serviço') || ' recebeu uma solicitação de horário.',
      'agenda-vendedor.html'
    );
  elsif NEW.status is distinct from OLD.status then
    if NEW.status='confirmed' then
      perform public.vendaai_notify(
        NEW.buyer_id,'booking','Reserva confirmada',
        coalesce(v_title,'Serviço') || ' foi confirmado pelo prestador.',
        'minhas-reservas.html'
      );
    elsif NEW.status='cancelled_seller' then
      perform public.vendaai_notify(
        NEW.buyer_id,'booking','Reserva cancelada',
        coalesce(v_title,'Serviço') || ' foi cancelado pelo prestador.',
        'minhas-reservas.html'
      );
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_mp_booking_notify on marketplace_bookings;
create trigger trg_mp_booking_notify
after insert or update on marketplace_bookings
for each row execute function public.vendaai_booking_notify();

-- Nome de vitrine também fica protegido contra edição por terceiros;
-- demais campos de reputação continuam protegidos pela V14.
