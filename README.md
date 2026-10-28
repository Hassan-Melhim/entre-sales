# Entre Sales

Inventory, point of sale, artist payouts and sales reports for the Entre Salas concept store.

A **website** used from the store's iPad and the owners' MacBooks. The data lives in **Supabase**
(one shared database, so every device sees the same stock and sales) and the site is hosted on **Vercel**.
Four people sign in, each with their own email and password: the three owners and the developer.
All four have the same rights.

The layout adapts to phones, tablets (portrait or landscape) and computer windows, in light or dark mode.

## First-time setup

**Full step-by-step guide (database, logins, Vercel, iPad): [SETUP.md](SETUP.md).**

Short version, once the database is set up:

```powershell
flutter pub get
flutter analyze
flutter test             # money formulas + reading Supabase rows
flutter run -d chrome    # the website, on your computer (real database)
```

Requires Flutter 3.35 or newer.

## Where to change the money rules

Everything that decides how money is split is in **`lib/domain/business_rules.dart`**,
each rule marked with `►►►`. The two rules the database applies when recording a sale (default
commission, whether discounts reduce the payout) are repeated at the top of
`supabase/migrations/20261028120200_functions.sql`; a test checks they match.

| Rule | Current value |
|---|---|
| Default store commission | 35% |
| Tax for Spain-resident artists | 10%, **added on top** of the payout (placeholder: confirm with your accountant) |
| Discounts | Absorbed by the store; artist is paid on the full price |
| Store profit | Customer paid (VAT incl.) − artist payout − resident tax added |
| Gender options | Male, Female, Queer |

### Commission (changed often, so it is one tap away)

The commission charged on a sale is chosen in this order:

1. **the product's own commission**, if set: the **%** button on each product in **Inventory**, or the
   field next to the price in the product form. The artist's rate is not touched;
2. otherwise **the artist's commission**: the **%** button on each artist in **Artists**;
3. otherwise the **store default** (35%).

Every sale stores the rate it used, so changing a commission never changes past sales or payouts.

VAT changes rarely, so it sits in **Settings → Categories** (21%, books 4%, café 0%) and under
**Tax (advanced)** in the product form for a one-off rate.

## How the app works

- **Sell** – search, tap a product, pick a variant (stock shown per variant), choose cash/card,
  optional Friends & Family discount, complete. Stock is re-checked when the sale is saved, so an item
  that is not in stock cannot be sold. Sales during a workshop session are tagged automatically.
- **Inventory** – every product with its variants grouped together. Out-of-stock products sit at the
  bottom with a warning. Restocking overwrites the date of arrival.
- **Artists** – contact and billing details (legal name, NIF, IBAN, bank), gender, residency, commission.
- **Sales** – history by date range, receipt PDFs, refunds (items go straight back into stock),
  and manual tagging of sales with a workshop session.
- **Invoices** – artist payouts for a **calendar month** (with previous / next) or **any date range**.
  Export as PDF or CSV, either a **summary** (one line per artist) or **detailed** (every item each
  artist sold and every refund: one PDF with a page per artist, or one CSV row per item).
  Workshop session invoices as PDF.
- **Reports** – for a **day, month, quarter (Q1–Q4), year or custom range**: profit, revenue, VAT, payouts,
  a timeline (by hour, day, week or month depending on the length), sales by category / artist / gender,
  best hours and weekdays, best sellers, turnover, days-to-sell and items longest on display.
  Export as PDF or CSV.
- **Settings** – this device (light / dark mode, shift length: signed out 5 hours after signing in,
  but never mid-use), store details for PDFs,
  categories and their fields, discounts, backup download.

Every date filter accepts the same day as start and end (that whole day).

### How the amounts are calculated

For a 100 € (before tax) poster, 21% VAT, 35% commission, Spain-resident artist:

| | |
|---|---|
| Customer pays | 121.00 € |
| Artist share | 100 − 35% = 65.00 € |
| Resident tax added | 6.50 € → artist is paid 71.50 € |
| Store profit | 121.00 − 65.00 − 6.50 = 49.50 € |

With the Friends & Family discount the customer pays 95 + 21% = 114.95 €; the artist still gets 65 €.

Refunds are dated on the day of the refund and are deducted from the artist payout of that period.

## How the database keeps the money safe

- **Signed-in owners only.** Without signing in, nothing can be read or changed. Sign-ups are closed;
  the four logins are created in Supabase.
- **Sales are calculated by the database**, from the catalog: prices, VAT, discount and commission
  can't be altered by a device.
- **Stock is checked and lowered in the same step as the sale**, so two devices can't sell the
  same last item.
