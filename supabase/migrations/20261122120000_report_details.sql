-- Migration 7: details the Reports screen needs.
--
--  * report_order_summaries also says whether the sale happened during a
--    workshop / event session (calendar_event_id).
--  * report_stock_items also gives each unit's price, VAT, commission and
--    the artist's residency, to value the stock on the shelf.
-- New columns are added at the end; older app versions ignore them.

drop function if exists public.report_order_summaries(timestamptz, timestamptz);
create function public.report_order_summaries(p_from timestamptz, p_to timestamptz)
returns table (id bigint, created_at timestamptz, payment_method text,
               discount_cents bigint, tax_cents bigint, total_cents bigint, calendar_event_id bigint)
language sql stable
set search_path = ''
as $$
  select o.id, o.created_at, o.payment_method, o.discount_cents, o.tax_cents, o.total_cents, o.calendar_event_id
  from public.orders o
  where o.created_at >= p_from and o.created_at < p_to
  order by o.id
$$;

drop function if exists public.report_stock_items();
create function public.report_stock_items()
returns table (id bigint, product_id bigint, product_name text, artist_name text, category_name text,
               quantity integer, arrival date,
               artist_id bigint, artist_resident boolean, unit_base_cents bigint,
               tax_percent numeric, commission_percent numeric)
language sql stable
set search_path = ''
as $$
  -- Same rates a sale would use now (see checkout).
  select v.id, p.id, p.name, a.name, c.name, v.quantity, v.date_of_arrival,
         a.id, a.is_spain_resident,
         case when p.per_variant_pricing and v.price_override_cents is not null
              then v.price_override_cents else p.base_price_cents end,
         coalesce(p.tax_percent_override, c.tax_percent),
         coalesce(p.commission_percent_override, a.commission_percent, public.rule_default_commission_percent())
  from public.variants v
  join public.products p on p.id = v.product_id
  join public.artists a on a.id = p.artist_id
  join public.categories c on c.id = p.category_id
  where v.quantity > 0
  order by v.id
$$;

revoke execute on function public.report_order_summaries(timestamptz, timestamptz) from public, anon;
revoke execute on function public.report_stock_items() from public, anon;
grant execute on function public.report_order_summaries(timestamptz, timestamptz) to authenticated;
grant execute on function public.report_stock_items() to authenticated;
