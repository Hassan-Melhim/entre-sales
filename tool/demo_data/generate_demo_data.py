"""Builds assets/demo/demo_data.json from the store's inventory export.

Usage (from the project root):
    pip install openpyxl
    python tool/demo_data/generate_demo_data.py path/to/ES_Inventory_12Sept2026.xlsx

What it does
  1. Reads the sheet and maps every row to a product + variant
     (see catalog_mapping.py for every grouping decision).
  2. Prices in the sheet include VAT; the base price (before VAT) is
     calculated from the category's VAT rate.
  3. Simulates a sales history (1 Jun – 18 Oct 2026) following the store's
     opening hours, with workshops, discounts, refunds and restocks.
  4. Works out the starting stock so that, after replaying the history,
     stock ends at the quantity in the sheet (negative quantities → 0,
     café items → a large stock).
  5. Replays everything once to prove stock never goes below zero.

The output is deterministic (fixed random seed).
"""
import collections
import datetime as dt
import json
import math
import os
import random
import re
import sys

import openpyxl

sys.path.insert(0, os.path.dirname(__file__))
from catalog_mapping import (  # noqa: E402
    ARTISTS, ARTIST_PROFILES, AUTO_FINISH_ARTISTS, CATEGORIES, EXCLUDE, LARGE_STOCK_CATEGORY,
    LARGE_STOCK_FINAL, PRICE_FIX, SPLIT_SIZES, STORE_ARTIST)

SEED = 2026
HISTORY_START = dt.date(2026, 6, 1)
HISTORY_END = dt.date(2026, 10, 18)  # last full day before the demo was made
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'demo', 'demo_data.json')

# Opening hours: Mon, Wed–Sat 11–21, Sun 14–19, Tue closed. weekday(): Mon=0.
OPENING = {0: (11, 21), 2: (11, 21), 3: (11, 21), 4: (11, 21), 5: (11, 21), 6: (14, 19)}
HOUR_WEIGHT = {11: 3, 12: 5, 13: 8, 14: 7, 15: 5, 16: 5, 17: 7, 18: 10, 19: 11, 20: 7}
ORDERS_PER_DAY = {0: 10, 2: 10, 3: 12, 4: 16, 5: 19, 6: 9}

# Relative popularity of café items. Taken from how far below zero each item
# went in the sheet (sold without stock tracking); coffees had no count, so
# they get a reasonable weight.
CAFE_WEIGHT = {
    ('Beer (sin alcohol)', 'Lager'): 707, ('Rosé Wine', 'Glass'): 196, ("L'herencia Wine", 'Glass'): 145,
    ('Beer (sin alcohol)', 'IPA'): 91, ('Hibiscus kombucha drink', None): 62, ('La Natural Wine', None): 39,
    ('Baby Jalebi Food', None): 36, ('Living Things Drink', 'Peach & Orange'): 24, ('Bifana', None): 12,
    ('Living Things Drink', 'Watermelon & Lime'): 6, ('BESSO Drink', 'Lima Limón'): 7,
    ('BESSO Drink', 'Melocotón & Maracuyá'): 3, ('BESSO Drink', 'Fresa Pasión'): 2,
    ('Café', 'Americano'): 60, ('Café', 'Con leche'): 55, ('Café', 'Cortado'): 50, ('Café', 'Espresso'): 40,
    ('Café', 'Flat White'): 40, ('Café', 'Iced Latte'): 35, ('Matcha', 'Iced'): 30, ('Matcha', 'Latte'): 25,
    ('Earl Grey Cake (slice)', None): 15, ('Ginger Cookie', None): 15, ('Rosé Wine', 'Bottle'): 2,
    ("L'herencia Wine", 'Bottle'): 2,
}
ALCOHOL = {'Beer (sin alcohol)', 'Rosé Wine', "L'herencia Wine", 'La Natural Wine'}
COFFEE = {'Café', 'Matcha', 'Earl Grey Cake (slice)', 'Ginger Cookie'}

