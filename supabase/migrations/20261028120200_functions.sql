-- =============================================================================
--  Entre Sales — 3 of 3: sales, refunds, stock and report functions
-- =============================================================================
--  The app calls these instead of writing to the tables, so that:
--    * prices, VAT, discounts and commission are calculated here, from the
--      database, never trusted from the device;
--    * stock is checked and lowered in the same step as the sale, so two
--      devices can't both sell the last unit;
--    * a sale is saved completely or not at all.
-- =============================================================================

-- ------------------------------------------------------------------ rules
-- ►►► These two must match lib/domain/business_rules.dart.
create function public.rule_default_commission_percent() returns numeric
language sql immutable as $$ select 35.0 $$;

create function public.rule_discount_reduces_artist_payout() returns boolean
language sql immutable as $$ select false $$;

-- ---------------------------------------------------------------- helpers
-- Stops anyone who is not signed in (the functions below bypass row security).
create function public.require_owner() returns void
language plpgsql stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;
end;
$$;

-- "S · Blue" from {"Size":"S","Colour":"Blue"}, or "Standard".
create function public.variant_label(attrs json) returns text
language sql immutable
set search_path = ''
as $$
  select coalesce(string_agg(e.value, ' · ' order by e.ord), 'Standard')
  from json_each_text(coalesce(attrs, '{}'::json)) with ordinality as e (key, value, ord)
$$;

-- --------------------------------------------------------------- checkout
-- p_lines: [{"variant_id": 12, "quantity": 2}, …]
-- p_sale_ref: chosen by the device for this exact cart. If a sale with that
-- reference already exists (the connection dropped after saving and the
-- device tried again), that sale is returned instead of selling twice.
-- Returns the order id. Not enough stock → error ES001, with the problems
-- as a JSON list in the error detail.
create function public.checkout(p_lines jsonb, p_payment_method text, p_discount_id bigint default null,
                                p_sale_ref uuid default null)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_discount_name    text;
  v_discount_percent numeric := 0;
  v_order_id         bigint;
  v_session_id       bigint;
  v_problems         jsonb := '[]';
  v_now              timestamptz := now();
  r                  record;
