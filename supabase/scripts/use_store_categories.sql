-- =============================================================================
--  USE THE STORE'S OWN CATEGORIES — run once, before importing the real data
-- =============================================================================
--  Replaces the app's starting categories with the 11 the store uses, with the
--  fields each one asks for when logging a product. All fields are free text.
--
--  Order on switch-over day:
--    1. clear_test_data.sql   (removes the demo products that use the old categories)
--    2. this script
--    3. Settings → Advanced settings → Import data
--
--  Stops without changing anything if any product still exists.
--  How: Supabase → SQL Editor → New query → paste → Run.
-- =============================================================================
do $categories$
begin
  if exists (select 1 from public.products) then
    raise exception 'There are still products in the app. Run clear_test_data.sql first.';
  end if;

  delete from public.categories;  -- their fields go with them

  with c (name, tax_percent, sort_order, fields) as (values
    ('Clothes',           21, 0,  array['Size', 'Style']),
    ('Jewellery',         21, 1,  array['Finish', 'Style']),
    ('Accessories',       21, 2,  array['Size', 'Style', 'Design']),
    ('Ceramics',          21, 3,  array['Design']),
    ('Home Goods',        21, 4,  array['Size', 'Pattern', 'Design']),
    ('Libros & Prints',   21, 5,  array['Size', 'Design']),     -- books: 4% set on the product
    ('Goodies',           21, 6,  array['Design']),
    ('Conceptual Pieces', 21, 7,  array['Design']),
    ('Paintings',         21, 8,  array[]::text[]),
    ('Food & Drink',       0, 9,  array[]::text[]),
    ('TBD',               21, 10, array[]::text[])
  ), ins as (
    insert into public.categories (name, tax_percent, sort_order)
    select name, tax_percent, sort_order from c
    returning id, name
  )
  insert into public.category_attributes (category_id, name, options, sort_order)
  select ins.id, f.name, '{}', f.ord - 1
  from ins
  join c on c.name = ins.name
  cross join lateral unnest(c.fields) with ordinality as f (name, ord);

  raise notice 'Categories replaced: %', (select string_agg(name, ', ' order by sort_order) from public.categories);
end
$categories$;
