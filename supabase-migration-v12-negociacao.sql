-- VendaAI V12 — propostas + contrapropostas + chat interno
-- Execute depois da V10/V11. Seguro para reexecutar.

alter table marketplace_offers
  add column if not exists counter_amount numeric(14,2),
  add column if not exists responded_at timestamptz;

-- PROPOSTAS
drop policy if exists mp_offer_select_participants on marketplace_offers;
create policy mp_offer_select_participants
on marketplace_offers
for select
using (
  buyer_id = auth.uid()
  or exists (
    select 1 from marketplace_listings l
    where l.id = marketplace_offers.listing_id
      and l.seller_id = auth.uid()
  )
);

drop policy if exists mp_offer_buyer_insert on marketplace_offers;
create policy mp_offer_buyer_insert
on marketplace_offers
for insert
with check (
  buyer_id = auth.uid()
  and exists (
    select 1 from marketplace_listings l
    where l.id = marketplace_offers.listing_id
      and l.status = 'active'
      and l.seller_id <> auth.uid()
  )
);

drop policy if exists mp_offer_buyer_cancel on marketplace_offers;
create policy mp_offer_buyer_cancel
on marketplace_offers
for update
using (buyer_id = auth.uid())
with check (
  buyer_id = auth.uid()
  and status in ('pending','cancelled')
);

drop policy if exists mp_offer_seller_update on marketplace_offers;
create policy mp_offer_seller_update
on marketplace_offers
for update
using (
  exists (
    select 1 from marketplace_listings l
    where l.id = marketplace_offers.listing_id
      and l.seller_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from marketplace_listings l
    where l.id = marketplace_offers.listing_id
      and l.seller_id = auth.uid()
  )
);

-- CONVERSAS
drop policy if exists mp_conversation_select_participants on marketplace_conversations;
create policy mp_conversation_select_participants
on marketplace_conversations
for select
using (
  buyer_id = auth.uid()
  or seller_id = auth.uid()
);

drop policy if exists mp_conversation_buyer_insert on marketplace_conversations;
create policy mp_conversation_buyer_insert
on marketplace_conversations
for insert
with check (
  buyer_id = auth.uid()
  and seller_id <> auth.uid()
  and exists (
    select 1 from marketplace_listings l
    where l.id = marketplace_conversations.listing_id
      and l.seller_id = marketplace_conversations.seller_id
      and l.status = 'active'
  )
);

drop policy if exists mp_conversation_participant_update on marketplace_conversations;
create policy mp_conversation_participant_update
on marketplace_conversations
for update
using (
  buyer_id = auth.uid()
  or seller_id = auth.uid()
)
with check (
  buyer_id = auth.uid()
  or seller_id = auth.uid()
);

-- MENSAGENS
drop policy if exists mp_message_select_participants on marketplace_messages;
create policy mp_message_select_participants
on marketplace_messages
for select
using (
  exists (
    select 1 from marketplace_conversations c
    where c.id = marketplace_messages.conversation_id
      and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
  )
);

drop policy if exists mp_message_insert_participants on marketplace_messages;
create policy mp_message_insert_participants
on marketplace_messages
for insert
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from marketplace_conversations c
    where c.id = marketplace_messages.conversation_id
      and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
  )
);

-- Oculta automaticamente contatos externos no texto da mensagem.
create or replace function public.vendaai_redact_marketplace_contact()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  original text;
begin
  original := NEW.body;

  NEW.body := regexp_replace(
    NEW.body,
    'https?://[^[:space:]]+|www\.[^[:space:]]+',
    '[link ocultado]',
    'gi'
  );

  NEW.body := regexp_replace(
    NEW.body,
    '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}',
    '[e-mail ocultado]',
    'gi'
  );

  NEW.body := regexp_replace(
    NEW.body,
    '(\+?55[[:space:]-]*)?(\(?[0-9]{2}\)?[[:space:]-]*)?9?[0-9]{4}[[:space:]-]*[0-9]{4}',
    '[telefone ocultado]',
    'g'
  );

  NEW.body := regexp_replace(
    NEW.body,
    '@[[:alnum:]_.]{2,}',
    '[perfil ocultado]',
    'g'
  );

  NEW.body := regexp_replace(
    NEW.body,
    '(whatsapp|telegram|pix)',
    '[contato externo ocultado]',
    'gi'
  );

  NEW.contact_redacted := (NEW.body is distinct from original);
  return NEW;
end;
$$;

drop trigger if exists trg_vendaai_redact_marketplace_contact on marketplace_messages;
create trigger trg_vendaai_redact_marketplace_contact
before insert or update on marketplace_messages
for each row
execute function public.vendaai_redact_marketplace_contact();

create index if not exists mp_offers_listing_status_idx
on marketplace_offers(listing_id,status,created_at desc);

create index if not exists mp_conversations_buyer_idx
on marketplace_conversations(buyer_id,updated_at desc);

create index if not exists mp_conversations_seller_idx
on marketplace_conversations(seller_id,updated_at desc);

create index if not exists mp_messages_conversation_idx
on marketplace_messages(conversation_id,created_at);
