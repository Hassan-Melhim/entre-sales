-- =============================================================================
--  Entre Sales — 4: importing data from the old system, and reading the logos
-- =============================================================================
--  Run once in the SQL Editor (after files 1–3).
--
--  * import_catalog: adds artists and products (with stock) from the import
--    template, all or nothing. Stops if any name already exists.
--  * import_past_sales: adds receipts from the old till as history. They count
--    in reports and artist payouts but do NOT change stock (the stock entered
--    with the products is what's on the shelf now). Each old receipt number
--    can only be imported once.
--  * Signed-in users can read the files in the "Logos & Icons" bucket, which
--    the PDFs use for the logos.
-- =============================================================================

-- The receipt number from the old system; empty for sales made in this app.
alter table public.orders add column legacy_receipt text unique;

-- The order list now includes legacy_receipt. (A view keeps the columns it was
-- created with, so they are listed, with the new one added at the end.)
create or replace view public.order_rows with (security_invoker = on) as
select o.id, o.created_at, o.created_by, o.sale_ref, o.payment_method, o.status, o.calendar_event_id,
       o.event_tag_source, o.discount_id, o.discount_name, o.discount_percent, o.subtotal_cents,
       o.discount_cents, o.tax_cents, o.total_cents,
       e.title as event_title,
       coalesce((select json_agg(i order by i.id) from public.order_items i where i.order_id = o.id), '[]')
         as items,
       o.legacy_receipt
from public.orders o
left join public.calendar_events e on e.id = o.calendar_event_id;

-- ------------------------------------------------------------ catalogue
-- p: {"artists": [{"name", "is_spain_resident", "commission_percent", "gender",
--                  "legal_name", "tax_id", "address", "iban", "bank_name"}],
--     "products": [{"artist", "name", "category", "base_price_cents",
--                   "per_variant_pricing", "tax_percent_override",
--                   "commission_percent_override",
--                   "variants": [{"attributes", "quantity", "price_override_cents",
--                                 "date_of_arrival"}]}]}
-- Artists and categories are matched by name (not case-sensitive).
-- Already existing names → error ES002 with the list in the error detail.
create function public.import_catalog(p json)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  a json;
  pr json;
  v_problems jsonb := '[]';
  v_artist bigint;
  v_category bigint;
  n_artists int := 0;
  n_products int := 0;
  n_variants int := 0;
begin
  perform public.require_owner();

  -- Everything that would clash, found before anything is written.
  select v_problems || coalesce(jsonb_agg(format('Artist "%s" already exists', x.value ->> 'name')), '[]')
  into v_problems
  from json_array_elements(coalesce(p -> 'artists', '[]')) x
  where exists (select 1 from public.artists ar where lower(ar.name) = lower(btrim(x.value ->> 'name')));

  select v_problems || coalesce(jsonb_agg(format('Product "%s" by %s already exists',
                                                 x.value ->> 'name', x.value ->> 'artist')), '[]')
  into v_problems
  from json_array_elements(coalesce(p -> 'products', '[]')) x
  where exists (select 1 from public.products pp join public.artists ar on ar.id = pp.artist_id
                where lower(ar.name) = lower(btrim(x.value ->> 'artist'))
                  and lower(pp.name) = lower(btrim(x.value ->> 'name')));

  if jsonb_array_length(v_problems) > 0 then
    raise exception 'Some names already exist' using errcode = 'ES002', detail = v_problems::text;
  end if;

  for a in select * from json_array_elements(coalesce(p -> 'artists', '[]')) loop
    insert into public.artists (name, is_spain_resident, commission_percent, gender, legal_name, tax_id,
                                address, iban, bank_name)
    values (btrim(a ->> 'name'), coalesce((a ->> 'is_spain_resident')::boolean, true),
            (a ->> 'commission_percent')::numeric, a ->> 'gender', a ->> 'legal_name', a ->> 'tax_id',
            a ->> 'address', a ->> 'iban', a ->> 'bank_name');
    n_artists := n_artists + 1;
  end loop;

  for pr in select * from json_array_elements(coalesce(p -> 'products', '[]')) loop
    select id into v_artist from public.artists where lower(name) = lower(btrim(pr ->> 'artist'));
    if v_artist is null then
      raise exception 'Unknown artist "%"', pr ->> 'artist' using errcode = 'ES002',
        detail = jsonb_build_array(format('Unknown artist "%s"', pr ->> 'artist'))::text;
    end if;
    select id into v_category from public.categories where lower(name) = lower(btrim(pr ->> 'category'));
    if v_category is null then
      raise exception 'Unknown category "%"', pr ->> 'category' using errcode = 'ES002',
        detail = jsonb_build_array(format('Unknown category "%s"', pr ->> 'category'))::text;
    end if;

    perform public.save_product(json_build_object(
      'name', btrim(pr ->> 'name'),
      'artist_id', v_artist,
      'category_id', v_category,
      'base_price_cents', (pr ->> 'base_price_cents')::bigint,
      'per_variant_pricing', coalesce((pr ->> 'per_variant_pricing')::boolean, false),
      'tax_percent_override', (pr ->> 'tax_percent_override')::numeric,
      'commission_percent_override', (pr ->> 'commission_percent_override')::numeric,
      'variants', coalesce(pr -> 'variants', '[]'::json)));
    n_products := n_products + 1;
    n_variants := n_variants + json_array_length(coalesce(pr -> 'variants', '[]'::json));
  end loop;

  return json_build_object('artists', n_artists, 'products', n_products, 'variants', n_variants);
end;
$$;

-- ------------------------------------------------------------ past sales
-- Which of these old receipt numbers are already imported.
create function public.imported_receipts(p_receipts text[])
returns setof text
language sql stable
set search_path = ''
as $$
  select legacy_receipt from public.orders where legacy_receipt = any (p_receipts)
$$;

-- p_receipts: [{"receipt", "at" (Madrid time, "2026-09-12 17:42:00"), "payment",
--               "discount" (a discount name or null),
--               "lines": [{"artist", "product", "category", "variant", "quantity",
--                          "base_cents" (line total before VAT, after discount),
--                          "total_cents" (line total incl. VAT),
--                          "commission_percent" (or null)}]}]
-- p_skip_existing: false = error ES002 if any receipt was imported before;
--                  true  = leave those out (to finish an interrupted import).
-- Returns how many receipts were added.
--
-- Amounts are taken as they were charged. The commission is the one given,
-- else the product's / artist's rate now, else the store default; the artist
-- share follows the same rules as a sale made in the app.
create function public.import_past_sales(p_receipts json, p_skip_existing boolean default false)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r json;
  l json;
  v_existing jsonb;
  v_order bigint;
  v_discount_percent numeric;
  v_artist bigint;
  v_product bigint;
  v_variant bigint;
  v_commission numeric;
  v_base bigint;
  v_total bigint;
  v_gross bigint;
  v_qty int;
  v_tax_pct numeric;
  n int := 0;
begin
  perform public.require_owner();

  select coalesce(jsonb_agg(format('Receipt %s was already imported', o.legacy_receipt)), '[]')
  into v_existing
  from public.orders o
  where o.legacy_receipt in (select x.value ->> 'receipt' from json_array_elements(p_receipts) x);
  if jsonb_array_length(v_existing) > 0 and not coalesce(p_skip_existing, false) then
    raise exception 'Some receipts were already imported' using errcode = 'ES002', detail = v_existing::text;
  end if;

  for r in select * from json_array_elements(p_receipts) loop
    continue when exists (select 1 from public.orders where legacy_receipt = r ->> 'receipt');

    v_discount_percent := 0;
    if r ->> 'discount' is not null then
      select percent into v_discount_percent from public.discounts where lower(name) = lower(r ->> 'discount');
      if not found then
        raise exception 'Unknown discount "%"', r ->> 'discount' using errcode = 'ES002',
          detail = jsonb_build_array(format('Receipt %s: unknown discount "%s"', r ->> 'receipt', r ->> 'discount'))::text;
      end if;
    end if;

    insert into public.orders (created_at, legacy_receipt, payment_method, discount_name, discount_percent,
                               subtotal_cents, discount_cents, tax_cents, total_cents)
    values (((r ->> 'at')::timestamp at time zone 'Europe/Madrid'), r ->> 'receipt', r ->> 'payment',
            case when v_discount_percent > 0 then (select name from public.discounts
                                                  where lower(name) = lower(r ->> 'discount')) end,
            v_discount_percent, 0, 0, 0, 0)
    returning id into v_order;

    for l in select * from json_array_elements(r -> 'lines') loop
      select id into v_artist from public.artists where lower(name) = lower(btrim(l ->> 'artist'));
      if v_artist is null then
        raise exception 'Unknown artist "%"', l ->> 'artist' using errcode = 'ES002',
          detail = jsonb_build_array(format('Receipt %s: unknown artist "%s"', r ->> 'receipt', l ->> 'artist'))::text;
      end if;
      v_product := null; v_variant := null;
      select id into v_product from public.products
      where artist_id = v_artist and lower(name) = lower(btrim(l ->> 'product'));
      if v_product is not null then
        select id into v_variant from public.variants
        where product_id = v_product
          and (lower(public.variant_label(attributes)) = lower(btrim(coalesce(l ->> 'variant', '')))
               or (coalesce(btrim(l ->> 'variant'), '') = ''
                   and (select count(*) from public.variants vv where vv.product_id = v_product) = 1))
        order by id limit 1;
      end if;

      v_qty := (l ->> 'quantity')::int;
      v_base := (l ->> 'base_cents')::bigint;
      v_total := (l ->> 'total_cents')::bigint;
      v_gross := case when v_discount_percent > 0 and v_discount_percent < 100
                      then round(v_base / (1 - v_discount_percent / 100)) else v_base end;
      v_commission := coalesce((l ->> 'commission_percent')::numeric,
                               (select commission_percent_override from public.products where id = v_product),
                               (select commission_percent from public.artists where id = v_artist),
                               public.rule_default_commission_percent());
      -- VAT as charged; shown as the usual rate when it rounds to one.
      v_tax_pct := case when v_base = 0 then 0 else round((v_total - v_base)::numeric * 100 / v_base, 2) end;
      select s.rate into v_tax_pct
      from (values (0::numeric), (4), (10), (21)) s (rate)
      where abs(s.rate - v_tax_pct) <= 0.5
      order by abs(s.rate - v_tax_pct) limit 1;
      v_tax_pct := coalesce(v_tax_pct,
                            case when v_base = 0 then 0 else round((v_total - v_base)::numeric * 100 / v_base, 2) end);

      insert into public.order_items (order_id, variant_id, product_id, artist_id, product_name, variant_label,
                                      category_name, quantity, unit_base_cents, tax_percent, commission_percent,
                                      discount_percent, base_cents, discount_cents, tax_cents, total_cents,
                                      artist_payout_cents, arrival_date)
      values (v_order, v_variant, v_product, v_artist, btrim(l ->> 'product'),
              coalesce(nullif(btrim(l ->> 'variant'), ''), 'Standard'), btrim(l ->> 'category'),
              v_qty, round(v_gross::numeric / v_qty), v_tax_pct, v_commission, v_discount_percent,
              v_base, v_gross - v_base, v_total - v_base, v_total,
              round((case when public.rule_discount_reduces_artist_payout() then v_base else v_gross end)
                    * (1 - v_commission / 100)),
              null);
    end loop;

    update public.orders o
    set subtotal_cents = t.base, discount_cents = t.discount, tax_cents = t.tax, total_cents = t.total
    from (select sum(base_cents) as base, sum(discount_cents) as discount,
                 sum(tax_cents) as tax, sum(total_cents) as total
          from public.order_items where order_id = v_order) t
    where o.id = v_order;
    n := n + 1;
  end loop;

  return n;
end;
$$;

revoke execute on function public.import_catalog(json), public.imported_receipts(text[]),
  public.import_past_sales(json, boolean) from public, anon;
grant execute on function public.import_catalog(json), public.imported_receipts(text[]),
  public.import_past_sales(json, boolean) to authenticated;

-- ----------------------------------------------------------------- logos
-- Signed-in users may read (only read) the logo files used in the PDFs.
create policy "Owners read logos" on storage.objects
  for select to authenticated
  using (bucket_id = 'Logos & Icons');
