"""One-off clean-up of the store's filled workbook (November 2026) into the import template's layout:
day/month dates swapped by Excel fixed, store categories, Skylex added, cells to complete marked.

    python tool/migration/prepare_filled_template.py ES_Filled_Template.xlsx "Entre Sales - data import template.xlsx" ES_Import_Ready.xlsx
"""
import datetime as dt, sys
from openpyxl import load_workbook
from openpyxl.comments import Comment
from openpyxl.formatting.formatting import ConditionalFormattingList
from openpyxl.styles import Font, PatternFill

FILLED, TEMPLATE, OUT = sys.argv[1:4]
src = load_workbook(FILLED, data_only=True)
wb = load_workbook(TEMPLATE)
TODO = PatternFill('solid', fgColor='F8CBAD')          # cells left for the owners to fill in
FIXED = PatternFill('solid', fgColor='DDEBF7')         # cells I changed (date corrected)
F = Font(name='Arial', size=10)

CATEGORIES = ['Clothes', 'Jewellery', 'Accessories', 'Ceramics', 'Home Goods', 'Libros & Prints', 'Goodies',
              'Conceptual Pieces', 'Paintings', 'Food & Drink', 'TBD']
FIELDS = {'Clothes': ['Size', 'Style'], 'Jewellery': ['Finish', 'Style'], 'Accessories': ['Size', 'Style', 'Design'],
          'Ceramics': ['Design'], 'Home Goods': ['Size', 'Pattern', 'Design'], 'Libros & Prints': ['Size', 'Design'],
          'Goodies': ['Design'], 'Conceptual Pieces': ['Design'], 'Paintings': [], 'Food & Drink': [], 'TBD': []}
VAT = {c: (0 if c == 'Food & Drink' else 21) for c in CATEGORIES}

def rows(ws, start):
    return [r for r in ws.iter_rows(min_row=start, values_only=True) if any(v not in (None, '') for v in r)]

def put(ws, r, c, v, fill=None, note=None):
    cell = ws.cell(row=r, column=c, value=v)
    cell.font = F
    if fill: cell.fill = fill
    if note: cell.comment = Comment(note, 'Claude')
    return cell

# ------------------------------------------------------------ lists / categories
lists = wb['Lists']
for i in range(2, 30):
    lists.cell(row=i, column=4, value=None)
for i, c in enumerate(CATEGORIES, start=2):
    lists.cell(row=i, column=4, value=c)
for name in ['Products', 'Past sales']:
    for dv in wb[name].data_validations.dataValidation:
        if dv.formula1 and 'Lists!$D$' in dv.formula1:
            dv.formula1 = f'=Lists!$D$2:$D${len(CATEGORIES) + 1}'
cats = wb['Categories']
for r in range(2, cats.max_row + 1):
    for c in range(1, 5):
        cats.cell(row=r, column=c, value=None)
for i, c in enumerate(CATEGORIES, start=2):
    for col, v in enumerate([c, VAT[c], ', '.join(FIELDS[c]) or '—', 'free text'], start=1):
        put(cats, i, col, v)
put(cats, len(CATEGORIES) + 3, 1, 'The store\'s own categories. Set up in the app with supabase/scripts/use_store_categories.sql '
    'before importing. Books in Libros & Prints keep 4% VAT through the "VAT (%) override" column.').font = Font(name='Arial', size=10, italic=True)
# The old "grey out unused fields" rules referred to the old categories.
wb['Products'].conditional_formatting = ConditionalFormattingList()

# ---------------------------------------------------------------------- Artists
names = [r[0].strip() for r in rows(src['Artists'], 1)]
if 'Skylex' not in names:
    names.append('Skylex')
ws = wb['Artists']
for i, n in enumerate(sorted(names, key=str.lower), start=3):
    put(ws, i, 1, n, note='Added: sold jeans on 19/11 (C-261119-000003); not on the original list.' if n == 'Skylex' else None)
    put(ws, i, 2, None, fill=TODO)  # Spain resident: to fill in
    if n == 'Entre Salas':
        put(ws, i, 3, 100, note='The store\'s own items: 100% commission, so no artist payout.')
artist_rows = len(names)

# --------------------------------------------------------------------- Products
P = rows(src['Products'], 2)
ws = wb['Products']
for i, r in enumerate(P, start=3):
    for c, v in enumerate(r[:16], start=1):
        if isinstance(v, str):
            v = v.strip()
        put(ws, i, c, v)

# ------------------------------------------------------------------- Past sales
def sale_date(v):
    """Text dd/mm/yyyy as written; Excel date cells had day and month swapped."""
    if isinstance(v, dt.datetime):
        d = v.date()
        return dt.date(d.year, d.day, d.month), True
    dd, mm, yy = map(int, v.split('/'))
    return dt.date(yy, mm, dd), False

