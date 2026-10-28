# Setting up Entre Sales

The store's website: inventory, till, artist invoices and reports. It runs in the browser on the iPad
and the MacBooks; the data lives in **Supabase** (one shared database) and the site is hosted on
**Vercel**.

| Part | Who | How often |
|---|---|---|
| 1. Tools on your computer | you | once per computer |
| 2. Get the code | you | once, then `git pull` |
| 3. Set up the database | you, in the Supabase dashboard | **once** |
| 4. Run it on your computer | you | while working on the app |
| 5. Put it online with Vercel | you, in the Vercel dashboard | once (then automatic) |
| 6. Use it on the iPad and Macs | everyone | once per device |
| 7. Going live | you | once, on the first real day |

Commands go in the **VS Code terminal** (*Terminal → New Terminal*).

---

## Part 1 — Tools (once per computer)

1. **Git**: <https://git-scm.com/downloads>.
2. **Flutter 3.35 or newer**: <https://docs.flutter.dev/get-started/install> (choose *Web*).
   Android Studio and Visual Studio are **not** needed any more.
3. **Google Chrome** (or Microsoft Edge).
4. **VS Code** with the **Flutter** extension (`Ctrl+Shift+X` → Flutter).
5. Check:
   ```powershell
   flutter doctor
   ```
   The **Flutter** and **Chrome** lines must show ✓. Android, Visual Studio and Xcode lines can be ignored.

## Part 2 — Get the code

First time:
```powershell
git clone https://github.com/Hassan-Melhim/entre-sales.git
cd entre-sales
code .
```
Later: `git pull`.

If your copy has `android`, `windows` or `ios` folders from before, you can delete them; the website
doesn't use them.

## Part 3 — Set up the database (once)

In the Supabase dashboard, project **mddsniqoqhutzthbleve**.

### 3a. Create the tables, security and functions

The setup is in three files in the repository, in `supabase/migrations/`. Run them **in this order,
once each**:

1. `20261028120000_tables.sql`
2. `20261028120100_security.sql`
3. `20261028120200_functions.sql`

For each one:

1. In Supabase, open **SQL Editor** (left menu) → **New query**.
2. Open the file in VS Code, select everything (`Ctrl+A`), copy, and paste it into the editor.
3. Press **Run**. It should say **Success. No rows returned**.
   If Supabase asks to confirm a *destructive operation*, that's the `revoke` lines removing
   default access: confirm.

If a file shows an error, stop there and send a screenshot. Don't run the next one.

Check: **Table Editor** now lists tables such as `artists`, `products` and `orders`, and `categories`
has 15 rows.

### 3b. Close sign-ups

**Authentication → Sign In / Providers** → turn **off** *Allow new users to sign up* → **Save**.
Now only the accounts you create in the next step can sign in.

### 3c. Create the three owner logins

**Authentication → Users → Add user → Create new user**, once per owner:

- **Email** and a **password** (at least 12 characters; a password manager helps).
- Tick **Auto Confirm User**.

All three have exactly the same rights.

### 3d. Load the demo data (to try things out)

So there's something realistic to sell, invoice and report on before the store goes live:
**SQL Editor → New query**, paste the whole of `supabase/scripts/load_demo_data.sql` → **Run**
(about a minute; it's a long file).

It adds the September 2026 inventory (40 artists, 266 products, 514 variants) and a mock sales
history from 1 June to 18 October 2026: about 1,550 sales, refunds, restocks and 12 workshop
sessions. The sales go through the same calculations as real ones and are recorded as made by
the first owner login. It only runs on an empty store, and it's all removed in Part 7.

### Never share

The **secret key** (`sb_secret_…`) and the **database password**. The app only uses the
*publishable* key, which is public by design and already in `lib/core/app_config.dart`.

## Part 4 — Run it on your computer

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome      # or: flutter run -d edge
```

Or in VS Code: **Run and Debug** (`Ctrl+Shift+D`) → **Entre Sales (Chrome)** → **F5**.

Sign in with one of the owner accounts. It's the **real** database: what you add here is what the
store sees (see Part 7 for clearing test data).

`flutter test` doesn't need the internet. It checks the money formulas and that the app reads
Supabase's rows correctly.

## Part 5 — Put it online with Vercel (once)

1. Go to <https://vercel.com> → **Sign up** → **Continue with GitHub**.
2. **Add New… → Project** → find **entre-sales** → **Import**.
   If it isn't listed, choose **Adjust GitHub App Permissions** and give Vercel access to that repository.
3. On the settings screen, change nothing (*Framework Preset: Other*). The build steps are in
   `vercel.json` in the repository. Press **Deploy**.
4. The first build takes about 5 minutes, because it downloads Flutter. Then you get an address such as
   `https://entre-sales.vercel.app`.

From then on, **every push to `main` updates the site automatically** in a few minutes. Vercel's
**Deployments** page shows each build; if one fails, the previous version stays online.

> Vercel's free (Hobby) plan is meant for non-commercial use. If Vercel ever asks, the Pro plan is
> $20/month, or the same files can move to another host.

Optional, in Supabase: **Authentication → URL Configuration → Site URL** = your Vercel address.
It's only used in emails Supabase sends.

## Part 6 — Use it on the iPad and Macs

- **iPad**: open the address in **Safari** → **Share** → **Add to Home Screen**. It opens full
  screen like an app. Sign in once.
- **Macs**: open it in any browser and bookmark it.
- Each device stays signed in for one **shift: 5 hours** from signing in. If it's being used when the
  time is up, it waits until it's been left alone for 5 minutes, so it never signs out mid-sale.
  **Sign out** (bottom of the menu) ends the shift early.
- **Settings → This device** changes the shift length (2–12 hours, or no limit) and light / dark
  mode. Both are per device, so the iPad and each laptop can differ.
- The site needs internet. If the store's wifi is down, use a phone hotspot.

## Part 7 — Going live (once)

Until then, use the site freely to try things out (with the demo data from Part 3d). Sales can't be
deleted from the app (on purpose), so on the first real day clear the demo data and everything you
entered while testing:

1. If anything should be kept, **Settings → Backup → Download backup** first.
2. In Supabase: **SQL Editor → New query**, paste `supabase/scripts/clear_test_data.sql` → **Run**.

That empties artists, products, sales, sessions and the change history. Categories, discounts,
store details and logins are kept, and sale numbers start again from 1.

## Everyday

- **Backups**: the free Supabase plan makes none. Once a week, use **Settings → Backup → Download backup**
  and keep the file somewhere safe (e.g. Google Drive). The Pro plan ($25/month) adds automatic daily
  backups.
- **Free plan pause**: Supabase pauses a free project after 7 days without use. With the store open
  6 days a week that shouldn't happen; if it does, open the Supabase dashboard and press **Restore**.
- **Who changed what**: every change is recorded in the `audit_log` table (Supabase → Table Editor),
  with the owner's email and the time.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Wrong email or password" | Check the account in Authentication → Users (is it confirmed?). Reset the password there. |
| "Entre Sales could not start" | No internet, or Supabase is paused (see *Everyday*). |
| A screen shows "permission denied" or "function … does not exist" | One of the three SQL files wasn't run, or not in order (Part 3a). |
| Vercel build fails | Open the failed deployment → **Build Logs**, and send the last 30 lines. |
| Site still shows the old version | Reload the page; on the iPad, close and reopen the Home Screen app. |
