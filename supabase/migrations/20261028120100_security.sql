-- =============================================================================
--  Entre Sales — 2 of 3: who can read and write what
-- =============================================================================
--  * Nobody who is not signed in can read or change anything.
--  * The three owners are equal: every signed-in user has the same rights.
--    (Sign-ups are closed in Supabase → Authentication, so only the accounts
--    created there can sign in.)
--  * Sales, sale lines and refunds can only be written by the checkout /
--    refund functions (file 3). They can never be edited or deleted.
--  * Stock changes only through those functions, a restock, or saving a
--    product, so two devices can't overwrite each other's stock counts.
--  * Every change is written to audit_log with who made it.
-- =============================================================================

-- ------------------------------------------------------------ table rights
revoke all on all tables in schema public from anon, authenticated;

grant select on all tables in schema public to authenticated;

grant insert, update, delete on
  public.settings,
  public.artists,
  public.discounts,
  public.calendar_events
to authenticated;

-- Products: created / edited with save_product(); quick commission edits and
-- deleting a product without sales are allowed directly.
grant update (commission_percent_override), delete on public.products to authenticated;

-- Categories: created / edited with save_category(); deleting one without
-- products is allowed directly.
grant delete on public.categories to authenticated;

-- variants, category_attributes, orders, order_items, refunds, audit_log:
-- read-only for users; written only by the functions in file 3.

-- ------------------------------------------------------- row level security
alter table public.settings            enable row level security;
alter table public.artists             enable row level security;
alter table public.categories          enable row level security;
alter table public.category_attributes enable row level security;
alter table public.products            enable row level security;
alter table public.variants            enable row level security;
alter table public.discounts           enable row level security;
alter table public.calendar_events     enable row level security;
alter table public.orders              enable row level security;
alter table public.order_items         enable row level security;
alter table public.refunds             enable row level security;
alter table public.audit_log           enable row level security;

-- One policy per table: signed-in owners only. What each owner may do on top
-- of reading is limited by the grants above.
create policy owners_all on public.settings            for all to authenticated using (true) with check (true);
create policy owners_all on public.artists             for all to authenticated using (true) with check (true);
create policy owners_all on public.categories          for all to authenticated using (true) with check (true);
create policy owners_all on public.category_attributes for all to authenticated using (true) with check (true);
create policy owners_all on public.products            for all to authenticated using (true) with check (true);
create policy owners_all on public.variants            for all to authenticated using (true) with check (true);
create policy owners_all on public.discounts           for all to authenticated using (true) with check (true);
create policy owners_all on public.calendar_events     for all to authenticated using (true) with check (true);
create policy owners_read on public.orders             for select to authenticated using (true);
create policy owners_read on public.order_items        for select to authenticated using (true);
create policy owners_read on public.refunds            for select to authenticated using (true);
create policy owners_read on public.audit_log          for select to authenticated using (true);

-- ---------------------------------------------------------------- audit log
create function public.audit_row() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  rec    jsonb := to_jsonb(coalesce(new, old));
begin
  -- Stock moving because of a sale or refund is already recorded by the sale.
  if tg_table_name = 'variants' and tg_op = 'UPDATE'
     and coalesce(current_setting('app.stock_movement', true), '') = 'sale' then
    return null;
  end if;

  insert into public.audit_log (user_id, user_email, table_name, row_id, action, old_data, new_data)
  values (
    (claims ->> 'sub')::uuid,
    claims ->> 'email',
    tg_table_name,
    coalesce(rec ->> 'id', rec ->> 'key'),
    tg_op,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end
  );
  return null;
end;
$$;

create trigger audit after insert or update or delete on public.settings            for each row execute function public.audit_row();
create trigger audit after insert or update or delete on public.artists             for each row execute function public.audit_row();
create trigger audit after insert or update or delete on public.categories          for each row execute function public.audit_row();
create trigger audit after insert or update or delete on public.category_attributes for each row execute function public.audit_row();
create trigger audit after insert or update or delete on public.products            for each row execute function public.audit_row();
create trigger audit after insert or update or delete on public.variants            for each row execute function public.audit_row();
create trigger audit after insert or update or delete on public.discounts           for each row execute function public.audit_row();
create trigger audit after insert or update or delete on public.calendar_events     for each row execute function public.audit_row();
create trigger audit after insert or update or delete on public.orders              for each row execute function public.audit_row();
create trigger audit after insert or update or delete on public.refunds             for each row execute function public.audit_row();

-- Belt and braces: even the database owner can't quietly rewrite history.
create function public.forbid_change() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% rows cannot be changed or deleted', tg_table_name;
end;
$$;

create trigger keep_history before update or delete on public.audit_log
  for each row execute function public.forbid_change();
create trigger keep_history before update or delete on public.refunds
  for each row execute function public.forbid_change();
create trigger keep_history before delete on public.orders
  for each row execute function public.forbid_change();
create trigger keep_history before delete on public.order_items
  for each row execute function public.forbid_change();
