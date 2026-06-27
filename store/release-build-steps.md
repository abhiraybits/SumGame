# Building for Release (Play Store)

## Step 1 — Generate the keystore (do this ONCE, keep the file safe)

Run from PowerShell on your Windows machine:

```powershell
# Create a folder to keep it
mkdir C:\sum10-keystore

# Generate the key (keytool comes with Java/Android Studio)
keytool -genkey -v `
  -keystore C:\sum10-keystore\release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias sum10
```

You'll be asked for passwords and your name/org — remember the passwords.

## Step 2 — Create keystore.properties

Create the file `flutter_app/android/keystore.properties` (NOT committed to git):

```
storeFile=C:/sum10-keystore/release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=sum10
keyPassword=YOUR_KEY_PASSWORD
```

## Step 3 — Build the App Bundle

```powershell
cd C:\Users\manyu\memwatch\sum10-game\flutter_app
$env:PATH += ";C:\src\flutter\bin"
flutter build appbundle --release
```

Output: `build\app\outputs\bundle\release\app-release.aab`

## Step 4 — Upload to Play Console

Upload `app-release.aab` to Google Play Console → your app → Production (or Internal Testing first).

## Play Store Assets Checklist

| Asset | Size | Status |
|---|---|---|
| App icon | 512×512 PNG, no alpha | ⬜ Need to create |
| Feature graphic | 1024×500 PNG | ⬜ Need to create |
| Phone screenshots | Min 2, max 8 | ⬜ Take from running app |
| Short description | Max 80 chars | ✅ In listing.md |
| Full description | Max 4000 chars | ✅ In listing.md |
| Privacy policy URL | Any hosted URL | ⬜ Need to host |

## App Icon

Create a 512×512 PNG with:
- Background: #0f0f1a (dark navy, matches the game)
- A bold "10" or "SUM" text in #f0c040 (gold)
- No alpha channel (Play Store rejects transparent icons)

Tools: Canva, Figma, or any image editor.

## Privacy Policy

Minimum required text (host on GitHub Pages or any free site):

> Sum 10 does not collect, store, or share any personal data.
> The app does not require an internet connection and has no user accounts.
