"""Turns tool/demo_data/demo_data.json into supabase/scripts/load_demo_data.sql,
a script to paste into the Supabase SQL Editor.

    python tool/demo_data/make_demo_sql.py
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'demo_data.json')
OUT = os.path.join(HERE, '..', '..', 'supabase', 'scripts', 'load_demo_data.sql')

data = json.load(open(SRC, encoding='utf-8'))
# Only what the loader needs; keeps the script smaller.
slim = {k: data[k] for k in ('artists', 'products', 'sessions', 'events')}
blob = json.dumps(slim, ensure_ascii=False, separators=(',', ':'))
assert '$demo_json$' not in blob

SQL = r"""-- =============================================================================
--  LOAD DEMO DATA — to try the site before going live
-- =============================================================================
--  Adds the September 2026 inventory (40 artists, 266 products, 514 variants)
--  and a mock sales history from 1 June to 18 October 2026 (~1,550 sales,
--  refunds, restocks, 12 workshop sessions).
--
--  Every sale, refund and restock goes through the same database functions
--  the site uses, so all amounts are calculated exactly like real sales.
--  The sales are recorded as made by the first owner login.
--
--  Before: run the 3 setup files and create the owner logins (SETUP.md Part 3).
--  Only works on an empty store (no artists, products or sales yet).
--
--  Remove it all before going live with: supabase/scripts/clear_test_data.sql
--
--  How: Supabase → SQL Editor → New query → paste this whole file → Run.
--  Takes up to a minute.
-- =============================================================================
do $demo$
declare
  d           json := $demo_json$__BLOB__$demo_json$;
  v_owner     uuid;
  v_discount  bigint;
  artist_ids  jsonb := '{}';
  variant_ids bigint[][];   -- [product][variant], 1-based
  v_product   bigint;
  session_ids bigint[] := '{}';
  order_ids   bigint[] := '{}';
  manual      jsonb := '[]';
  p           json;
  e           json;
  l           json;
  lines       jsonb;
  items       jsonb;
  v_order     bigint;
  v_at        timestamptz;
  v_last_refund bigint;
  item_ids    bigint[];
  n_sales int := 0; n_refunds int := 0; n_restocks int := 0;
