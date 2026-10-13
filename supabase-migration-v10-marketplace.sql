-- VendaAI V10 — fundação do Marketplace
-- ADITIVA: não remove tabelas do CRM imobiliário existente.
-- Execute somente depois de revisar em ambiente de teste.

create extension if not exists pgcrypto;

create table if not exists marketplace_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  account_type text not null default 'person' check (account_type in ('person','business','provider')),
  cpf_cnpj_hash text,
  phone_verified boolean not null default false,
  email_verified boolean not null default false,
  identity_status text not null default 'pending' check (identity_status in ('pending','verified','rejected','review')),
  risk_status text not null default 'normal' check (risk_status in ('normal','limited','suspended','banned')),
  city text,
  state text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists marketplace_stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  slug text unique not null,
  description text,
  logo_url text,
  banner_url text,
  city text,
  state text,
  founder_badge boolean not null default false,
  verified boolean not null default false,
  followers_count integer not null default 0,
  rating numeric(3,2) not null default 0,
  sales_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists marketplace_listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  store_id uuid references marketplace_stores(id) on delete set null,
  category text not null check (category in ('products','services','vehicles','real_estate')),
  title text not null,
  description text,
  price numeric(14,2) not null check (price >= 0),
  price_mode text not null default 'fixed' check (price_mode in ('fixed','negotiable','auction','quote')),
  city text,
  state text,
  status text not null default 'draft' check (status in ('draft','review','active','paused','sold','blocked')),
  risk_level text not null default 'low' check (risk_level in ('low','medium','high')),
  risk_reason text,
  authenticity_status text not null default 'not_required' check (authenticity_status in ('not_required','pending','verified','rejected')),
  allows_installments boolean not null default false,
  allows_offers boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists marketplace_listing_media (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references marketplace_listings(id) on delete cascade,
  url text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists marketplace_favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references marketplace_listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id,listing_id)
);

create table if not exists marketplace_store_followers (
  user_id uuid not null references auth.users(id) on delete cascade,
  store_id uuid not null references marketplace_stores(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id,store_id)
);

