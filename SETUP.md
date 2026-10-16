# Setting up and running Entre Sales

A step-by-step guide for a Windows computer and the store's Android tablet.
Commands go in **PowerShell** (or the terminal inside VS Code / Android Studio).

---

## Part 1 — Install the tools (once per computer)

1. **Install Git** from <https://git-scm.com/download/win> (default options are fine).
2. **Install Flutter** following <https://docs.flutter.dev/get-started/install/windows/mobile>.
   - Use Flutter **3.27 or newer**.
   - The guide also installs **Android Studio** and the Android SDK. Open Android Studio once
     and let it finish downloading its components.
3. Accept the Android licences:
   ```powershell
   flutter doctor --android-licenses
   ```
4. Check everything is green for Android:
   ```powershell
   flutter doctor
   ```
   Lines about Chrome, Visual Studio or Linux can be ignored. The **Flutter** and
   **Android toolchain** lines must have a ✓.

## Part 2 — Prepare the tablet (once)

1. On the tablet open **Settings → About tablet** (sometimes under *Software information*).
2. Tap **Build number** 7 times until it says you are a developer.
3. Go back to **Settings → System → Developer options** and turn on **USB debugging**.
4. Connect the tablet to the computer with a USB cable. On the tablet, accept
   **"Allow USB debugging?"** (tick *Always allow from this computer*).
5. Check the computer sees it:
   ```powershell
   flutter devices
   ```
   The tablet should be listed.

## Part 3 — Get the code (first time)

```powershell
cd $HOME\Documents
git clone https://github.com/Hassan-Melhim/entre-sales.git
cd entre-sales
```

> **Already cloned it and ran `flutter create` before?** Delete the sample test that
> `flutter create` made, then pull the latest code:
> ```powershell
> Remove-Item test\widget_test.dart
> git pull
> ```

## Part 4 — Generate the Android project (first time)

The Android project folder is not in the repository, so create it once:

```powershell
flutter create --platforms=android --org com.entre .
```

This only adds missing files; it does not overwrite the app's code.

Then give the app internet access (only used for Google Calendar):

1. Open `android\app\src\main\AndroidManifest.xml`.
2. Just **above** the line that starts with `<application`, add:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
3. Save.

## Part 5 — Download packages and check the code

```powershell
flutter pub get
flutter analyze
flutter test
```

- `flutter analyze` should report **no errors** (blue "info" lines are style hints and are safe).
- `flutter test` should end with **All tests passed!**

If either shows errors, copy the output and send it over.

## Part 6 — Run the app on the tablet

With the tablet connected:

```powershell
flutter run
```

The first build takes a few minutes. The app opens on the tablet in landscape.
While it is running, press `r` in the terminal to reload after a code change, `q` to quit.

## Part 7 — Install a permanent version on the tablet

`flutter run` installs a debug build, which is slower and meant for testing.
For daily use in the store, install the release build:

```powershell
flutter build apk --release
flutter install --release
```

The app stays on the tablet as **entre_sales** and works without the computer.
Its data stays on the tablet even when you install a newer version.

> ⚠️ Do **not** uninstall the app from the tablet: uninstalling deletes its database.
> Make a backup first (see Part 10).

## Part 8 — First use in the app

1. **Settings → Store details**: store name, address and NIF (printed on PDFs). Press **Save**.
2. **Settings → Categories**: check the tax rates. Add fixed options to a field if you want them
   (e.g. Size: `XS, S, M, L, XL`), or leave options empty to type values freely.
3. **Artists → New artist**: add each artist with billing details, residency and commission
   (leave commission empty for the default 35%).
4. **Inventory → Log product**: name → artist → delivery date → category → fields → price →
   quantity for each variant.
5. **Sell**: tap products, choose cash or card, **Complete sale**.

## Part 9 — Connect Google Calendar (optional, once)

The app reads events whose title contains **"workshop"** from the store's calendar.

1. Get the computer's signing fingerprint (SHA-1). In the project folder:
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

> The SHA-1 belongs to the computer that builds the app. If you later build and install from a
> different computer, add that computer's SHA-1 as a second Android OAuth client.

Sync whenever the tablet is online; tagging sales works offline using the last sync.
Sales during a workshop are tagged automatically; missed ones can be tagged in **Sales**.

## Part 10 — Backups

All data lives only on the tablet. Regularly use
**Settings → Backup → Share database backup** and save the file to Google Drive or email it.

## Updating the app later

```powershell
cd $HOME\Documents\entre-sales
git pull
flutter pub get
flutter build apk --release
flutter install --release
```

Your data is kept.

## Troubleshooting

| Problem | Fix |
|---|---|
| `flutter devices` doesn't show the tablet | Re-plug the cable, accept the USB debugging prompt, try another cable/port. |
| `The name 'MyApp' isn't a class` | Delete `test\widget_test.dart` and run `git pull` (see Part 3). |
| Google sign-in closes with an error | Check the package name and SHA-1 in Part 9, and that the account is a test user. |
| Sync says "Not signed in" | Settings → Google Calendar → Connect again. |
| Need to change commission / resident tax rules | Edit `lib\config\business_rules.dart`, then rebuild (Part 7). |
