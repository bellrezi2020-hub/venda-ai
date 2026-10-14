-- VendaAI V13 — favoritos, denúncias, avaliações e notificações
-- Execute depois da V12. Seguro para reexecutar.

-- NOTIFICAÇÕES
create table if not exists marketplace_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  link text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists mp_notifications_user_idx
on marketplace_notifications(user_id,is_read,created_at desc);

alter table marketplace_notifications enable row level security;

drop policy if exists mp_notification_own_select on marketplace_notifications;
create policy mp_notification_own_select
on marketplace_notifications for select
using (user_id=auth.uid());

drop policy if exists mp_notification_own_update on marketplace_notifications;
create policy mp_notification_own_update
on marketplace_notifications for update
using (user_id=auth.uid())
with check (user_id=auth.uid());

-- Denúncias: usuário enxerga as próprias; admin continua enxergando tudo pela V10.
drop policy if exists mp_report_own_select on marketplace_reports;
create policy mp_report_own_select
on marketplace_reports for select
using (reporter_id=auth.uid());

-- AVALIAÇÕES ligadas a uma negociação real.
alter table marketplace_reviews
  alter column order_id drop not null,
  add column if not exists listing_id uuid references marketplace_listings(id) on delete set null;

create index if not exists mp_reviews_listing_idx
on marketplace_reviews(listing_id,created_at desc);

drop policy if exists mp_review_participant_insert on marketplace_reviews;
create policy mp_review_participant_insert
on marketplace_reviews for insert
with check (
  reviewer_id=auth.uid()
  and reviewer_id<>reviewed_user_id
  and listing_id is not null
  and exists (
    select 1
    from marketplace_conversations c
    where c.listing_id=marketplace_reviews.listing_id
      and (
        (c.buyer_id=auth.uid() and c.seller_id=marketplace_reviews.reviewed_user_id)
        or
        (c.seller_id=auth.uid() and c.buyer_id=marketplace_reviews.reviewed_user_id)
      )
  )
);

-- Evita múltiplas avaliações da mesma pessoa para a mesma contraparte/anúncio.
create unique index if not exists mp_review_listing_pair_unique
on marketplace_reviews(listing_id,reviewer_id,reviewed_user_id)
where listing_id is not null;

-- FUNÇÃO INTERNA DE NOTIFICAÇÃO
create or replace function public.vendaai_notify(
  p_user uuid,
  p_kind text,
  p_title text,
  p_body text,
  p_link text
) returns void
language sql
security definer
set search_path=public
as $$
  insert into marketplace_notifications(user_id,kind,title,body,link)
  values(p_user,p_kind,p_title,p_body,p_link);
$$;

revoke all on function public.vendaai_notify(uuid,text,text,text,text) from public;
revoke all on function public.vendaai_notify(uuid,text,text,text,text) from authenticated;

-- Nova proposta -> notifica vendedor.
create or replace function public.vendaai_offer_notify_insert()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_seller uuid; v_title text;
begin
  select seller_id,title into v_seller,v_title
  from marketplace_listings where id=NEW.listing_id;

  if v_seller is not null then
    perform public.vendaai_notify(
      v_seller,'offer','Nova proposta',
      'Você recebeu uma proposta de ' || to_char(NEW.amount,'FM999G999G990D00'),
      'vendedor-painel.html'
    );
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_mp_offer_notify_insert on marketplace_offers;
create trigger trg_mp_offer_notify_insert
after insert on marketplace_offers
for each row execute function public.vendaai_offer_notify_insert();

-- Resposta/contraproposta -> notifica comprador.
create or replace function public.vendaai_offer_notify_update()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_title text; v_body text;
begin
  if NEW.status is distinct from OLD.status or NEW.counter_amount is distinct from OLD.counter_amount then
    select title into v_title from marketplace_listings where id=NEW.listing_id;
    v_body := case
      when NEW.status='accepted' then 'Sua proposta foi aceita.'
      when NEW.status='rejected' then 'Sua proposta foi recusada.'
      when NEW.status='countered' then 'Você recebeu uma contraproposta.'
      else 'Sua proposta foi atualizada.'
    end;
    perform public.vendaai_notify(
      NEW.buyer_id,'offer_update',coalesce(v_title,'Proposta atualizada'),
      v_body,'minhas-negociacoes.html'
    );
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_mp_offer_notify_update on marketplace_offers;
create trigger trg_mp_offer_notify_update
after update on marketplace_offers
for each row execute function public.vendaai_offer_notify_update();

-- Nova mensagem -> notifica a outra pessoa.
create or replace function public.vendaai_message_notify()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_buyer uuid; v_seller uuid; v_listing uuid; v_target uuid; v_title text;
begin
  select buyer_id,seller_id,listing_id into v_buyer,v_seller,v_listing
  from marketplace_conversations where id=NEW.conversation_id;

  v_target := case when NEW.sender_id=v_buyer then v_seller else v_buyer end;
  select title into v_title from marketplace_listings where id=v_listing;

  if v_target is not null then
    perform public.vendaai_notify(
      v_target,'message','Nova mensagem',
      coalesce(v_title,'Você recebeu uma nova mensagem.'),
      'minhas-negociacoes.html'
    );
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_mp_message_notify on marketplace_messages;
create trigger trg_mp_message_notify
after insert on marketplace_messages
for each row execute function public.vendaai_message_notify();

-- Atualiza média da loja quando vendedor recebe avaliação.
create or replace function public.vendaai_refresh_store_rating()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_seller uuid;
begin
  v_seller := coalesce(NEW.reviewed_user_id,OLD.reviewed_user_id);
  update marketplace_stores s
  set rating=coalesce((
    select avg(r.rating)::numeric(3,2)
    from marketplace_reviews r
    where r.reviewed_user_id=v_seller and r.role='seller'
  ),0)
  where s.owner_id=v_seller;
  return coalesce(NEW,OLD);
end;
$$;

drop trigger if exists trg_mp_refresh_store_rating on marketplace_reviews;
create trigger trg_mp_refresh_store_rating
after insert or update or delete on marketplace_reviews
for each row execute function public.vendaai_refresh_store_rating();


-- Comprador pode responder a uma contraproposta e cancelar proposta própria.
drop policy if exists mp_offer_buyer_cancel on marketplace_offers;
drop policy if exists mp_offer_buyer_response on marketplace_offers;
create policy mp_offer_buyer_response
on marketplace_offers
for update
using (buyer_id=auth.uid())
with check (
  buyer_id=auth.uid()
  and status in ('accepted','rejected','cancelled','countered','pending')
);