- **A sale sent twice** (e.g. the connection dropped and the button was pressed again) is recorded once.
- **Sales and refunds can't be edited or deleted**; mistakes are corrected with a refund.
- **Every change is logged** (`audit_log`) with who made it and when.
- Saving a product changes stock by the difference typed, so a sale made on another device while the
  form was open isn't undone.

All of this is in `supabase/migrations/` and tested by `supabase/tests/test_migrations.py`
(runs on a local PostgreSQL).

## Demo data

To try the site before going live, `supabase/scripts/load_demo_data.sql` (run in the Supabase SQL
Editor, see SETUP.md Part 3d) adds:

- the **September 2026 inventory** (`ES_Inventory_12Sept2026.xlsx`): 40 artists, 266 products, 514 variants.
  Rows that are versions of one item are grouped as variants (e.g. silver/gold jewellery, bedrunner
  pattern × size, café drinks). Prices in the sheet include VAT; base prices are calculated from them.
  Items marked "?" belong to the store (artist **Entre Salas**, 100% commission, so no payout).
  Café and bar items have a large stock and 0% VAT. Workshop and participation fees are left out.
- a **mock sales history, 1 June – 18 October 2026**, following the opening hours
  (Mon & Wed–Sat 11–21, Sun 14–19, closed Tuesdays): ~1,550 sales, Friends & Family discounts,
  refunds, restocks and 12 workshop sessions (a few sales tagged by hand).
- placeholder artist details (obviously fake billing: `ES00 0000…`, "Demo Bank"), and examples of
  the overrides: 10% tax on Matilde Cunha's *Photo Strip*, product commissions of 30% on Cora's
  *Ceramic Butter Dish* and 40% on Ana Drucker's *Bookend*.

Every event goes through the database's own sale / refund / restock functions, and each variant ends
at exactly the stock in the sheet. `supabase/scripts/clear_test_data.sql` removes it all before go-live.

To rebuild it from a newer inventory export:

```powershell
pip install openpyxl
python tool/demo_data/generate_demo_data.py path\to\ES_Inventory.xlsx   # → demo_data.json
python tool/demo_data/make_demo_sql.py                                   # → load_demo_data.sql
```

## Moving the real data in

`migration/Entre Sales - data import template.xlsx` is the workbook to fill in before the switch-over:
**Artists** (with billing details), **Products** (one row per variant, with today's stock) and
**Past sales** (one row per item of each receipt, with totals before and after VAT). Instructions are
on its first tab. It's built by `tool/migration/make_import_template.py`.

## Code layout

The code is split in three layers. Each layer only uses the ones above it in this list:

```
lib/
  core/            money and date formatting, Supabase address, asset paths
  domain/          the business: what the store does, independent of any database or screen
    business_rules.dart      ← money rules
    pricing.dart             VAT, commission, discount, refund formulas (for the cart and previews)
    models/                  one plain data class per file (Artist, Product, SaleOrder, ReportPeriod, …)
    repositories/            interfaces: what data the app needs (ProductRepository, AuthRepository, …)
    services/                report and artist-statement calculations
  data/            how it is done
    supabase/                one Supabase…Repository per interface, row ↔ model mapping, paging
    local/                   per-device preferences (light / dark, auto sign-out)
    export/                  PDF and CSV files, browser downloads
  presentation/    what the user sees
    providers.dart           the only place that picks the implementations (Riverpod)
    theme/                   colours (light / dark), spacing and size tokens, breakpoints
    widgets/                 shared widgets (incl. end-of-shift sign-out)
    screens/                 login + one folder per tab
supabase/
  migrations/      the database: tables, security, sale / refund / report functions (run in order)
  scripts/         load_demo_data.sql (try it out), clear_test_data.sql (first real day)
  tests/           checks the migrations on a local PostgreSQL; dumps rows for the Dart tests
tool/              Vercel build script, demo data generator (→ JSON → SQL)
web/               the website's page, icons and manifest
vercel.json        how Vercel builds and serves the site
test/
  pricing_test.dart            money formulas, date ranges, report periods
  supabase_mappers_test.dart   real Supabase rows → models, a report over them
  widget_test.dart             widgets in light and dark mode
```

Sizes, spacing and breakpoints come from `lib/presentation/theme/app_tokens.dart` and
`breakpoints.dart`; colours come from the theme, so everything follows light and dark mode.

### Screen sizes

| Width | Example | Navigation | Layout |
|---|---|---|---|
| < 600 dp | phone, narrow window | menu drawer | single column, cart opens as a sheet |
| 600–999 dp | iPad portrait | rail with labels | forms in rows where they fit |
| ≥ 1000 dp | iPad landscape, MacBook | extended rail | cart beside products, side-by-side panels |

## Backup

The free Supabase plan makes no automatic backups: use **Settings → Backup → Download backup**
regularly (e.g. weekly). The Pro plan adds daily backups.
