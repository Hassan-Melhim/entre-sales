# Setting up and running Entre Sales

A step-by-step guide for a Windows computer with **VS Code**, the store's **Android tablet**, and
running the app **on Windows** for testing.
Commands go in the **VS Code terminal** (*Terminal → New Terminal*, which opens PowerShell).

---

## Part 1 — Install the tools (once per computer)

1. **Git**: <https://git-scm.com/download/win> (default options are fine).
2. **Flutter 3.27 or newer**: follow <https://docs.flutter.dev/get-started/install/windows/desktop>.
   It installs the Flutter SDK and explains the next two items.
3. **Visual Studio 2022** (the full *Visual Studio*, not VS Code), needed to build Windows apps:
   - Download the free *Community* edition from <https://visualstudio.microsoft.com/downloads/>.
   - In the installer tick the workload **"Desktop development with C++"** and install.
4. **Android Studio**, needed to build for the tablet: install it from <https://developer.android.com/studio>,
   open it once and let it download the Android SDK.
5. **Windows Developer Mode** (Flutter needs it for plugins on Windows):
   *Settings → System → For developers →* turn on **Developer Mode**.
   (Or run `start ms-settings:developers` and switch it on.)
6. **VS Code extensions**: open VS Code → Extensions (`Ctrl+Shift+X`) → install **Flutter**
   (it also installs **Dart**).
7. Accept the Android licences and check the setup:
   ```powershell
   flutter doctor --android-licenses
   flutter doctor
   ```
   The **Flutter**, **Windows Version**, **Android toolchain** and **Visual Studio** lines must show ✓.
   Lines about Chrome or Linux can be ignored.

## Part 2 — Get the code

**First time:**
```powershell
cd $HOME\Documents
git clone https://github.com/Hassan-Melhim/entre-sales.git
cd entre-sales
code .
```
(`code .` opens the folder in VS Code.)

**Already have it:** in VS Code's terminal, inside the project folder:
```powershell
git pull
```

## Part 3 — Generate the platform folders (first time, or after this update)

The `android` and `windows` folders are generated on your computer, not stored in the repository:

```powershell
flutter create --platforms=android,windows --org com.entre .
```

This only adds missing files; it never overwrites the app's code. Running it again later is harmless.

Then give the Android app internet access (only used for Google Calendar):

1. Open `android\app\src\main\AndroidManifest.xml`.
2. Just **above** the line that starts with `<application`, add:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
3. Save.

## Part 4 — Download packages and check the code

```powershell
flutter pub get
flutter analyze
flutter test
```

- `flutter analyze`: **no errors** expected. Blue "info" lines are style hints.
- `flutter test`: should end with **All tests passed!** These tests run the real database code on your PC
  (sales, stock checks, refunds, artist payouts, reports), so they are a good check after any change.

If either shows errors, copy the output and send it over.

## Part 5 — Run on Windows (for testing)

**From VS Code (recommended):**
1. Open the **Run and Debug** panel (`Ctrl+Shift+D`).
2. Pick **"Entre Sales (Windows)"** in the dropdown at the top.
3. Press **F5** (or the green ▶).

**From the terminal:** `flutter run -d windows`

While running:
- Save a file to hot-reload instantly. In the terminal press `r` to reload, `R` to restart, `q` to quit.
- **Resize the window** to see the layout adapt: narrow window = phone layout (menu drawer, cart as a
  sheet), medium = tablet portrait, wide = tablet landscape.

Good to know on Windows:
- The test data is stored in `%APPDATA%\com.entre\entre_sales\entre_sales.db`, completely separate from
  the tablet. Delete that file to start fresh.
- PDFs, CSVs and backups are saved to **Documents\Entre Sales**; a message appears with
  **Show in folder**.
- **Google Calendar sync only works on the tablet.** On Windows you can add workshop sessions by hand
  (*Invoices → Workshop sessions → Add by hand*) to test session tagging.

## Part 6 — Prepare the tablet (once)

1. On the tablet: **Settings → About tablet** (sometimes under *Software information*).
2. Tap **Build number** 7 times until it says you are a developer.
3. **Settings → System → Developer options** → turn on **USB debugging**.
4. Connect the tablet by USB and accept **"Allow USB debugging?"** (tick *Always allow from this computer*).
5. Check the computer sees it:
   ```powershell
   flutter devices
   ```
   The tablet should be listed (next to "Windows").