begin
  perform public.require_owner();

  if p_sale_ref is not null then
    -- Waits for a simultaneous attempt with the same reference to finish.
    perform pg_advisory_xact_lock(hashtextextended(p_sale_ref::text, 0));
    select id into v_order_id from public.orders where sale_ref = p_sale_ref;
    if found then
      return v_order_id;
    end if;
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'The cart is empty' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_array_elements(p_lines) l
             where coalesce((l ->> 'quantity')::int, 0) <= 0 or l ->> 'variant_id' is null) then
    raise exception 'Every line needs a variant and a quantity above 0' using errcode = '22023';
  end if;

  if p_discount_id is not null then
    select name, percent into v_discount_name, v_discount_percent
    from public.discounts where id = p_discount_id and active;
    if not found then
      raise exception 'That discount is not available' using errcode = '22023';
    end if;
  end if;

  -- Lock the variants being sold (in id order, so two sales never deadlock),
  -- then check stock, adding up lines of the same variant.
  perform 1 from public.variants
  where id in (select (l ->> 'variant_id')::bigint from jsonb_array_elements(p_lines) l)
  order by id
  for update;

  for r in
    with wanted as (
      select (l ->> 'variant_id')::bigint as variant_id, sum((l ->> 'quantity')::int) as qty
      from jsonb_array_elements(p_lines) l
      group by 1
    )
    select w.variant_id, w.qty, v.quantity as in_stock, p.name as product_name, v.attributes
    from wanted w
    left join public.variants v on v.id = w.variant_id
    left join public.products p on p.id = v.product_id
    order by w.variant_id
  loop
    if r.in_stock is null then
      v_problems := v_problems || to_jsonb('A product in the cart no longer exists'::text);
    elsif r.in_stock < r.qty then
      v_problems := v_problems || to_jsonb(format('%s (%s): %s requested, %s in stock',
        r.product_name, public.variant_label(r.attributes), r.qty, r.in_stock));
    end if;
  end loop;
  if jsonb_array_length(v_problems) > 0 then
    raise exception 'Not enough stock' using errcode = 'ES001', detail = v_problems::text;
  end if;

  -- Workshop running right now?
  select id into v_session_id
  from public.calendar_events
  where start_at <= v_now and end_at > v_now
  order by start_at desc
  limit 1;

  insert into public.orders (created_at, sale_ref, payment_method, calendar_event_id, event_tag_source,
                             discount_id, discount_name, discount_percent,
                             subtotal_cents, discount_cents, tax_cents, total_cents)
  values (v_now, p_sale_ref, p_payment_method, v_session_id, case when v_session_id is not null then 'auto' end,
          p_discount_id, v_discount_name, v_discount_percent, 0, 0, 0, 0)
  returning id into v_order_id;

  -- One line per cart line, with prices and rates copied from the catalog.
  -- Same formulas as Pricing.line() in lib/domain/pricing.dart.
  insert into public.order_items (order_id, variant_id, product_id, artist_id, product_name, variant_label,
                                  category_name, quantity, unit_base_cents, tax_percent, commission_percent,
                                  discount_percent, base_cents, discount_cents, tax_cents, total_cents,
                                  artist_payout_cents, arrival_date)
  select v_order_id, x.variant_id, x.product_id, x.artist_id, x.product_name, x.variant_label,
         x.category_name, x.qty, x.unit_base, x.tax_pct, x.commission_pct,
         v_discount_percent, x.base, x.gross - x.base, x.tax, x.base + x.tax,
         round((case when public.rule_discount_reduces_artist_payout() then x.base else x.gross end)
               * (1 - x.commission_pct / 100)),
         x.arrival
  from (
    select l.ord, v.id as variant_id, p.id as product_id, p.artist_id, p.name as product_name,
           public.variant_label(v.attributes) as variant_label, c.name as category_name,
           (l.value ->> 'quantity')::int as qty, v.date_of_arrival as arrival,
           y.unit_base, y.tax_pct, y.commission_pct,
           y.unit_base * (l.value ->> 'quantity')::int as gross,
           round(y.unit_base * (l.value ->> 'quantity')::int * (1 - v_discount_percent / 100)) as base,
           round(round(y.unit_base * (l.value ->> 'quantity')::int * (1 - v_discount_percent / 100))
                 * y.tax_pct / 100) as tax
    from jsonb_array_elements(p_lines) with ordinality as l (value, ord)
    join public.variants v on v.id = (l.value ->> 'variant_id')::bigint
    join public.products p on p.id = v.product_id
    join public.artists a on a.id = p.artist_id
    join public.categories c on c.id = p.category_id
    cross join lateral (
      select case when p.per_variant_pricing and v.price_override_cents is not null
                  then v.price_override_cents else p.base_price_cents end as unit_base,
             coalesce(p.tax_percent_override, c.tax_percent) as tax_pct,
             coalesce(p.commission_percent_override, a.commission_percent,
                      public.rule_default_commission_percent()) as commission_pct
    ) y
  ) x
  order by x.ord;

  update public.orders o
  set subtotal_cents = t.base, discount_cents = t.discount, tax_cents = t.tax, total_cents = t.total
  from (select sum(base_cents) as base, sum(discount_cents) as discount,
               sum(tax_cents) as tax, sum(total_cents) as total
        from public.order_items where order_id = v_order_id) t
  where o.id = v_order_id;

  perform set_config('app.stock_movement', 'sale', true);
  update public.variants v
  set quantity = v.quantity - w.qty
  from (select (l ->> 'variant_id')::bigint as variant_id, sum((l ->> 'quantity')::int) as qty
        from jsonb_array_elements(p_lines) l group by 1) w
  where v.id = w.variant_id;
  perform set_config('app.stock_movement', '', true);

  return v_order_id;
end;
$$;

