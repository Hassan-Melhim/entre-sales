-- =============================================================================
--  Entre Sales — 1 of 3: tables and starting data
-- =============================================================================
--  Run once, in order: 1 tables → 2 security → 3 functions.
--  (Supabase dashboard → SQL Editor → New query → paste → Run.)
--
--  Conventions
--    money        bigint, in cents (12.50 € = 1250)
--    percentages  numeric(5,2), 0–100 (35 = 35%)
--    moments      timestamptz (stored in UTC, shown in Madrid time by the app)
--    days         date (date of arrival)
-- =============================================================================

-- Key/value settings shared by every device (store name, address, NIF…).
create table public.settings (
  key   text primary key,
  value text
);

create table public.artists (
  id                 bigint generated always as identity primary key,
  name               text not null check (btrim(name) <> ''),
  gender             text,
  address            text,
  legal_name         text,
  tax_id             text,
  iban               text,
  bank_name          text,
  is_spain_resident  boolean not null default true,
  commission_percent numeric(5,2) check (commission_percent between 0 and 100), -- null = store default
  created_at         timestamptz not null default now()
);

create table public.categories (
  id          bigint generated always as identity primary key,
  name        text not null check (btrim(name) <> ''),
  tax_percent numeric(5,2) not null check (tax_percent between 0 and 100),
  sort_order  integer not null default 0
);
create unique index categories_name_key on public.categories (lower(name));

-- The extra fields asked when logging a product (e.g. Size). Empty options = free text.
create table public.category_attributes (
  id          bigint generated always as identity primary key,
  category_id bigint not null references public.categories (id) on delete cascade,
  name        text not null,
  options     text[] not null default '{}',
  sort_order  integer not null default 0
);

create table public.products (
  id                          bigint generated always as identity primary key,
  artist_id                   bigint not null references public.artists (id),
  category_id                 bigint not null references public.categories (id),
  name                        text not null check (btrim(name) <> ''),
  base_price_cents            bigint not null check (base_price_cents >= 0), -- before tax
  per_variant_pricing         boolean not null default false,
  tax_percent_override        numeric(5,2) check (tax_percent_override between 0 and 100),        -- null = category rate
  commission_percent_override numeric(5,2) check (commission_percent_override between 0 and 100), -- null = artist's
  created_at                  timestamptz not null default now()
);

-- "json" (not jsonb) keeps the fields in the order they were entered: Size, Colour…
create table public.variants (
  id                   bigint generated always as identity primary key,
  product_id           bigint not null references public.products (id) on delete cascade,
  attributes           json not null default '{}',
  quantity             integer not null default 0 check (quantity >= 0),
  price_override_cents bigint check (price_override_cents >= 0), -- before tax; with per_variant_pricing
  date_of_arrival      date not null                              -- overwritten on restock
);

create table public.discounts (
  id      bigint generated always as identity primary key,
  name    text not null check (btrim(name) <> ''),
  percent numeric(5,2) not null check (percent between 0 and 100),
  active  boolean not null default true
);

-- Workshop / event sessions (added by hand; Google Calendar sync comes later).
create table public.calendar_events (
  id        bigint generated always as identity primary key,
  google_id text unique,
  title     text not null check (btrim(title) <> ''),
  start_at  timestamptz not null,
  end_at    timestamptz not null,
  synced_at timestamptz,
  check (end_at > start_at)
);

-- Sales. Written only by the checkout / refund functions (see file 3).
create table public.orders (
  id                bigint generated always as identity primary key,
  created_at        timestamptz not null default now(),
  created_by        uuid default auth.uid() references auth.users (id) on delete set null,
  sale_ref          uuid unique, -- set by the device; a repeated attempt returns the same sale
  payment_method    text not null check (payment_method in ('Cash', 'Card')),
  status            text not null default 'completed'
                    check (status in ('completed', 'partially_refunded', 'refunded')),
  calendar_event_id bigint references public.calendar_events (id) on delete set null,
  event_tag_source  text check (event_tag_source in ('auto', 'manual')),
  discount_id       bigint references public.discounts (id) on delete set null,
  discount_name     text,
  discount_percent  numeric(5,2) not null default 0,
  subtotal_cents    bigint not null, -- after discount, before tax
  discount_cents    bigint not null,
  tax_cents         bigint not null,
  total_cents       bigint not null
);

