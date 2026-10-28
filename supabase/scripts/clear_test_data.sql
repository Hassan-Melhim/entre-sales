-- =============================================================================
--  CLEAR TEST DATA — run once, on the day the store starts using the site
-- =============================================================================
--  ⚠ Deletes ALL artists, products, stock, sales, refunds, workshop sessions
--    and the history of changes. It cannot be undone.
--    Download a backup first (Settings → Backup) if anything should be kept.
--
--  Keeps: categories (and their fields), discounts, store details, logins.
--  Sale numbers start again from 1.
--
--  How: Supabase → SQL Editor → New query → paste → Run.
--  (Sales can't be deleted from the app on purpose; this is the only way.)
-- =============================================================================
truncate table
  public.refunds,
  public.order_items,
  public.orders,
  public.calendar_events,
  public.variants,
  public.products,
  public.artists,
  public.audit_log
restart identity;