# Demo-only: one product with a manual tax rate, to show the feature.
TAX_OVERRIDE = {('Matilde Cunha', 'Photo Strip'): 10.0}

# Demo-only: products with their own store commission (the artist's rate is
# unchanged), to show the per-product commission override.
COMMISSION_OVERRIDE = {
    ('Cora', 'Ceramic Butter Dish'): 30.0,
    ('Ana Drucker', 'Bookend'): 40.0,
}

WORKSHOPS = [
    ('Ceramics workshop with Cora', 'Cora'),
    ('Risograph printing workshop – Jumbo Press', 'Jumbo Press'),
    ('Pin making workshop with Celina', 'Celina'),
    ('Jewellery workshop – Je Jewellery', 'Je Jewellery'),
    ('Embroidery workshop with Elleonor', 'Elleonor'),
    ('Zine making workshop – RizoMasr', 'RizoMasr'),
    ('Candle workshop', STORE_ARTIST),
    ('Linocut workshop with Lino', 'Lino'),
]

rng = random.Random(SEED)


# ====================================================================== catalog

def clean(name):
    name = (name or '').strip()
    name = re.sub(r'^-\s*', '', name).strip()
    return re.sub(r'\s+', ' ', name)


def auto_finish(name):
    """'Branch Earrings - gold' -> ('Branch Earrings', {'Finish': 'Gold'}), etc."""
    name = name.replace('Earring + Earcuff', 'Earrings + Earcuff')
    m = re.match(r'^(.*?)\s*-\s*(gold|silver|chunky|blue)$', name, re.I)
    if m:
        base, suffix = m.group(1), m.group(2).lower()
        if suffix == 'chunky':
            return base, {'Finish': 'Silver', 'Style': 'Chunky'}
        return base, {'Finish': suffix.capitalize()}
    m = re.match(r'^(.*?)\s*\((.+)\)$', name)
    if m:
        return m.group(1), {'Finish': m.group(2)}
    return name, {}


def base_cents_from_shelf(price_eur, tax):
    """Base price (before VAT) whose VAT-included price rounds back to the shelf price."""
    shelf = round(price_eur * 100)
    guess = round(shelf / (1 + tax / 100))
    for b in (guess, guess - 1, guess + 1):
        if round(b * (1 + tax / 100)) == shelf:
            return b
    return guess


def read_rows(path):
    ws = openpyxl.load_workbook(path, data_only=True).worksheets[0]
    rows = []
    for r in ws.iter_rows(min_row=2, values_only=True):
        if not any(v is not None for v in r):
            continue
        artist = (r[0] or '').strip()
        rows.append(dict(artist=artist, name=clean(r[1]), ref=r[2], price=float(r[3]), qty=int(r[4] or 0)))
    return rows