begin
  select id into v_owner from auth.users order by created_at limit 1;
  if v_owner is null then
    raise exception 'Create the owner logins first (SETUP.md Part 3c).';
  end if;
  if exists (select 1 from public.artists) or exists (select 1 from public.products)
     or exists (select 1 from public.orders) then
    raise exception 'The store already has data. Run clear_test_data.sql first to replace it.';
  end if;

  -- Act as the first owner (the functions only work for signed-in owners).
  perform set_config('request.jwt.claims',
                     json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);

  select id into v_discount from public.discounts where name = 'Friends & Family';

  -- ------------------------------------------------------------ artists
  for p in select * from json_array_elements(d -> 'artists') loop
    insert into public.artists (name, gender, address, legal_name, tax_id, iban, bank_name,
                                is_spain_resident, commission_percent)
    values (p ->> 'name', p ->> 'gender', p ->> 'address', p ->> 'legal_name', p ->> 'tax_id',
            p ->> 'iban', p ->> 'bank_name', (p ->> 'resident')::boolean, (p ->> 'commission')::numeric)
    returning jsonb_build_object(p ->> 'name', id) || artist_ids into artist_ids;
  end loop;

  -- ----------------------------------------------------------- products
  variant_ids := array_fill(null::bigint, array[
    json_array_length(d -> 'products'),
    (select max(json_array_length(x -> 'variants')) from json_array_elements(d -> 'products') x)]);
  for p, v_product in
    select x.value, x.ord from json_array_elements(d -> 'products') with ordinality as x (value, ord)
  loop
    declare
      new_id bigint;
      i int := 0;
      vid bigint;
    begin
      new_id := public.save_product(json_build_object(
        'name', p ->> 'name',
        'artist_id', (artist_ids ->> (p ->> 'artist'))::bigint,
        'category_id', (select id from public.categories where name = p ->> 'category'),
        'base_price_cents', (p ->> 'base')::bigint,
        'per_variant_pricing', (p ->> 'per_variant')::boolean,
        'tax_percent_override', (p ->> 'tax_override')::numeric,
        'commission_percent_override', (p ->> 'commission_override')::numeric,
        'variants', (select json_agg(json_build_object(
                        'attributes', v -> 'attrs',
                        'quantity', (v ->> 'qty')::int,
                        'price_override_cents', (v ->> 'price')::bigint,
                        'date_of_arrival', ((v ->> 'arrival')::timestamp)::date) order by o)
                     from json_array_elements(p -> 'variants') with ordinality as y (v, o))));
      for vid in select id from public.variants where product_id = new_id order by id loop
        i := i + 1;
        variant_ids[v_product][i] := vid;
      end loop;
    end;
  end loop;

  -- ----------------------------------------------------------- sessions
  for p in select * from json_array_elements(d -> 'sessions') loop
    insert into public.calendar_events (google_id, title, start_at, end_at)
    values (p ->> 'google_id', p ->> 'title',
            (p ->> 'start')::timestamp at time zone 'Europe/Madrid',
            (p ->> 'end')::timestamp at time zone 'Europe/Madrid')
    returning session_ids || id into session_ids;
  end loop;

  -- ------------------------------------------------------------ history
  alter table public.refunds disable trigger keep_history;

  for e in select * from json_array_elements(d -> 'events') loop
    v_at := (e ->> 'at')::timestamp at time zone 'Europe/Madrid';
    case e ->> 't'
      when 'sale' then
        select jsonb_agg(jsonb_build_object(
                 'variant_id', variant_ids[(z.ln ->> 0)::int + 1][(z.ln ->> 1)::int + 1],
                 'quantity', (z.ln ->> 2)::int) order by z.o)
        into lines
        from json_array_elements(e -> 'lines') with ordinality as z (ln, o);
        v_order := public.checkout(lines, e ->> 'pay',
                                   case when e ->> 'discount' is not null then v_discount end, null);
        update public.orders
        set created_at = v_at, calendar_event_id = null, event_tag_source = null
        where id = v_order;
        order_ids := order_ids || v_order;
        if e ->> 'manual_session' is not null then
          manual := manual || jsonb_build_array(jsonb_build_array(v_order,
                      session_ids[(e ->> 'manual_session')::int + 1]));
        end if;
        n_sales := n_sales + 1;
      when 'refund' then
        v_order := order_ids[(e ->> 'sale')::int + 1];
        select array_agg(id order by id) into item_ids from public.order_items where order_id = v_order;
        select jsonb_object_agg(item_ids[(z.ln ->> 0)::int + 1]::text, (z.ln ->> 1)::int)
        into items
        from json_array_elements(e -> 'lines') as z (ln);
        select coalesce(max(id), 0) into v_last_refund from public.refunds;
        perform public.refund(v_order, items);
        update public.refunds set created_at = v_at where id > v_last_refund;
        n_refunds := n_refunds + 1;
      when 'restock' then
        perform public.restock(variant_ids[(e ->> 'p')::int + 1][(e ->> 'v')::int + 1],
                               (e ->> 'q')::int, v_at::date);
        n_restocks := n_restocks + 1;
    end case;
  end loop;

  alter table public.refunds enable trigger keep_history;

  -- Workshop tags: automatic from the session times, then the ones made by hand.
  perform public.auto_tag_sales();
  for l in select * from jsonb_array_elements(manual) loop
    perform public.set_order_session((l ->> 0)::bigint, (l ->> 1)::bigint);
  end loop;

  -- The demo's own setup isn't part of the history of changes.
  truncate public.audit_log restart identity;

  raise notice 'Demo data loaded: % artists, % products, % sales, % refunds, % restocks, % sessions',
    (select count(*) from public.artists), (select count(*) from public.products),
    n_sales, n_refunds, n_restocks, array_length(session_ids, 1);
end
$demo$;
"""

open(OUT, 'w', encoding='utf-8').write(SQL.replace('__BLOB__', blob))
print(f'written {os.path.relpath(OUT)} ({os.path.getsize(OUT) // 1024} KB)')