## Part 7 — Run on the tablet

**From VS Code:**
1. Click the device name in the **bottom-right status bar** (or `Ctrl+Shift+P` → *Flutter: Select Device*)
   and choose the tablet.
2. In **Run and Debug**, pick **"Entre Sales (tablet / selected device)"** and press **F5**.

**From the terminal:** `flutter run -d <tablet-id>` using the id shown by `flutter devices`.

> If you see *"databaseFactory not initialized"*, the app was started on a platform without the
> SQLite setup. Make sure you pulled the latest code (this is fixed) and picked the right device.

## Part 8 — Install the permanent version on the tablet

For daily use in the store, install the release build (faster, no debugger needed):

```powershell
flutter build apk --release
flutter install --release -d <tablet-id>
```

The app stays on the tablet as **entre_sales** and works without the computer.
Its data stays on the tablet when you install a newer version.

> ⚠️ Do **not** uninstall the app from the tablet: uninstalling deletes its database.
> Make a backup first (Part 11).

## Part 9 — First use in the app

1. **Settings → Store details**: store name, address and NIF (printed on PDFs). Press **Save**.
2. **Settings → Categories**: check the tax rates. Add fixed options to a field if you want them
   (e.g. Size: `XS, S, M, L, XL`), or leave options empty to type values freely.
3. **Artists → New artist**: billing details, residency and commission
   (leave commission empty for the default 35%).
4. **Inventory → Log product**: name → artist → delivery date → category → fields → price →
   quantity for each variant.
5. **Sell**: tap products, choose cash or card, **Complete sale**.

## Part 10 — Connect Google Calendar (tablet only, once)

The app reads events whose title contains **"workshop"** from the store's calendar.

1. Get the signing fingerprint (SHA-1). In the project folder:
   ```powershell
   cd android
   .\gradlew signingReport
   cd ..
   ```
   Copy the **SHA1** line under `Variant: release` (by default it is the same key as debug).
2. Go to <https://console.cloud.google.com> signed in with the **store's** Google account.
3. Create a project called **Entre Sales**.
4. **APIs & Services → Library** → search **Google Calendar API** → **Enable**.
5. **APIs & Services → OAuth consent screen**: choose **External**, fill in the app name and email,
   and under **Test users** add the store's Google account.
6. **APIs & Services → Credentials → Create credentials → OAuth client ID**:
   - Application type: **Android**
   - Package name: `com.entre.entre_sales`
   - SHA-1: paste the value from step 1
7. On the tablet: **Settings → Google Calendar → Connect**, sign in with the store account,
   then **Sync now**.
8. If workshops are on a secondary calendar (not the account's main one), copy its
   **Calendar ID** from Google Calendar (calendar settings → *Integrate calendar*), paste it in the
   app's **Calendar ID** field, press **Save**, and **Sync now** again.

> The SHA-1 belongs to the computer that builds the app. If you later build from a different computer,
> add that computer's SHA-1 as a second Android OAuth client.

Sync whenever the tablet is online; tagging sales works offline using the last sync.
Sales during a workshop are tagged automatically; missed ones can be tagged in **Sales**.

## Part 11 — Backups

All data lives only on the tablet. Regularly use **Settings → Backup → Save database backup** and save
the file to Google Drive or email it.

## Updating the app later

```powershell
git pull
flutter pub get
flutter test
flutter build apk --release
flutter install --release -d <tablet-id>
```

Your data is kept.

## Troubleshooting

| Problem | Fix |
|---|---|
| `Building with plugins requires symlink support` | Turn on Windows Developer Mode (Part 1, step 5). |
| `Unable to find suitable Visual Studio toolchain` | Install Visual Studio 2022 with "Desktop development with C++" (Part 1, step 3). |
| `No Windows desktop project configured` | Run `flutter create --platforms=android,windows --org com.entre .` (Part 3). |
| `databaseFactory not initialized` | `git pull` the latest code, then `flutter pub get`. |
| `flutter devices` doesn't show the tablet | Re-plug the cable, accept the USB debugging prompt, try another cable/port. |
| `The name 'MyApp' isn't a class` | Delete `test\widget_test.dart`, then `git pull`. |
| Google sign-in closes with an error | Check the package name and SHA-1 (Part 10) and that the account is a test user. |
| Need to change commission / resident tax rules | Edit `lib\config\business_rules.dart`, then rebuild (Part 8). |