create table if not exists marketplace_offers (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references marketplace_listings(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  status text not null default 'pending' check (status in ('pending','accepted','rejected','countered','expired','cancelled')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists marketplace_conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references marketplace_listings(id) on delete set null,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(listing_id,buyer_id,seller_id)
);

create table if not exists marketplace_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references marketplace_conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  contact_redacted boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists marketplace_orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references auth.users(id) on delete restrict,
  seller_id uuid not null references auth.users(id) on delete restrict,
  listing_id uuid references marketplace_listings(id) on delete set null,
  gross_amount numeric(14,2) not null,
  seller_fee numeric(14,2) not null default 0,
  buyer_protection_fee numeric(14,2) not null default 0,
  seller_net numeric(14,2) generated always as (gross_amount-seller_fee) stored,
  payment_status text not null default 'pending' check (payment_status in ('pending','authorized','held','released','refunded','cancelled','disputed')),
  fulfillment_status text not null default 'pending' check (fulfillment_status in ('pending','accepted','sent','delivered','service_completed','cancelled')),
  auto_release_at timestamptz,
  delivered_at timestamptz,
  released_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists marketplace_wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  order_id uuid references marketplace_orders(id) on delete set null,
  entry_type text not null check (entry_type in ('sale','refund','referral','promo','withdrawal','purchase','adjustment')),
  amount numeric(14,2) not null,
  is_withdrawable boolean not null default true,
  status text not null default 'pending' check (status in ('pending','available','held','completed','cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists marketplace_disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references marketplace_orders(id) on delete cascade,
  opened_by uuid not null references auth.users(id) on delete restrict,
  reason text not null,
  details text,
  status text not null default 'open' check (status in ('open','waiting_buyer','waiting_seller','review','resolved_buyer','resolved_seller','cancelled')),
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists marketplace_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete restrict,
  target_user_id uuid references auth.users(id) on delete set null,
  listing_id uuid references marketplace_listings(id) on delete set null,
  reason text not null,
  details text,
  status text not null default 'open' check (status in ('open','review','resolved','dismissed')),
  created_at timestamptz not null default now()
);

create table if not exists marketplace_reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references marketplace_orders(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id) on delete restrict,
  reviewed_user_id uuid not null references auth.users(id) on delete restrict,
  role text not null check (role in ('buyer','seller','provider')),
  rating integer not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  unique(order_id,reviewer_id,reviewed_user_id)
);

create table if not exists marketplace_bookings (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references marketplace_listings(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete restrict,
  seller_id uuid not null references auth.users(id) on delete restrict,
  starts_at timestamptz not null,
  total_amount numeric(14,2) not null default 0,
  deposit_amount numeric(14,2) not null default 0,
  deposit_policy text,
  status text not null default 'pending' check (status in ('pending','confirmed','completed','cancelled_buyer','cancelled_seller','no_show')),
  created_at timestamptz not null default now()
);

create index if not exists mp_listings_status_cat_city_idx on marketplace_listings(status,category,city);
create index if not exists mp_listings_seller_idx on marketplace_listings(seller_id,created_at desc);
create index if not exists mp_orders_buyer_idx on marketplace_orders(buyer_id,created_at desc);
create index if not exists mp_orders_seller_idx on marketplace_orders(seller_id,created_at desc);
create index if not exists mp_reports_status_idx on marketplace_reports(status,created_at);
create index if not exists mp_disputes_status_idx on marketplace_disputes(status,created_at);

-- RLS: começa restritivo. Libere políticas adicionais somente quando as telas estiverem conectadas.
alter table marketplace_profiles enable row level security;
alter table marketplace_stores enable row level security;
alter table marketplace_listings enable row level security;
alter table marketplace_listing_media enable row level security;
alter table marketplace_favorites enable row level security;
alter table marketplace_store_followers enable row level security;
alter table marketplace_offers enable row level security;
alter table marketplace_conversations enable row level security;
alter table marketplace_messages enable row level security;
alter table marketplace_orders enable row level security;
alter table marketplace_wallet_ledger enable row level security;
alter table marketplace_disputes enable row level security;
alter table marketplace_reports enable row level security;
alter table marketplace_reviews enable row level security;
alter table marketplace_bookings enable row level security;

-- Leitura pública somente de lojas e anúncios ativos.
drop policy if exists mp_public_stores on marketplace_stores;
create policy mp_public_stores on marketplace_stores for select using (true);
drop policy if exists mp_public_active_listings on marketplace_listings;
create policy mp_public_active_listings on marketplace_listings for select using (status='active' or seller_id=auth.uid());
drop policy if exists mp_public_listing_media on marketplace_listing_media;
create policy mp_public_listing_media on marketplace_listing_media for select using (true);

-- Usuário controla seu próprio perfil.
drop policy if exists mp_own_profile_select on marketplace_profiles;
create policy mp_own_profile_select on marketplace_profiles for select using (user_id=auth.uid());
drop policy if exists mp_own_profile_update on marketplace_profiles;
create policy mp_own_profile_update on marketplace_profiles for update using (user_id=auth.uid()) with check (user_id=auth.uid());

-- O vendedor gerencia os próprios anúncios/lojas.
drop policy if exists mp_own_store_write on marketplace_stores;
create policy mp_own_store_write on marketplace_stores for all using (owner_id=auth.uid()) with check (owner_id=auth.uid());
drop policy if exists mp_own_listing_write on marketplace_listings;
create policy mp_own_listing_write on marketplace_listings for all using (seller_id=auth.uid()) with check (seller_id=auth.uid());

-- IMPORTANTE: pagamentos, carteira, retenção e saques NÃO devem ser operados diretamente pelo front-end.
-- Eles precisam de API server-side + provedor de pagamentos/split antes de produção.


-- V10 MVP operacional: admin, onboarding e políticas necessárias
create table if not exists marketplace_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Semeia o administrador a partir da empresa de desenvolvimento já existente.
insert into marketplace_admins(user_id)
select owner_id from companies where id='7a452f2a-d3c2-4f2f-acc1-d3f7b953fc57'
on conflict (user_id) do nothing;

alter table marketplace_admins enable row level security;

drop policy if exists mp_admin_self_read on marketplace_admins;
create policy mp_admin_self_read on marketplace_admins for select using (user_id=auth.uid());

create or replace function public.vendaai_is_marketplace_admin()
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(select 1 from marketplace_admins where user_id=auth.uid());
$$;

grant execute on function public.vendaai_is_marketplace_admin() to authenticated;

-- Perfil próprio: inserir e atualizar.
drop policy if exists mp_own_profile_insert on marketplace_profiles;
create policy mp_own_profile_insert on marketplace_profiles for insert with check (user_id=auth.uid());

-- Favoritos e seguidores próprios.
drop policy if exists mp_own_favorites on marketplace_favorites;
create policy mp_own_favorites on marketplace_favorites for all using (user_id=auth.uid()) with check (user_id=auth.uid());
drop policy if exists mp_own_store_follow on marketplace_store_followers;
create policy mp_own_store_follow on marketplace_store_followers for all using (user_id=auth.uid()) with check (user_id=auth.uid());

-- Leitura pública dos dados mínimos das lojas/anúncios.
drop policy if exists mp_public_reviews on marketplace_reviews;
create policy mp_public_reviews on marketplace_reviews for select using (true);

-- Admin pode revisar anúncios e denúncias.
drop policy if exists mp_admin_listings on marketplace_listings;
create policy mp_admin_listings on marketplace_listings for all using (public.vendaai_is_marketplace_admin()) with check (public.vendaai_is_marketplace_admin());
drop policy if exists mp_admin_reports on marketplace_reports;
create policy mp_admin_reports on marketplace_reports for all using (public.vendaai_is_marketplace_admin()) with check (public.vendaai_is_marketplace_admin());
drop policy if exists mp_admin_disputes on marketplace_disputes;
create policy mp_admin_disputes on marketplace_disputes for all using (public.vendaai_is_marketplace_admin()) with check (public.vendaai_is_marketplace_admin());

-- Usuário autenticado pode criar denúncia.
drop policy if exists mp_create_report on marketplace_reports;
create policy mp_create_report on marketplace_reports for insert with check (reporter_id=auth.uid());

-- Vendedor pode ler os próprios anúncios mesmo em revisão (já coberto por select pública + seller_id).
-- Não ativamos pagamentos/carteira pelo navegador nesta etapa.
