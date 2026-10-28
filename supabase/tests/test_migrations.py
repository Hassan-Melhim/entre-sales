"""Runs the three migrations on a throw-away local PostgreSQL database and
checks sales, refunds, stock, security and the money formulas.

    python supabase/tests/test_migrations.py   (needs a local PostgreSQL + psycopg)
"""
import glob, json, os, re, sys, threading, uuid
import psycopg

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ADMIN = os.environ.get('PG_ADMIN', 'dbname=postgres user=postgres')
DB = 'entre_sales_test'
OWNER = str(uuid.uuid4())

failures = 0
def check(cond, msg):
    global failures
    print(('  ok   ' if cond else '  FAIL ') + msg)
    if not cond: failures += 1

def setup():
    with psycopg.connect(ADMIN, autocommit=True) as c:
        c.execute(f'drop database if exists {DB}')
        c.execute(f'create database {DB}')
        for r in ('anon', 'authenticated', 'service_role'):
            c.execute(f"do $$ begin if exists (select 1 from pg_roles where rolname='{r}') then "
                      f"execute 'drop owned by {r} cascade'; end if; end $$")
    conninfo = ADMIN.replace('dbname=postgres', f'dbname={DB}')
    with psycopg.connect(conninfo, autocommit=True) as c:
        c.execute("do $$ begin create role anon nologin; exception when duplicate_object then null; end $$")
        c.execute("do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$")
        c.execute("do $$ begin create role service_role nologin bypassrls; exception when duplicate_object then null; end $$")
        stub = open(os.path.join(HERE, 'supabase_stub.sql')).read()
        stub = re.sub(r'create role [^;]+;\n', '', stub)
        c.execute(stub)
        c.execute('insert into auth.users (id, email) values (%s, %s)', (OWNER, 'owner@example.com'))
        for f in sorted(glob.glob(os.path.join(ROOT, 'supabase/migrations/*.sql'))):
            c.execute(open(f).read())
            print('applied', os.path.basename(f))
    return conninfo

def as_owner(conninfo, signed_in=True):
    c = psycopg.connect(conninfo, autocommit=True)
    role = 'authenticated' if signed_in else 'anon'
    claims = json.dumps({'sub': OWNER, 'email': 'owner@example.com', 'role': role}) if signed_in else ''
    c.execute(f'set role {role}')
    c.execute("select set_config('request.jwt.claims', %s, false)", (claims,))
    return c

def one(c, sql, args=()):
    return c.execute(sql, args).fetchone()

