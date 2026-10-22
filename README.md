# Entre Sales

Inventory, point of sale, artist payouts and sales reports for the Entre Salas concept store.

The app is moving to a **website** (planned at entresalas.shop) used from the store's iPad and the owners'
MacBooks, with no app-store fees. For now the website keeps its data **in the browser of each device**
(mock/demo data). A shared online database (Supabase) comes next, so every device will see the same data.
The same code still runs as a Windows or Android app for testing.

The layout adapts to phones, tablets (portrait or landscape) and computer windows, in light or dark mode.

## First-time setup

**Full step-by-step guide: [SETUP.md](SETUP.md).**

Short version: platform folders are not committed. Generate them once, then run:

```powershell
flutter create --platforms=web,windows,android --org com.entre .   # keeps existing files
flutter pub get
dart run sqflite_common_ffi_web:setup   # once: puts the browser SQLite files in web/
flutter test             # money formulas + the whole database layer
flutter analyze
flutter run -d chrome    # the website, on your computer
flutter run -d windows   # the Windows app
```

Requires Flutter 3.35 or newer.

## Where to change the money rules

Everything that decides how money is split is in **`lib/domain/business_rules.dart`**,
each rule marked with `►►►`:

| Rule | Current value |
|---|---|
| Default store commission | 35% |
| Tax for Spain-resident artists | 10%, **added on top** of the payout (placeholder: confirm with your accountant) |
| Discounts | Absorbed by the store; artist is paid on the full price |
| Store profit | Customer paid (VAT incl.) − artist payout − resident tax added |
| Workshop keyword | Calendar events whose title contains "workshop" |
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
- **Settings** – appearance (system / light / dark), store details for PDFs, categories and their fields,
  discounts, Google Calendar, backup, demo data.

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

## The website (current state)

| | Now | With Supabase (next step) |
|---|---|---|
| Where data lives | In each browser, on each device separately | One shared database for all devices |
| Demo data | **Settings → Demo data** on each device | Loaded once |
| Backup | Not available (the browser keeps the data) | Automatic daily backups |
| Google Calendar | Add workshop sessions by hand | Synced on the server |
| Sign-in | None | Each owner has their own login (all with the same rights) |

Because of this, **do not use the website for real sales yet**: clearing the browser's data deletes it.

On the iPad: open the site in Safari → Share → **Add to Home Screen**, and it opens full screen like an app.

## Google Calendar (Android app only, for now)

The Android app can read the store's calendar to know when workshops happen; see SETUP.md Part 10.
On the website and on Windows, add workshops by hand in **Invoices → Workshop sessions**.

## Demo data

**Settings → Demo data → Load demo data** replaces everything on the device with:

- the **September 2026 inventory** (`ES_Inventory_12Sept2026.xlsx`): 40 artists, 266 products, 514 variants.
  Rows that are versions of one item are grouped as variants (e.g. silver/gold jewellery, bedrunner
  pattern × size, café drinks). Prices in the sheet include VAT; base prices are calculated from them.
  Items marked "?" belong to the store (artist **Entre Salas**, 100% commission, so no payout).
  Café and bar items have a large stock and 0% VAT. Workshop and participation fees are left out.
- a **mock sales history, 1 June – 18 October 2026**, following the opening hours
  (Mon & Wed–Sat 11–21, Sun 14–19, closed Tuesdays): ~1,550 sales, Friends & Family discounts,
  refunds, restocks, and 2–3 workshop sessions a month (some from "Google Calendar", some added by hand,
  a few sales tagged by hand). Stock at the end matches the sheet; negative quantities became 0.
- placeholder artist details: mixed genders, residency and commissions; billing details are obviously
  fake (`ES00 0000…`, "Demo Bank").
- demo-only examples of the overrides: a 10% tax rate on Matilde Cunha's *Photo Strip*, and a product
  commission of 30% on Cora's *Ceramic Butter Dish* and 40% on Ana Drucker's *Bookend*.

The button is shown on the website, on computers and in debug builds, and hidden in a release app on a
phone or tablet so real data can't be wiped by accident.

The history is replayed through the app's own sale and refund code, so all amounts are calculated exactly
like real sales. `test/demo_data_test.dart` loads the file and checks every final stock level against the
sheet.

To rebuild the demo file (e.g. from a newer inventory export):

```powershell
pip install openpyxl
python tool/demo_data/generate_demo_data.py path\to\ES_Inventory.xlsx
```

How each row is grouped and categorised is listed in `tool/demo_data/catalog_mapping.py`.

## Code layout

The code is split in three layers. Each layer only uses the ones above it in this list:

```
lib/
  core/            formatting of money and dates, asset paths (no Flutter widgets, no database)
  domain/          the business: what the store does, independent of any database or screen
    business_rules.dart      ← money rules
    pricing.dart             VAT, commission, discount, refund formulas
    models/                  one plain data class per file (Artist, Product, SaleOrder, ReportPeriod, …)
    repositories/            interfaces: what data the app needs (ProductRepository, SalesRepository, …)
    services/                report and artist-statement calculations
  data/            how it is done today
    sqlite/                  SQLite schema + one Sqlite…Repository per interface
                             (browser, Windows, Android picked automatically)
    export/                  PDF and CSV files; saving / downloading / sharing them
    calendar/                Google Calendar sync
  presentation/    what the user sees
    providers.dart           the only place that picks the implementations (Riverpod)
    theme/                   colours (light / dark), spacing and size tokens, breakpoints
    widgets/                 shared widgets
    screens/                 one folder per tab
tool/demo_data/    builds assets/demo/demo_data.json from the inventory sheet
web/               the website's page, icons and manifest
test/
  pricing_test.dart          money formulas, date ranges, report periods
  database_test.dart         sales, stock, commission priority, refunds, statements, reports, upgrades
  demo_data_test.dart        loads the demo data and checks it against the sheet
  widget_test.dart           widgets in light and dark mode
```

**Switching to Supabase** means writing one `Supabase…Repository` per interface in
`lib/domain/repositories/` and changing the providers in `lib/presentation/providers.dart`.
The screens, formulas and reports do not change.

Sizes, spacing and breakpoints come from `lib/presentation/theme/app_tokens.dart` and
`breakpoints.dart`; colours come from the theme, so everything follows light and dark mode.

### Screen sizes

| Width | Example | Navigation | Layout |
|---|---|---|---|
| < 600 dp | phone, narrow window | menu drawer | single column, cart opens as a sheet |
| 600–999 dp | iPad portrait | rail with labels | forms in rows where they fit |
| ≥ 1000 dp | iPad landscape, MacBook | extended rail | cart beside products, side-by-side panels |

## Backup

- **Website**: nothing to back up yet; it only holds test data (see above).
- **Windows / Android app**: **Settings → Backup → Save database backup**. On Windows, PDFs, CSVs and
  backups are saved to `Documents\Entre Sales`, and the database lives in
  `%APPDATA%\com.entre\entre_sales`.
