-- VendaAI V11 — fotos + edição/exclusão de anúncios
-- Execute depois da V10. Seguro para reexecutar.

alter table marketplace_listing_media
  add column if not exists storage_path text;

-- Vendedor pode gerenciar mídia somente dos próprios anúncios.
drop policy if exists mp_own_listing_media_insert on marketplace_listing_media;
create policy mp_own_listing_media_insert
on marketplace_listing_media
for insert
with check (
  exists (
    select 1
    from marketplace_listings l
    where l.id = marketplace_listing_media.listing_id
      and l.seller_id = auth.uid()
  )
);

drop policy if exists mp_own_listing_media_update on marketplace_listing_media;
create policy mp_own_listing_media_update
on marketplace_listing_media
for update
using (
  exists (
    select 1
    from marketplace_listings l
    where l.id = marketplace_listing_media.listing_id
      and l.seller_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from marketplace_listings l
    where l.id = marketplace_listing_media.listing_id
      and l.seller_id = auth.uid()
  )
);

drop policy if exists mp_own_listing_media_delete on marketplace_listing_media;
create policy mp_own_listing_media_delete
on marketplace_listing_media
for delete
using (
  exists (
    select 1
    from marketplace_listings l
    where l.id = marketplace_listing_media.listing_id
      and l.seller_id = auth.uid()
  )
);

-- Bucket público de fotos do marketplace.
insert into storage.buckets (id, name, public)
values ('marketplace-media', 'marketplace-media', true)
on conflict (id) do update set public = true;

drop policy if exists mp_media_public_read on storage.objects;
create policy mp_media_public_read
on storage.objects
for select
using (bucket_id = 'marketplace-media');

drop policy if exists mp_media_own_insert on storage.objects;
create policy mp_media_own_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'marketplace-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists mp_media_own_update on storage.objects;
create policy mp_media_own_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'marketplace-media'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'marketplace-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists mp_media_own_delete on storage.objects;
create policy mp_media_own_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'marketplace-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);