def main():
    conninfo = setup()
    c = as_owner(conninfo)

    print('starting data')
    check(one(c, 'select count(*) from categories')[0] == 15, '15 categories')
    check(one(c, "select tax_percent from categories where name='Books & Zines'")[0] == 4, 'books 4% VAT')
    check(one(c, "select options from category_attributes a join categories c on c.id=a.category_id "
                 "where c.name='Clothing' and a.name='Size'")[0] == ['XS', 'XS/S', 'S', 'M', 'L', 'XL'], 'clothing sizes')
    check(one(c, "select name, percent from discounts")[0:2] == ('Friends & Family', 5), 'F&F 5%')

    rules = open(os.path.join(ROOT, 'lib/domain/business_rules.dart')).read()
    dart_comm = float(re.search(r'defaultCommissionPercent = ([\d.]+)', rules).group(1))
    dart_disc = re.search(r'discountReducesArtistPayout = (\w+)', rules).group(1) == 'true'
    check(float(one(c, 'select rule_default_commission_percent()')[0]) == dart_comm, 'SQL default commission matches Dart')
    check(one(c, 'select rule_discount_reduces_artist_payout()')[0] == dart_disc, 'SQL discount rule matches Dart')

    print('catalog')
    artist = one(c, "insert into artists (name, is_spain_resident) values ('Ana', true) returning id")[0]
    posters = one(c, "select id from categories where name='Prints & Posters'")[0]
    pid = one(c, 'select save_product(%s)', (json.dumps({
        'name': 'Sunset print', 'artist_id': artist, 'category_id': posters, 'base_price_cents': 10000,
        'per_variant_pricing': False, 'variants': [
            {'attributes': {'Design': 'Sun', 'Size': 'A3'}, 'quantity': 1, 'date_of_arrival': '2026-10-01'},
            {'attributes': {'Size': 'A2'}, 'quantity': 2, 'date_of_arrival': '2026-10-01'}]}),))[0]
    prod = one(c, 'select row_to_json(r) from search_products(%s) r', ('sunset',))[0]
    check(prod['name'] == 'Sunset print' and len(prod['variants']) == 2, 'product saved with 2 variants')
    check(list(prod['variants'][0]['attributes'].keys()) == ['Design', 'Size'], 'field order kept as typed')
    a3, a2 = [v['id'] for v in prod['variants']]
    check(one(c, 'select variant_label(attributes) from variants where id=%s', (a3,))[0] == 'Sun · A3', 'variant label')
    check(len(c.execute('select * from search_products(%s)', ('ana',)).fetchall()) == 1, 'search by artist name')

    print('checkout')
    disc = one(c, 'select id from discounts')[0]
    oid = one(c, 'select checkout(%s, %s, %s)', (json.dumps([{'variant_id': a3, 'quantity': 1}]), 'Card', disc))[0]
    o = one(c, 'select subtotal_cents, tax_cents, total_cents, created_by::text from orders where id=%s', (oid,))
    check(o[:3] == (9500, 1995, 11495), 'totals with 5% discount (95 + 21% = 114.95)')
    check(o[3] == OWNER, 'sale records who made it')
    it = one(c, 'select artist_payout_cents, commission_percent, variant_label, arrival_date::text from order_items where order_id=%s', (oid,))
    check(it[0] == 6500 and float(it[1]) == 35, 'artist paid 65 € on full price, 35%')
    check(it[2] == 'Sun · A3' and it[3] == '2026-10-01', 'line snapshot')
    check(one(c, 'select quantity from variants where id=%s', (a3,))[0] == 0, 'stock lowered')

    try:
        c.execute('select checkout(%s, %s)', (json.dumps([{'variant_id': a2, 'quantity': 3}]), 'Cash'))
        check(False, 'over-selling refused')
    except psycopg.Error as e:
        check(e.sqlstate == 'ES001' and 'A2' in (e.diag.message_detail or ''), 'over-selling refused with ES001 + detail')
    check(one(c, 'select count(*) from orders')[0] == 1, 'nothing recorded by the failed sale')

    print('commission priority')
    c.execute('update artists set commission_percent = 40 where id=%s', (artist,))
    oid2 = one(c, 'select checkout(%s, %s)', (json.dumps([{'variant_id': a2, 'quantity': 1}]), 'Cash'))[0]
    check(one(c, 'select artist_payout_cents from order_items where order_id=%s', (oid2,))[0] == 6000, 'artist 40%')
    c.execute('update products set commission_percent_override = 20 where id=%s', (pid,))
    c.execute('select restock(%s, 2, %s)', (a3, '2026-10-20'))
    oid3 = one(c, 'select checkout(%s, %s)', (json.dumps([{'variant_id': a3, 'quantity': 1}]), 'Cash'))[0]
    check(one(c, 'select artist_payout_cents from order_items where order_id=%s', (oid3,))[0] == 8000, 'product 20% wins')
    check(float(one(c, 'select commission_percent from artists where id=%s', (artist,))[0]) == 40, 'artist rate untouched')
    check(one(c, 'select artist_payout_cents from order_items where order_id=%s', (oid,))[0] == 6500, 'past sale unchanged')
    check(one(c, 'select date_of_arrival::text from variants where id=%s', (a3,))[0] == '2026-10-20', 'restock overwrites arrival')

    print('refunds')
    c.execute('select restock(%s, 5, %s)', (a2, '2026-10-21'))
    oid4 = one(c, 'select checkout(%s, %s)', (json.dumps([{'variant_id': a2, 'quantity': 3}]), 'Card'))[0]
    item = one(c, 'select id, total_cents from order_items where order_id=%s', (oid4,))
    c.execute('select refund(%s, %s)', (oid4, json.dumps({str(item[0]): 1})))
    check(one(c, 'select status from orders where id=%s', (oid4,))[0] == 'partially_refunded', 'partial refund status')
    c.execute('select refund(%s, %s)', (oid4, json.dumps({str(item[0]): 5})))
    check(one(c, 'select status from orders where id=%s', (oid4,))[0] == 'refunded', 'full refund (capped at 2 more)')
    check(one(c, 'select sum(r.total_cents) from refunds r join order_items i on i.id=r.order_item_id where i.order_id=%s', (oid4,))[0] == item[1],
          'refund shares add up to the line')
    check(one(c, 'select quantity from variants where id=%s', (a2,))[0] == 5 + 2 - 1, 'stock back after refund')  # 2-1 sold earlier, +5, -3, +3

    print('product edits from another device')
    c.execute('select checkout(%s, %s)', (json.dumps([{'variant_id': a2, 'quantity': 1}]), 'Cash'))  # sold while form open
    before = 6  # what the form showed
    c.execute('select save_product(%s)', (json.dumps({
        'id': pid, 'name': 'Sunset print', 'artist_id': artist, 'category_id': posters, 'base_price_cents': 10000,
        'per_variant_pricing': False, 'commission_percent_override': 20, 'variants': [
            {'id': a3, 'attributes': {'Design': 'Sun', 'Size': 'A3'}, 'quantity': 1, 'quantity_before': 1, 'date_of_arrival': '2026-10-20'},
            {'id': a2, 'attributes': {'Size': 'A2'}, 'quantity': before + 4, 'quantity_before': before, 'date_of_arrival': '2026-10-22'}]}),))
    check(one(c, 'select quantity from variants where id=%s', (a2,))[0] == 5 + 4, 'form adds 4 without undoing the other sale')

    print('workshops')
    sess = one(c, "insert into calendar_events (title, start_at, end_at) values ('Ceramics workshop', now() - interval '1 hour', now() + interval '1 hour') returning id")[0]
    oid5 = one(c, 'select checkout(%s, %s)', (json.dumps([{'variant_id': a2, 'quantity': 1}]), 'Cash'))[0]
    check(one(c, 'select calendar_event_id, event_tag_source from orders where id=%s', (oid5,)) == (sess, 'auto'), 'auto-tagged')
    c.execute('select set_order_session(%s, null)', (oid5,))
    check(one(c, 'select auto_tag_sales()')[0] >= 0 and
          one(c, 'select event_tag_source from orders where id=%s', (oid5,))[0] == 'manual', 'manual untag kept')

    print('reports')
    rows = c.execute("select * from report_sold_items(now() - interval '1 day', now() + interval '1 day')").fetchall()
    check(len(rows) == 6, 'sold items in range')
    check(len(c.execute("select * from report_refunded_items(now() - interval '1 day', now() + interval '1 day', %s)", (artist,)).fetchall()) == 2,
          'refunded items for the artist')
    check(len(c.execute('select * from report_stock_items()').fetchall()) == 2, 'stock items')
    check(len(c.execute("select * from search_orders(now() - interval '1 day', now() + interval '1 day', null, 'sunset')").fetchall()) == 6,
          'order search')

    print('security')
    for sql, what in [
        ("update orders set total_cents = 1 where id = %s" % oid, 'cannot edit a sale'),
        ("delete from orders where id = %s" % oid, 'cannot delete a sale'),
        ("update order_items set total_cents = 1", 'cannot edit sale lines'),
        ("insert into orders (payment_method, subtotal_cents, discount_cents, tax_cents, total_cents) values ('Cash',0,0,0,0)", 'cannot insert a sale directly'),
        ("update variants set quantity = 99", 'cannot set stock directly'),
        ("delete from audit_log", 'cannot delete the audit log'),
        ("update products set base_price_cents = 1", 'cannot change price outside the form'),
        ("delete from artists where id = %s" % artist, 'cannot delete an artist with sales'),
        ("delete from products where id = %s" % pid, 'cannot delete a product with sales'),
    ]:
        try:
            c.execute(sql)
            n = c.rowcount
            check(n == 0, what + f' (rows changed: {n})')
        except psycopg.Error:
            check(True, what)
    check(one(c, "select count(*) from audit_log where table_name='orders' and action='INSERT'")[0] == 6, 'sales in audit log')
    check(one(c, "select count(*) from audit_log where table_name='variants' and action='UPDATE' and user_email='owner@example.com'")[0] >= 2,
          'restocks/edits in audit log (sales not duplicated)')

    anon = as_owner(conninfo, signed_in=False)
    for sql, what in [('select * from artists', 'signed-out cannot read artists'),
                      ('select * from search_products()', 'signed-out cannot search'),
                      ("select checkout('[{\"variant_id\":1,\"quantity\":1}]', 'Cash')", 'signed-out cannot sell')]:
        try:
            rows = anon.execute(sql).fetchall()
            check(len(rows) == 0, what)
        except psycopg.Error:
            check(True, what)

    print('two devices selling the last unit at once')
    last = one(c, 'select save_product(%s)', (json.dumps({
        'name': 'Unique vase', 'artist_id': artist, 'category_id': posters, 'base_price_cents': 5000,
        'per_variant_pricing': False, 'variants': [{'attributes': {}, 'quantity': 1, 'date_of_arrival': '2026-10-01'}]}),))[0]
    vid = one(c, 'select id from variants where product_id=%s', (last,))[0]
    results = []
    def sell():
        d = as_owner(conninfo)
        try:
            d.execute('select checkout(%s, %s)', (json.dumps([{'variant_id': vid, 'quantity': 1}]), 'Cash'))
            results.append('sold')
        except psycopg.Error as e:
            results.append(e.sqlstate)
    ts = [threading.Thread(target=sell) for _ in range(5)]
    [t.start() for t in ts]; [t.join() for t in ts]
    check(results.count('sold') == 1 and results.count('ES001') == 4, f'only one sale wins {results}')
    check(one(c, 'select quantity from variants where id=%s', (vid,))[0] == 0, 'stock is 0, never negative')

    print('repeated attempt of the same sale')
    pid2 = one(c, 'select save_product(%s)', (json.dumps({
        'name': 'Tote bag', 'artist_id': artist, 'category_id': posters, 'base_price_cents': 2000,
        'per_variant_pricing': False, 'variants': [{'attributes': {}, 'quantity': 3, 'date_of_arrival': '2026-10-01'}]}),))[0]
    tote = one(c, 'select id from variants where product_id=%s', (pid2,))[0]
    ref = str(uuid.uuid4())
    line = json.dumps([{'variant_id': tote, 'quantity': 1}])
    first = one(c, 'select checkout(%s, %s, null, %s)', (line, 'Cash', ref))[0]
    again = one(c, 'select checkout(%s, %s, null, %s)', (line, 'Cash', ref))[0]
    check(first == again, 'same sale reference returns the same sale')
    check(one(c, 'select quantity from variants where id=%s', (tote,))[0] == 2, 'stock lowered only once')
    other = one(c, 'select checkout(%s, %s, null, %s)', (line, 'Cash', str(uuid.uuid4())))[0]
    check(other != first, 'a new reference is a new sale')

    print()
    print('FAILURES:', failures)
    sys.exit(1 if failures else 0)

main()
