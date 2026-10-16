# Entre Sales

Inventory, point of sale, artist settlements and monthly reports for the Entre concept store.
Runs fully offline on one Android tablet; all data is stored locally in SQLite.

## First-time setup

**Full step-by-step guide (install, tablet, Google Calendar, updates): [SETUP.md](SETUP.md).**

Short version — platform folders (`android/`) are not committed yet. Generate them once:

```bash
git clone https://github.com/Hassan-Melhim/entre-sales.git
cd entre-sales
flutter create --platforms=android --org com.entre .   # keeps existing files
flutter pub get
flutter test        # money calculations
flutter analyze     # please send me any errors
flutter run
```

Then add internet access (only used for Google Calendar sync) to
`android/app/src/main/AndroidManifest.xml`, just above `<application`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Requires Flutter 3.27 or newer.

## Where to change the money rules

Everything that decides how money is split is in **`lib/config/business_rules.dart`**,
each rule marked with `►►►`:

| Rule | Current value |
|---|---|
| Default store commission | 35% (per-artist override in the Artists screen) |
| Tax for Spain-resident artists | 10%, **added on top** of the payout (placeholder: confirm with your accountant) |
| Discounts | Absorbed by the store; artist is paid on the full price |
| Store profit | Customer paid (VAT incl.) − artist payout − resident tax added |
| Workshop keyword | Calendar events whose title contains "workshop" |
| Gender options | Male, Female, Queer |

VAT per category (21%, books 4%) is edited in the app: **Settings → Categories**.
A single product can have its own tax rate (checkbox when logging the product).

## How the app works

- **Sell** – search, tap a product, pick a variant (stock shown per variant), choose cash/card,
  optional Friends & Family discount, complete. Stock is re-checked when the sale is saved, so an item
  that is not in stock cannot be sold. Sales during a workshop session are tagged automatically.
- **Inventory** – every product with its variants grouped together. Out-of-stock products sit at the
  bottom with a warning. Log a product: name → artist → delivery date → category → the category's fields
  (e.g. sizes) → price → quantity per variant. Restocking overwrites the date of arrival.
- **Artists** – contact and billing details (legal name, NIF, IBAN, bank), gender, residency, commission.
- **Sales** – history by date range, receipt PDFs, refunds (items go straight back into stock),
  and manual tagging of sales with a workshop session.
- **Invoices** – artist payouts for 1st–15th / 16th–end (or the 15 days up to any date), with a PDF per
  artist and a CSV of all; workshop session invoices as PDF.
- **Reports** – monthly profit, revenue, VAT, payouts, sales by category / artist / gender, best hours and
  weekdays, best sellers, turnover, days-to-sell and items longest on display. Export as PDF or CSV.
- **Settings** – store details for PDFs, categories and their fields, discounts, Google Calendar, backup.

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

## Google Calendar

The app reads the store's calendar to know when workshops happen. One-time setup (about 15 minutes):

1. Go to <https://console.cloud.google.com>, create a project (e.g. "Entre Sales").
2. **APIs & Services → Library** → enable **Google Calendar API**.
3. **APIs & Services → OAuth consent screen** → External, add the store's Google account as a test user.
4. **Credentials → Create credentials → OAuth client ID → Android**:
   - Package name: `com.entre.entre_sales`
   - SHA-1: run `cd android && ./gradlew signingReport` and copy the SHA-1 of the variant you install.
5. In the app: **Settings → Google Calendar → Connect**, sign in with the store account, then **Sync now**.
   If workshops are on a secondary calendar, paste its Calendar ID (Google Calendar → calendar settings →
   "Integrate calendar").

Sessions are cached on the tablet, so tagging works offline; sync again whenever you're online.
Workshops that weren't on the calendar can be added by hand in **Invoices → Workshop sessions**.

## Code layout

```
lib/
  config/business_rules.dart   ← money rules
  core/                        money, dates, pricing formulas
  data/database.dart           SQLite schema + seed categories
  data/models.dart
  data/repositories/           queries (inventory, sales, calendar, reports)
  services/                    PDF, CSV export, Google Calendar
  ui/                          screens (Riverpod)
test/pricing_test.dart         checks the money formulas
```

## Backup

Everything lives only on the tablet. Use **Settings → Backup → Share database backup** regularly
(e.g. save it to Google Drive).
