-- VendaAI V18 — corrige RLS da criação de reservas
-- Execute depois da V17.

-- Permite que o comprador crie a própria reserva,
-- mantendo validação de identidade, serviço, vendedor e slot.
drop policy if exists mp_booking_buyer_insert on marketplace_bookings;
create policy mp_booking_buyer_insert
on marketplace_bookings
for insert
with check (
  buyer_id = auth.uid()
  and buyer_id <> seller_id
  and public.vendaai_account_can_transact(auth.uid())
  and exists (
    select 1
    from marketplace_listings l
    where l.id = marketplace_bookings.listing_id
      and l.seller_id = marketplace_bookings.seller_id
      and l.category = 'services'
      and l.status = 'active'
  )
  and (
    slot_id is null
    or exists (
      select 1
      from marketplace_availability_slots s
      where s.id = marketplace_bookings.slot_id
        and s.listing_id = marketplace_bookings.listing_id
        and s.seller_id = marketplace_bookings.seller_id
        and s.status in ('available','reserved')
    )
  )
);

-- A função continua sendo o fluxo oficial do front-end.
-- O trigger de segurança da V17 continua protegendo horário, valor e status.