def build_catalog(rows):
    cat_by_name = {c[0]: c for c in CATEGORIES}
    products = collections.OrderedDict()  # (artist, product) -> dict

    # Pass 1: map rows.
    mapped = []
    for row in rows:
        a = row['artist']
        if (a, row['name']) in EXCLUDE:
            continue
        cfg = ARTISTS[a]
        price = PRICE_FIX.get((a, row['name']), row['price'])
        if row['name'] in cfg['groups']:
            g = cfg['groups'][row['name']]
            pname, attrs = g[0], dict(g[1])
            cat = g[2] if len(g) > 2 else cfg['category']
        elif a in AUTO_FINISH_ARTISTS:
            pname, attrs = auto_finish(row['name'])
            cat = cfg['category']
        else:
            pname, attrs, cat = row['name'], {}, cfg['category']
        mapped.append(dict(row, artist=a, product=pname, attrs=attrs, category=cat, price=price))

    # Auto-finish: a single row keeps only an explicit finish; in a group of
    # several rows, the plain one is the silver version.
    groups = collections.defaultdict(list)
    for m in mapped:
        groups[(m['artist'], m['product'])].append(m)
    for (a, p), ms in groups.items():
        if a in AUTO_FINISH_ARTISTS and len(ms) > 1:
            for m in ms:
                m['attrs'].setdefault('Finish', 'Silver')

    # Pass 2: assemble products and variants.
    for m in mapped:
        key = (m['artist'], m['product'])
        artist_name = STORE_ARTIST if m['artist'] == '?' else m['artist']
        prod = products.setdefault(key, dict(artist=artist_name, source_artist=m['artist'], name=m['product'],
                                             category=m['category'], variants=[]))
        if prod['category'] != m['category']:
            raise SystemExit(f'Category clash for {key}: {prod["category"]} vs {m["category"]}')
        same = [v for v in prod['variants'] if v['attrs'] == m['attrs']]
        if same and same[0]['price'] == m['price']:
            same[0]['qty'] += max(0, m['qty'])  # exact duplicate row: merge
            same[0]['raw_qty'] += m['qty']
            continue
        if same:  # same name, different price: tell them apart by reference
            same[0]['attrs'] = {**same[0]['attrs'], 'Style': same[0]['ref'] or 'A'}
            m['attrs'] = {**m['attrs'], 'Style': m['ref'] or 'B'}
        prod['variants'].append(dict(attrs=m['attrs'], price=m['price'], qty=max(0, m['qty']), raw_qty=m['qty'],
                                     ref=m['ref']))

    # Split some clothing into sizes.
    for key, sizes in SPLIT_SIZES.items():
        prod = products[(key[0], key[1])]
        new = []
        for v in prod['variants']:
            share = [v['qty'] // len(sizes)] * len(sizes)
            for i in range(v['qty'] % len(sizes)):
                share[(i + 1) % len(sizes)] += 1  # extra units go to M first
            for s, q in zip(sizes, share):
                new.append(dict(v, attrs={**v['attrs'], 'Size': s}, qty=q))
        prod['variants'] = new

    # Validate attributes against categories, compute prices and stock targets.
    out = []
    for (src_artist, pname), prod in products.items():
        cat = cat_by_name[prod['category']]
        allowed = set(cat[2].keys())
        tax = TAX_OVERRIDE.get((prod['artist'], pname), cat[1])
        for v in prod['variants']:
            bad = set(v['attrs']) - allowed
            if bad:
                raise SystemExit(f'{prod["artist"]} / {pname}: attribute(s) {bad} not in category {cat[0]}')
            v['base'] = base_cents_from_shelf(v['price'], tax)
            if prod['category'] == LARGE_STOCK_CATEGORY and v['raw_qty'] <= 0:
                v['target'] = LARGE_STOCK_FINAL  # café item: stock not really tracked
            else:
                v['target'] = v['qty']
        bases = collections.Counter(v['base'] for v in prod['variants'])
        base = bases.most_common(1)[0][0]
        prod['base'] = base
        prod['per_variant'] = len(bases) > 1
        prod['tax_override'] = TAX_OVERRIDE.get((prod['artist'], pname))
        prod['commission_override'] = COMMISSION_OVERRIDE.get((prod['artist'], pname))
        out.append(prod)
    return out


# ================================================================ sales history

def rand_time(day):
    lo, hi = OPENING[day.weekday()]
    hours = list(range(lo, hi))
    h = rng.choices(hours, weights=[HOUR_WEIGHT.get(x, 5) for x in hours])[0]
    return dt.datetime(day.year, day.month, day.day, h, rng.randrange(60), rng.randrange(60))


def open_days():
    d = HISTORY_START
    while d <= HISTORY_END:
        if d.weekday() in OPENING:
            yield d
        d += dt.timedelta(days=1)


def assign_arrivals(products):
    """Delivery date per product (all its variants arrive together)."""
    for p in products:
        if p['category'] == LARGE_STOCK_CATEGORY:
            arrival = dt.datetime(2026, 5, 20, 10, 0)
        else:
            r = rng.random()
            if r < 0.7:  # already in the shop before the history starts
                day = dt.date(2026, 1, 10) + dt.timedelta(days=rng.randrange(140))
            else:  # delivered during the summer
                day = dt.date(2026, 6, 1) + dt.timedelta(days=rng.randrange(100))
            arrival = dt.datetime(day.year, day.month, day.day, 10, 30)
        for v in p['variants']:
            v['arrival'] = arrival


def build_history(products):
    cafe, goods = [], []
    for pi, p in enumerate(products):
        for vi, v in enumerate(p['variants']):
            if p['category'] == LARGE_STOCK_CATEGORY:
                opt = v['attrs'].get('Option')
                w = CAFE_WEIGHT.get((p['name'], opt), CAFE_WEIGHT.get((p['name'], None), 5))
                cafe.append((pi, vi, w))
            else:
                price = v['price']
                w = rng.uniform(0.5, 1.5) / math.sqrt(max(price, 3))
                goods.append((pi, vi, w))

    def pick_cafe(t):
        weights = []
        for pi, vi, w in cafe:
            name = products[pi]['name']
            if t.hour < 15 and name in COFFEE:
                w *= 3
            if t.hour >= 18 and name in ALCOHOL:
                w *= 2
            weights.append(w)
        pi, vi, _ = rng.choices(cafe, weights=weights)[0]
        return pi, vi

    def pick_goods(t, artist=None):
        pool = [(pi, vi, w) for pi, vi, w in goods if products[pi]['variants'][vi]['arrival'] <= t
                and (artist is None or products[pi]['artist'] == artist)]
        if not pool:
            return None
        pi, vi, _ = rng.choices(pool, weights=[w for _, _, w in pool])[0]
        return pi, vi

    def goods_qty(pi):
        cat = products[pi]['category']
        if cat in ('Postcards & Stickers',):
            return rng.choice([1, 1, 2, 3])
        return 1 if rng.random() < 0.9 else 2

    def make_order(t, kind, artist=None):
        lines = collections.OrderedDict()
        if kind in ('cafe', 'mixed'):
            for _ in range(rng.choice([1, 1, 2, 2, 3])):
                pi, vi = pick_cafe(t)
                q = rng.choice([1, 1, 2])
                lines[(pi, vi)] = lines.get((pi, vi), 0) + q
        if kind in ('goods', 'mixed'):
            for _ in range(1 if rng.random() < 0.8 else 2):
                pv = pick_goods(t, artist)
                if pv:
                    lines[pv] = lines.get(pv, 0) + goods_qty(pv[0])
        if not lines:
            return None
        has_goods = any(products[pi]['category'] != LARGE_STOCK_CATEGORY for pi, _ in lines)
        return dict(t='sale', at=t, lines=[[pi, vi, q] for (pi, vi), q in lines.items()],
                    pay='Cash' if (not has_goods and rng.random() < 0.45) or rng.random() < 0.2 else 'Card',
                    discount=has_goods and rng.random() < 0.05)

    events = []

    # Workshop sessions: 2–3 a month on Wed/Thu/Sat evenings (+2 upcoming).
    sessions = []
    month = dt.date(2026, 6, 1)
    while month <= dt.date(2026, 10, 1):
        days = [d for d in open_days() if d.year == month.year and d.month == month.month and d.weekday() in (2, 3, 5)]
        for d in sorted(rng.sample(days, min(len(days), rng.choice([2, 3])))):
            title, host = rng.choice(WORKSHOPS)
            start = dt.datetime(d.year, d.month, d.day, 18, 30)
            sessions.append(dict(title=title, host=host, start=start, end=start + dt.timedelta(hours=2),
                                 google=rng.random() < 0.7))
        month = (month.replace(day=28) + dt.timedelta(days=4)).replace(day=1)
    sessions = [s for s in sessions if s['start'].date() <= HISTORY_END]
    for d, (title, host) in [(dt.date(2026, 10, 22), WORKSHOPS[1]), (dt.date(2026, 10, 31), WORKSHOPS[0])]:
        start = dt.datetime(d.year, d.month, d.day, 18, 30)
        sessions.append(dict(title=title, host=host, start=start, end=start + dt.timedelta(hours=2), google=True))
    for i, s in enumerate(sessions):
        s['id'] = f'demo-gcal-{i:03d}' if s['google'] else None

    # Regular days.
    for day in open_days():
        n = ORDERS_PER_DAY[day.weekday()]
        if day.month == 8:
            n *= 0.8
        n = max(6, int(round(n * rng.uniform(0.75, 1.25))))
        for _ in range(n):
            t = rand_time(day)
            kind = rng.choices(['cafe', 'goods', 'mixed'], weights=[55, 33, 12])[0]
            o = make_order(t, kind)
            if o:
                events.append(o)

    # Workshop crowds: extra orders during each past session, some of the host's work.
    for si, s in enumerate(sessions):
        if s['start'].date() > HISTORY_END:
            continue
        for _ in range(rng.randint(4, 9)):
            t = s['start'] + dt.timedelta(minutes=rng.randrange(120))
            host = None if s['host'] == STORE_ARTIST else s['host']
            o = make_order(t, rng.choice(['cafe', 'mixed', 'goods']), artist=host if rng.random() < 0.6 else None)
            if o:
                events.append(o)
        # A sale just after the end that staff tagged by hand.
        if rng.random() < 0.5:
            t = s['end'] + dt.timedelta(minutes=rng.randint(5, 25))
            o = make_order(t, 'mixed')
            if o:
                o['manual_session'] = si
                events.append(o)

    events.sort(key=lambda e: e['at'])

    # Make sure everything that ends at 0 in the sheet sold at least once.
    sold = collections.Counter()
    for e in events:
        for pi, vi, q in e['lines']:
            sold[(pi, vi)] += q
    days = list(open_days())
    for pi, p in enumerate(products):
        for vi, v in enumerate(p['variants']):
            if v['target'] == 0 and sold[(pi, vi)] == 0:
                options = [d for d in days if dt.datetime(d.year, d.month, d.day, 23) > v['arrival']]
                t = rand_time(rng.choice(options))
                events.append(dict(t='sale', at=t, lines=[[pi, vi, 1]], pay=rng.choice(['Card', 'Card', 'Cash']),
                                   discount=False))
    events.sort(key=lambda e: e['at'])

    # Refunds: ~3.5% of orders with goods, 1–7 days later, during opening hours.
    sale_events = [e for e in events if e['t'] == 'sale']
    refunds = []
    for si, e in enumerate(sale_events):
        goods_lines = [i for i, (pi, vi, q) in enumerate(e['lines'])
                       if products[pi]['category'] != LARGE_STOCK_CATEGORY]
        if goods_lines and rng.random() < 0.035:
            day = e['at'].date() + dt.timedelta(days=rng.randint(1, 7))
            while day.weekday() not in OPENING:
                day += dt.timedelta(days=1)
            if day > HISTORY_END:
                continue
            li = rng.choice(goods_lines)
            full = e['lines'][li][2]
            q = full if rng.random() < 0.6 else max(1, full - 1)
            refunds.append(dict(t='refund', at=rand_time(day), sale=si, lines=[[li, q]]))
    events.extend(refunds)

    # Restocks: some popular goods get more units mid-history (arrival date is overwritten).
    sold = collections.Counter()
    for e in events:
        if e['t'] == 'sale':
            for pi, vi, q in e['lines']:
                sold[(pi, vi)] += q
    candidates = [k for k, n in sold.items() if n >= 3 and products[k[0]]['category'] != LARGE_STOCK_CATEGORY]
    for pi, vi in rng.sample(candidates, min(18, len(candidates))):
        day = dt.date(2026, 8, 1) + dt.timedelta(days=rng.randrange(70))
        while day.weekday() not in OPENING:
            day += dt.timedelta(days=1)
        events.append(dict(t='restock', at=dt.datetime(day.year, day.month, day.day, 10, 45), p=pi, v=vi,
                           q=rng.randint(2, 6)))

    events.sort(key=lambda e: (e['at'], {'restock': 0, 'sale': 1, 'refund': 2}[e['t']]))
    # Refund events point at the sale index; re-index after sorting.
    sale_index = {}
    for e in events:
        if e['t'] == 'sale':
            sale_index[id(e)] = len(sale_index)
    by_old = {i: e for i, e in enumerate(sale_events)}
    for e in events:
        if e['t'] == 'refund':
            e['sale'] = sale_index[id(by_old[e['sale']])]
    return events, sessions


def settle_stock(products, events):
    """Initial stock so that the history ends at the sheet quantity and never goes negative."""
    sale_events = [e for e in events if e['t'] == 'sale']
    for _ in range(50):
        delta = collections.Counter()
        for e in events:
            if e['t'] == 'sale':
                for pi, vi, q in e['lines']:
                    delta[(pi, vi)] -= q
            elif e['t'] == 'refund':
                s = sale_events[e['sale']]
                for li, q in e['lines']:
                    pi, vi, _ = s['lines'][li]
                    delta[(pi, vi)] += q
            else:
                delta[(e['p'], e['v'])] += e['q']
        for pi, p in enumerate(products):
            for vi, v in enumerate(p['variants']):
                v['initial'] = v['target'] - delta[(pi, vi)]

        # Replay and fix any dip below zero by moving units from a restock to the start.
        stock = {(pi, vi): v['initial'] for pi, p in enumerate(products) for vi, v in enumerate(p['variants'])}
        problem = None
        for e in events:
            if e['t'] == 'sale':
                for pi, vi, q in e['lines']:
                    stock[(pi, vi)] -= q
                    if stock[(pi, vi)] < 0:
                        problem = (pi, vi, -stock[(pi, vi)])
            elif e['t'] == 'refund':
                s = sale_events[e['sale']]
                for li, q in e['lines']:
                    pi, vi, _ = s['lines'][li]
                    stock[(pi, vi)] += q
            else:
                stock[(e['p'], e['v'])] += e['q']
            if problem:
                break
        if not problem:
            return
        pi, vi, short = problem
        restocks = [e for e in events if e['t'] == 'restock' and (e['p'], e['v']) == (pi, vi)]
        if restocks:
            # Move units from the restock to the starting stock.
            restocks[0]['q'] -= short
            events[:] = [e for e in events if not (e['t'] == 'restock' and e['q'] <= 0)]
            continue
        # Otherwise a refund returned the unit too late: drop that refund.
        for e in list(events):
            if e['t'] == 'refund':
                s = sale_events[e['sale']]
                if any(s['lines'][li][:2] == [pi, vi] for li, _ in e['lines']):
                    events.remove(e)
                    break
        else:
            raise SystemExit(f'Could not settle stock for {products[pi]["name"]}')
    raise SystemExit('Could not settle stock')


def verify(products, events):
    """Independent replay: stock never negative, ends at target, sales after arrival."""
    sale_events = [e for e in events if e['t'] == 'sale']
    stock = {(pi, vi): v['initial'] for pi, p in enumerate(products) for vi, v in enumerate(p['variants'])}
    for e in events:
        if e['t'] == 'sale':
            for pi, vi, q in e['lines']:
                assert products[pi]['variants'][vi]['arrival'] <= e['at'], 'sold before arrival'
                stock[(pi, vi)] -= q
                assert stock[(pi, vi)] >= 0, f'negative stock {products[pi]["name"]}'
            d = e['at']
            lo, hi = OPENING[d.weekday()]
            in_session = 'manual_session' in e or d.hour >= hi - 3
            assert lo <= d.hour < hi or in_session, f'sale outside opening hours {d}'
        elif e['t'] == 'refund':
            s = sale_events[e['sale']]
            assert e['at'] > s['at']
            for li, q in e['lines']:
                pi, vi, _ = s['lines'][li]
                stock[(pi, vi)] += q
        else:
            stock[(e['p'], e['v'])] += e['q']
    for pi, p in enumerate(products):
        for vi, v in enumerate(p['variants']):
            assert stock[(pi, vi)] == v['target'], (p['name'], v['attrs'], stock[(pi, vi)], v['target'])


# ======================================================================= output

def iso(t):
    return t.strftime('%Y-%m-%dT%H:%M:%S')


def fake_billing(i, name):
    return dict(
        address=f'Demo street {i + 1}, 00000 Demo city',
        legal_name=f'{name} (demo)',
        tax_id=f'00000{i:03d}X',
        iban=f'ES00 0000 0000 0000 0000 0{i:03d}',
        bank_name='Demo Bank',
    )


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    rows = read_rows(sys.argv[1])
    products = build_catalog(rows)
    assign_arrivals(products)
    events, sessions = build_history(products)
    settle_stock(products, events)
    verify(products, events)

    artists = sorted({p['artist'] for p in products}, key=str.lower)
    artist_json = []
    for i, name in enumerate(artists):
        prof = ARTIST_PROFILES[name]
        artist_json.append(dict(name=name, gender=prof['gender'], resident=prof['resident'],
                                commission=prof.get('commission'), **fake_billing(i, name)))

    data = dict(
        version=1,
        source='ES_Inventory_12Sept2026.xlsx',
        history=dict(start=HISTORY_START.isoformat(), end=HISTORY_END.isoformat()),
        store=dict(name=STORE_ARTIST),
        categories=[dict(name=n, tax=t, attributes=[dict(name=a, options=o) for a, o in attrs.items()])
                    for n, t, attrs in CATEGORIES],
        discounts=[dict(name='Friends & Family', percent=5)],
        artists=artist_json,
        products=[dict(
            artist=p['artist'], name=p['name'], category=p['category'], base=p['base'],
            per_variant=p['per_variant'], tax_override=p['tax_override'],
            commission_override=p['commission_override'],
            variants=[dict(attrs=v['attrs'], qty=v['initial'], final=v['target'],
                           price=v['base'] if p['per_variant'] and v['base'] != p['base'] else None,
                           arrival=iso(v['arrival'])) for v in p['variants']],
        ) for p in products],
        sessions=[dict(title=s['title'], start=iso(s['start']), end=iso(s['end']), google_id=s['id'])
                  for s in sessions],
        events=[],
    )
    for e in events:
        if e['t'] == 'sale':
            out = dict(t='sale', at=iso(e['at']), lines=e['lines'], pay=e['pay'])
            if e['discount']:
                out['discount'] = 'Friends & Family'
            if 'manual_session' in e:
                out['manual_session'] = e['manual_session']
        elif e['t'] == 'refund':
            out = dict(t='refund', at=iso(e['at']), sale=e['sale'], lines=e['lines'])
        else:
            out = dict(t='restock', at=iso(e['at']), p=e['p'], v=e['v'], q=e['q'])
        data['events'].append(out)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

    # Summary
    nv = sum(len(p['variants']) for p in products)
    kinds = collections.Counter(e['t'] for e in events)
    print(f'{len(artists)} artists, {len(products)} products, {nv} variants, {len(CATEGORIES)} categories')
    print(f'{kinds["sale"]} sales, {kinds["refund"]} refunds, {kinds["restock"]} restocks, {len(sessions)} sessions')
    print(f'{sum(1 for e in events if e.get("discount"))} discounted sales, '
          f'{sum(1 for e in events if "manual_session" in e)} tagged by hand')
    print(f'out of stock at the end: {sum(1 for p in products for v in p["variants"] if v["target"] == 0)} variants')
    print('written', os.path.normpath(OUT), f'({os.path.getsize(OUT) // 1024} KB)')


if __name__ == '__main__':
    main()