-- Each line keeps a copy of names, prices and rates at the moment of sale,
-- so editing a product or artist later never changes past sales.
-- Products, variants and artists with sales cannot be deleted (restrict).
create table public.order_items (
  id                  bigint generated always as identity primary key,
  order_id            bigint not null references public.orders (id) on delete cascade,
  variant_id          bigint references public.variants (id) on delete restrict,
  product_id          bigint references public.products (id) on delete restrict,
  artist_id           bigint not null references public.artists (id) on delete restrict,
  product_name        text not null,
  variant_label       text not null,
  category_name       text not null,
  quantity            integer not null check (quantity > 0),
  unit_base_cents     bigint not null,
  tax_percent         numeric(5,2) not null,
  commission_percent  numeric(5,2) not null,
  discount_percent    numeric(5,2) not null,
  base_cents          bigint not null, -- after discount, before tax
  discount_cents      bigint not null,
  tax_cents           bigint not null,
  total_cents         bigint not null,
  artist_payout_cents bigint not null, -- before the Spain-resident tax
  arrival_date        date,            -- for shelf-life analysis
  refunded_quantity   integer not null default 0 check (refunded_quantity between 0 and quantity)
);

create table public.refunds (
  id                  bigint generated always as identity primary key,
  order_item_id       bigint not null references public.order_items (id) on delete cascade,
  quantity            integer not null check (quantity > 0),
  base_cents          bigint not null,
  tax_cents           bigint not null,
  total_cents         bigint not null,
  artist_payout_cents bigint not null,
  created_at          timestamptz not null default now(),
  created_by          uuid default auth.uid() references auth.users (id) on delete set null
);

-- Who changed what, and when. Filled by triggers (file 2); nobody can edit it.
create table public.audit_log (
  id         bigint generated always as identity primary key,
  at         timestamptz not null default now(),
  user_id    uuid,
  user_email text,
  table_name text not null,
  row_id     text,
  action     text not null, -- INSERT | UPDATE | DELETE
  old_data   jsonb,
  new_data   jsonb
);

create index products_artist_idx        on public.products (artist_id);
create index products_category_idx      on public.products (category_id);
create index variants_product_idx       on public.variants (product_id);
create index category_attributes_cat_idx on public.category_attributes (category_id);
create index orders_created_idx         on public.orders (created_at);
create index orders_event_idx           on public.orders (calendar_event_id);
create index order_items_order_idx      on public.order_items (order_id);
create index order_items_artist_idx     on public.order_items (artist_id);
create index order_items_variant_idx    on public.order_items (variant_id);
create index order_items_product_idx    on public.order_items (product_id);
create index refunds_item_idx           on public.refunds (order_item_id);
create index refunds_created_idx        on public.refunds (created_at);
create index calendar_events_start_idx  on public.calendar_events (start_at);
create index audit_log_at_idx           on public.audit_log (at);

-- ----------------------------------------------------------- starting data
-- Same as seedCategories / seedDiscounts in lib/domain/business_rules.dart.
-- VAT: 21% general, 4% books, 0% café.
with c (name, tax_percent, sort_order, attrs) as (values
  ('Clothing',             21, 0,  '[["Size", ["XS","XS/S","S","M","L","XL"]], ["Style", []]]'),
  ('Jewellery',            21, 1,  '[["Finish", []], ["Style", []]]'),
  ('Accessories',          21, 2,  '[["Style", []], ["Size", []]]'),
  ('Ceramics',             21, 3,  '[["Design", []], ["Size", []]]'),
  ('Prints & Posters',     21, 4,  '[["Design", []], ["Size", ["A4","A3","Big"]]]'),
  ('Postcards & Stickers', 21, 5,  '[["Design", []]]'),
  ('Books & Zines',         4, 6,  '[["Language", []]]'),
  ('Stationery',           21, 7,  '[["Design", []]]'),
  ('Home & Textiles',      21, 8,  '[["Pattern", []], ["Size", ["Single","Double","King"]]]'),
  ('Lamps',                21, 9,  '[["Design", []]]'),
  ('Candles',              21, 10, '[["Scent", []]]'),
  ('Toys & Games',         21, 11, '[["Design", []]]'),
  ('Art & Objects',        21, 12, '[["Design", []]]'),
  ('Food & Drink',          0, 13, '[["Option", []]]'),
  ('Miscellaneous',        21, 14, '[]')
), ins as (
  insert into public.categories (name, tax_percent, sort_order)
  select name, tax_percent, sort_order from c
  returning id, name
)
insert into public.category_attributes (category_id, name, options, sort_order)
select ins.id,
       a.value ->> 0,
       coalesce(array(select jsonb_array_elements_text(a.value -> 1)), '{}'),
       a.ordinality - 1
from ins
join c on c.name = ins.name
cross join lateral jsonb_array_elements(c.attrs::jsonb) with ordinality as a (value, ordinality);

insert into public.discounts (name, percent) values ('Friends & Family', 5);
insert into public.settings (key, value) values ('store_name', 'Entre Salas');
