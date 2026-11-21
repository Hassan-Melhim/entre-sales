-- Migration 5: product photos.
--
--  * Each product can have one photo, stored twice in the "product-photos"
--    Storage bucket: a display size (photo_path) and a small thumbnail
--    (thumb_path). Both columns hold the file's path inside the bucket.
--  * The bucket is public to read (anyone with the exact link can view a
--    photo); only signed-in staff can add, change or remove photos.
--  * product_rows gets the two columns at the end.

alter table public.products
  add column photo_path text,
  add column thumb_path text;

grant update (photo_path, thumb_path) on public.products to authenticated;

-- ------------------------------------------------------------- the bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-photos', 'product-photos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true;

create policy "Staff read product photos" on storage.objects
  for select to authenticated
  using (bucket_id = 'product-photos');
create policy "Staff add product photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'product-photos');
create policy "Staff change product photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'product-photos')
  with check (bucket_id = 'product-photos');
create policy "Staff remove product photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'product-photos');

-- ----------------------------------------------------------- product list
-- Same columns as before, in the same order, with the photo paths appended.
create or replace view public.product_rows with (security_invoker = on) as
select p.id, p.artist_id, p.category_id, p.name, p.base_price_cents, p.per_variant_pricing,
       p.tax_percent_override, p.commission_percent_override, p.created_at,
       a.name as artist_name,
       a.commission_percent as artist_commission,
       c.name as category_name,
       c.tax_percent as category_tax,
       coalesce((select json_agg(v order by v.id) from public.variants v where v.product_id = p.id), '[]')
         as variants,
       p.photo_path,
       p.thumb_path
from public.products p
join public.artists a on a.id = p.artist_id
join public.categories c on c.id = p.category_id;