S = rows(src['Sales'], 2)
ws = wb['Past sales']
fixed = todo = 0
for i, r in enumerate(S, start=3):
    receipt, date, time, payment, artist, product, category, variant, qty, before, incl = r[:11]
    d, swapped = sale_date(date)
    put(ws, i, 1, receipt.strip())
    c = put(ws, i, 2, d, fill=FIXED if swapped else None,
            note=f'Was {date:%d/%m/%Y}: Excel had swapped day and month.' if swapped else None)
    c.number_format = 'DD/MM/YYYY'
    fixed += swapped
    if time is not None:
        put(ws, i, 3, time).number_format = 'HH:MM'
    if payment in ('Cash', 'Card'):
        put(ws, i, 4, payment)
    else:
        put(ws, i, 4, None, fill=TODO, note=f'Was "{payment}". Choose Cash or Card.' if payment else 'No payment method in the old data. Choose Cash or Card.')
        todo += 1
    for col, v in zip(range(5, 12), [artist, product, category, variant, qty, before, incl]):
        put(ws, i, col, v.strip() if isinstance(v, str) else v)
    for col in (10, 11):
        ws.cell(row=i, column=col).number_format = '#,##0.00 "€"'

wb.active = 0
wb.save(OUT)
print(f'artists {artist_rows}, products rows {len(P)}, sale rows {len(S)}, dates corrected {fixed}, payments to fill {todo}')

# ------------------------------------------------------------- What I changed
wb = load_workbook(OUT)
ch = wb.create_sheet('What changed', 1)
ch.sheet_view.showGridLines = False
ch.column_dimensions['A'].width = 3; ch.column_dimensions['B'].width = 28; ch.column_dimensions['C'].width = 100
lines = [
    ('h', 'What was changed from ES_Filled_Template'),
    ('', ''),
    ('h', 'Still to fill in (orange cells)'),
    ('r', ('Artists → Spain resident', f'Yes or No for each of the {artist_rows} artists (decides the 10% resident tax).')),
    ('r', ('Past sales → Payment', f'{todo} lines: the 45 early receipts (R25-…) had none, and B-000406 was "Customer Account". Choose Cash or Card.')),
    ('', ''),
    ('h', 'Fixed'),
    ('r', ('Sale dates (blue cells)', f'{fixed} dates had day and month swapped by Excel (e.g. 3 June became 6 March). '
                                     'Corrected: ticket numbers now run in date order and none are in the future. The old value is in each cell\'s note.')),
    ('r', ('Artists', 'Header row added (the tab had names only). Skylex added: sold jeans on 19/11 (C-261119-000003).')),
    ('r', ('Entre Salas', 'Commission 100%: the store\'s own items (café, fees…) pay no artist.')),
    ('r', ('Tab names', '"Sales" is now "Past sales", the name the import expects.')),
    ('', ''),
    ('h', 'Kept as they were'),
    ('r', ('Categories', 'Your 11 categories. Set them up in the app first with supabase/scripts/use_store_categories.sql.')),
    ('r', ('Products', 'All 539 rows (427 products) unchanged. Books keep their 4% VAT override.')),
    ('r', ('Amounts', 'Totals before/after VAT as charged: 21%, 4% on books, 0% on Food & Drink.')),
    ('r', ('TBD lines', 'Participation, workshop and rental fees are imported as sales under TBD.')),
    ('', ''),
    ('h', 'Then'),
    ('r', ('1.', 'Fill in the orange cells and save.')),
    ('r', ('2.', 'Save each of the tabs Artists, Products and Past sales as its own CSV (File → Save As → CSV UTF-8), '
                 'or send the workbook back to get the CSV files.')),
    ('r', ('3.', 'In the app: Settings → Advanced settings → Import data → choose the three files → Check files → Import.')),
]
r = 1
for kind, v in lines:
    r += 1
    if kind == 'h':
        ch.cell(row=r, column=2, value=v).font = Font(name='Arial', size=12, bold=True, color='5B3A2C')
    elif kind == 'r':
        ch.cell(row=r, column=2, value=v[0]).font = Font(name='Arial', size=10, bold=True)
        c = ch.cell(row=r, column=3, value=v[1]); c.font = F
        from openpyxl.styles import Alignment
        c.alignment = Alignment(wrap_text=True, vertical='top')
ch.cell(row=4, column=2).fill = TODO; ch.cell(row=5, column=2).fill = TODO; ch.cell(row=8, column=2).fill = FIXED
wb.save(OUT)
