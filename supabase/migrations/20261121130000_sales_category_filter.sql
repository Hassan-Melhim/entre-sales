-- Migration 6: filter the sales list by category.
--
-- A sale is listed when at least one of its items is in the category: either
-- the category the item was sold under (saved on the sale) or the product's
-- category today (in case the category was renamed since). The whole sale is
-- returned, with all its items and totals.

drop function if exists public.search_orders(timestamptz, timestamptz, bigint, text);

create function public.search_orders(p_from timestamptz default null, p_to timestamptz default null,
                                     p_session_id bigint default null, p_query text default '',
                                     p_category_id bigint default null)
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
    and (p_category_id is null
         or exists (select 1
                    from public.order_items i
                    left join public.products p on p.id = i.product_id
                    where i.order_id = o.id
                      and (p.category_id = p_category_id
                           or i.category_name = (select c.name from public.categories c where c.id = p_category_id))))
  order by o.created_at desc, o.id desc
$$;

revoke execute on function public.search_orders(timestamptz, timestamptz, bigint, text, bigint) from public, anon;
grant execute on function public.search_orders(timestamptz, timestamptz, bigint, text, bigint) to authenticated;
