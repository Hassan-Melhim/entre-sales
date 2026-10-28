"""After test_migrations.py has run, saves rows exactly as Supabase returns them
to test/fixtures/supabase_rows.json (used by test/supabase_mappers_test.dart).

    python supabase/tests/test_migrations.py && python supabase/tests/dump_fixtures.py
"""
import json, os
import psycopg

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADMIN = os.environ.get('PG_ADMIN', 'dbname=postgres user=postgres')
conn = psycopg.connect(ADMIN.replace('dbname=postgres', 'dbname=entre_sales_test'))

def rows(sql):
    return conn.execute(f"select coalesce(json_agg(t), '[]') from ({sql}) t").fetchone()[0]

span = "'2000-01-01', '2100-01-01'"
fixtures = {
    'artists': rows('select * from artists order by id'),
    'categories': rows("select c.*, (select coalesce(json_agg(a), '[]') from category_attributes a "
                       "where a.category_id = c.id) as category_attributes from categories c order by id"),
    'product_rows': rows('select * from product_rows order by id'),
    'discounts': rows('select * from discounts order by id'),
    'calendar_events': rows('select * from calendar_events order by id'),
    'order_rows': rows('select * from order_rows order by id'),
    'report_order_summaries': rows(f'select * from report_order_summaries({span})'),
    'report_sold_items': rows(f'select * from report_sold_items({span})'),
    'report_refunded_items': rows(f'select * from report_refunded_items({span})'),
    'report_stock_items': rows('select * from report_stock_items()'),
}
out = os.path.join(ROOT, 'test', 'fixtures', 'supabase_rows.json')
json.dump(fixtures, open(out, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
print('written', os.path.relpath(out, ROOT))