-- ----------------------------------------------------------------- refund
-- p_items: {"<order item id>": <units to refund>, …}
-- Units go straight back into stock. Dated now, so they count in the payout
-- period of the refund. Shares are calculated so that refunding every unit
-- returns exactly the line amount (same as Pricing.refundShare).
create function public.refund(p_order_id bigint, p_items jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  it record;
  q  int;
begin
  perform public.require_owner();
  perform set_config('app.stock_movement', 'sale', true);

  for it in
    select oi.*, (e.value)::int as wanted
    from jsonb_each_text(coalesce(p_items, '{}')) e
    join public.order_items oi on oi.id = e.key::bigint and oi.order_id = p_order_id
    order by oi.id
    for update of oi
  loop
    q := least(greatest(it.wanted, 0), it.quantity - it.refunded_quantity);
    continue when q = 0;

    insert into public.refunds (order_item_id, quantity, base_cents, tax_cents, total_cents, artist_payout_cents)
    values (
      it.id, q,
      round(it.base_cents::numeric * (it.refunded_quantity + q) / it.quantity)
        - round(it.base_cents::numeric * it.refunded_quantity / it.quantity),
      round(it.tax_cents::numeric * (it.refunded_quantity + q) / it.quantity)
        - round(it.tax_cents::numeric * it.refunded_quantity / it.quantity),
      round(it.total_cents::numeric * (it.refunded_quantity + q) / it.quantity)
        - round(it.total_cents::numeric * it.refunded_quantity / it.quantity),
      round(it.artist_payout_cents::numeric * (it.refunded_quantity + q) / it.quantity)
        - round(it.artist_payout_cents::numeric * it.refunded_quantity / it.quantity)
    );

    update public.order_items set refunded_quantity = refunded_quantity + q where id = it.id;
    if it.variant_id is not null then
      update public.variants set quantity = quantity + q where id = it.variant_id;
    end if;
  end loop;

  perform set_config('app.stock_movement', '', true);

  update public.orders o
  set status = case when t.r = 0 then 'completed'
                    when t.r >= t.q then 'refunded'
                    else 'partially_refunded' end
  from (select sum(quantity) as q, sum(refunded_quantity) as r
        from public.order_items where order_id = p_order_id) t
  where o.id = p_order_id;
end;
$$;

-- ------------------------------------------------------ workshop tagging
-- Tags (or untags, with null) a sale by hand. Manual tags are never
-- changed by automatic tagging.
create function public.set_order_session(p_order_id bigint, p_session_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_owner();
  update public.orders
  set calendar_event_id = p_session_id, event_tag_source = 'manual'
  where id = p_order_id;
end;
$$;

-- Tags sales made during a session that aren't tagged yet (e.g. after a
-- session is added afterwards). Returns how many sales were tagged.
create function public.auto_tag_sales()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare n integer;
begin
  perform public.require_owner();
  update public.orders o
  set calendar_event_id = (
        select e.id from public.calendar_events e
        where e.start_at <= o.created_at and e.end_at > o.created_at
        order by e.start_at desc limit 1),
      event_tag_source = 'auto'
  where o.event_tag_source is null
    and exists (select 1 from public.calendar_events e
                where e.start_at <= o.created_at and e.end_at > o.created_at);
  get diagnostics n = row_count;
  return n;
end;
$$;

-- ------------------------------------------------------------------ stock
-- Adds units to a variant; a restock overwrites the date of arrival.
create function public.restock(p_variant_id bigint, p_quantity integer, p_arrival date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_owner();
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Restock quantity must be above 0' using errcode = '22023';
  end if;
  update public.variants
  set quantity = quantity + p_quantity, date_of_arrival = p_arrival
  where id = p_variant_id;
end;
$$;

-- --------------------------------------------------------------- products
-- Creates (no "id") or updates a product with its full list of variants:
--   {"id", "name", "artist_id", "category_id", "base_price_cents",
--    "per_variant_pricing", "tax_percent_override", "commission_percent_override",
--    "variants": [{"id", "attributes", "quantity", "quantity_before",
--                  "price_override_cents", "date_of_arrival"}]}
-- Stock of existing variants changes by (quantity − quantity_before), so a
-- sale made on another device while the form was open isn't undone.
-- Variants left out are deleted, or set to 0 if they were ever sold.
create function public.save_product(p jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id   bigint := (p ->> 'id')::bigint;
  v_per  boolean := coalesce((p ->> 'per_variant_pricing')::boolean, false);
  v_keep bigint[];
  v      jsonb;
begin
  perform public.require_owner();

  if v_id is null then
    insert into public.products (name, artist_id, category_id, base_price_cents, per_variant_pricing,
                                 tax_percent_override, commission_percent_override)
    values (btrim(p ->> 'name'), (p ->> 'artist_id')::bigint, (p ->> 'category_id')::bigint,
            (p ->> 'base_price_cents')::bigint, v_per,
            (p ->> 'tax_percent_override')::numeric, (p ->> 'commission_percent_override')::numeric)
    returning id into v_id;
  else
    update public.products
    set name = btrim(p ->> 'name'),
        artist_id = (p ->> 'artist_id')::bigint,
        category_id = (p ->> 'category_id')::bigint,
        base_price_cents = (p ->> 'base_price_cents')::bigint,
        per_variant_pricing = v_per,
        tax_percent_override = (p ->> 'tax_percent_override')::numeric,
        commission_percent_override = (p ->> 'commission_percent_override')::numeric
    where id = v_id;
    if not found then
      raise exception 'Product % not found', v_id using errcode = 'P0002';
    end if;
  end if;

  select coalesce(array_agg((e ->> 'id')::bigint), '{}') into v_keep
  from jsonb_array_elements(coalesce(p -> 'variants', '[]')) e
  where e ->> 'id' is not null;

  -- Variants removed from the form.
  update public.variants set quantity = 0
  where product_id = v_id and id <> all (v_keep)
    and exists (select 1 from public.order_items oi where oi.variant_id = variants.id);
  delete from public.variants
  where product_id = v_id and id <> all (v_keep)
    and not exists (select 1 from public.order_items oi where oi.variant_id = variants.id);

  for v in select * from jsonb_array_elements(coalesce(p -> 'variants', '[]'))
  loop
    if v ->> 'id' is null then
      insert into public.variants (product_id, attributes, quantity, price_override_cents, date_of_arrival)
      values (v_id, coalesce(v -> 'attributes', '{}')::json, greatest((v ->> 'quantity')::int, 0),
              case when v_per then (v ->> 'price_override_cents')::bigint end,
              (v ->> 'date_of_arrival')::date);
    else
      update public.variants
      set attributes = coalesce(v -> 'attributes', '{}')::json,
          quantity = greatest(quantity + (v ->> 'quantity')::int
                              - coalesce((v ->> 'quantity_before')::int, quantity), 0),
          price_override_cents = case when v_per then (v ->> 'price_override_cents')::bigint end,
          date_of_arrival = (v ->> 'date_of_arrival')::date
      where id = (v ->> 'id')::bigint and product_id = v_id;
    end if;
  end loop;

  return v_id;
end;
$$;

-- ------------------------------------------------------------- categories
-- {"id", "name", "tax_percent", "attributes": [{"name", "options": [..]}]}
-- Products keep their variant values even if a field is renamed.
create function public.save_category(c jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare v_id bigint := (c ->> 'id')::bigint;
begin
  perform public.require_owner();
  if v_id is null then
    insert into public.categories (name, tax_percent, sort_order)
    values (btrim(c ->> 'name'), (c ->> 'tax_percent')::numeric,
            (select coalesce(max(sort_order), 0) + 1 from public.categories))
    returning id into v_id;
  else
    update public.categories
    set name = btrim(c ->> 'name'), tax_percent = (c ->> 'tax_percent')::numeric
    where id = v_id;
    delete from public.category_attributes where category_id = v_id;
  end if;

  insert into public.category_attributes (category_id, name, options, sort_order)
  select v_id, btrim(a.value ->> 'name'),
         coalesce(array(select jsonb_array_elements_text(a.value -> 'options')), '{}'),
         a.ord - 1
  from jsonb_array_elements(coalesce(c -> 'attributes', '[]')) with ordinality as a (value, ord);

  return v_id;
end;
$$;

-- ------------------------------------------------- reading lists (paged)
-- Rows come back in a fixed order, so the app can read them 1000 at a time.

create view public.product_rows with (security_invoker = on) as
select p.*,
       a.name as artist_name,
       a.commission_percent as artist_commission,
       c.name as category_name,
       c.tax_percent as category_tax,
       coalesce((select json_agg(v order by v.id) from public.variants v where v.product_id = p.id), '[]')
         as variants
from public.products p
join public.artists a on a.id = p.artist_id
join public.categories c on c.id = p.category_id;

create function public.search_products(p_query text default '', p_artist_id bigint default null,
                                       p_category_id bigint default null)
returns setof public.product_rows
language sql stable
set search_path = ''
as $$
  select * from public.product_rows r
  where (coalesce(btrim(p_query), '') = ''
         or r.name ilike '%' || btrim(p_query) || '%'
         or r.artist_name ilike '%' || btrim(p_query) || '%')
    and (p_artist_id is null or r.artist_id = p_artist_id)
    and (p_category_id is null or r.category_id = p_category_id)
  order by r.id
$$;

create view public.order_rows with (security_invoker = on) as
select o.*,
       e.title as event_title,
       coalesce((select json_agg(i order by i.id) from public.order_items i where i.order_id = o.id), '[]')
         as items
from public.orders o
left join public.calendar_events e on e.id = o.calendar_event_id;

create function public.search_orders(p_from timestamptz default null, p_to timestamptz default null,
                                     p_session_id bigint default null, p_query text default '')
returns setof public.order_rows
language sql stable
set search_path = ''
as $$
  select * from public.order_rows o
  where (p_from is null or o.created_at >= p_from)
    and (p_to is null or o.created_at < p_to)
    and (p_session_id is null or o.calendar_event_id = p_session_id)
    and (coalesce(btrim(p_query), '') = ''
         or exists (select 1 from public.order_items i
                    where i.order_id = o.id and i.product_name ilike '%' || btrim(p_query) || '%'))
  order by o.created_at desc, o.id desc
$$;

-- ---------------------------------------------------------- report facts
-- The calculations happen in the app (lib/domain/services); these return
-- the raw rows for a period [p_from, p_to).

create function public.report_order_summaries(p_from timestamptz, p_to timestamptz)
returns table (id bigint, created_at timestamptz, payment_method text,
               discount_cents bigint, tax_cents bigint, total_cents bigint)
language sql stable
set search_path = ''
as $$
  select o.id, o.created_at, o.payment_method, o.discount_cents, o.tax_cents, o.total_cents
  from public.orders o
  where o.created_at >= p_from and o.created_at < p_to
  order by o.id
$$;

create function public.report_sold_items(p_from timestamptz, p_to timestamptz, p_artist_id bigint default null)
returns table (id bigint, order_id bigint, sold_at timestamptz, artist_id bigint, artist_name text,
               artist_gender text, artist_resident boolean, product_id bigint, product_name text,
               variant_label text, category_name text, quantity integer, unit_base_cents bigint,
               base_cents bigint, discount_cents bigint, tax_cents bigint, total_cents bigint,
               commission_percent numeric, artist_payout_cents bigint, arrival_date date)
language sql stable
set search_path = ''
as $$
  select i.id, i.order_id, o.created_at, i.artist_id, a.name, a.gender, a.is_spain_resident,
         i.product_id, i.product_name, i.variant_label, i.category_name, i.quantity, i.unit_base_cents,
         i.base_cents, i.discount_cents, i.tax_cents, i.total_cents, i.commission_percent,
         i.artist_payout_cents, i.arrival_date
  from public.order_items i
  join public.orders o on o.id = i.order_id
  join public.artists a on a.id = i.artist_id
  where o.created_at >= p_from and o.created_at < p_to
    and (p_artist_id is null or i.artist_id = p_artist_id)
  order by i.id
$$;

create function public.report_refunded_items(p_from timestamptz, p_to timestamptz, p_artist_id bigint default null)
returns table (id bigint, order_id bigint, refunded_at timestamptz, artist_id bigint, artist_name text,
               artist_gender text, artist_resident boolean, product_id bigint, product_name text,
               variant_label text, category_name text, quantity integer, unit_base_cents bigint,
               base_cents bigint, tax_cents bigint, total_cents bigint,
               commission_percent numeric, artist_payout_cents bigint)
language sql stable
set search_path = ''
as $$
  select r.id, i.order_id, r.created_at, i.artist_id, a.name, a.gender, a.is_spain_resident,
         i.product_id, i.product_name, i.variant_label, i.category_name, r.quantity, i.unit_base_cents,
         r.base_cents, r.tax_cents, r.total_cents, i.commission_percent, r.artist_payout_cents
  from public.refunds r
  join public.order_items i on i.id = r.order_item_id
  join public.artists a on a.id = i.artist_id
  where r.created_at >= p_from and r.created_at < p_to
    and (p_artist_id is null or i.artist_id = p_artist_id)
  order by r.id
$$;

create function public.report_stock_items()
returns table (id bigint, product_id bigint, product_name text, artist_name text, category_name text,
               quantity integer, arrival date)
language sql stable
set search_path = ''
as $$
  select v.id, p.id, p.name, a.name, c.name, v.quantity, v.date_of_arrival
  from public.variants v
  join public.products p on p.id = v.product_id
  join public.artists a on a.id = p.artist_id
  join public.categories c on c.id = p.category_id
  where v.quantity > 0
  order by v.id
$$;

-- ------------------------------------------------------- function rights
-- Only signed-in owners may call anything. (Supabase lets everyone call new
-- functions by default, so this is switched off first.)
revoke execute on all functions in schema public from public, anon;
grant execute on function
  public.checkout(jsonb, text, bigint, uuid),
  public.refund(bigint, jsonb),
  public.set_order_session(bigint, bigint),
  public.auto_tag_sales(),
  public.restock(bigint, integer, date),
  public.save_product(jsonb),
  public.save_category(jsonb),
  public.search_products(text, bigint, bigint),
  public.search_orders(timestamptz, timestamptz, bigint, text),
  public.report_order_summaries(timestamptz, timestamptz),
  public.report_sold_items(timestamptz, timestamptz, bigint),
  public.report_refunded_items(timestamptz, timestamptz, bigint),
  public.report_stock_items(),
  public.variant_label(json),
  public.require_owner(),
  public.rule_default_commission_percent(),
  public.rule_discount_reduces_artist_payout()
to authenticated;

revoke all on public.product_rows, public.order_rows from anon;
grant select on public.product_rows, public.order_rows to authenticated;
