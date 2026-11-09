# Release AlienMatch: ruční kroky v účtech

Pipeline je z Distribution (`.github/workflows/release-ios.yml`, `release-android.yml`, `ci.yml`).
Release spouští tag `v*`, postup: skill `release-flutter`. Tyhle kroky skript neudělá:

## Apple
1. App ID `com.ol1n.alienmatch` (Explicit). Capabilities zatím žádné (App Group ani extension nejsou).
2. Distribution provisioning profile pro App Store na `com.ol1n.alienmatch`,
   ulož ho do `Distribution/Apple/AlienMatch/` (setup-gh-secrets bere první `*.mobileprovision`).
3. App Store Connect: nová appka „AlienMatch“, bundle `com.ol1n.alienmatch`, primární jazyk čeština,
   kategorie **Dating**, věkové hodnocení 17+.
   - Privacy Policy URL: `https://lioilsources.github.io/AlienMatch/privacy.html`
   - Support URL: `https://lioilsources.github.io/AlienMatch/support.html`
   - Marketing URL: `https://olin.now/alienmatch`
   - App Privacy: žádný tracking. Sbírané údaje: User Content (fotka), Health & Fitness (nálada,
     pouze se souhlasem), Other (profil). Location: **not collected**.
   - Bluetooth: „Bluetooth proximity, not linked to location“; Průlet je opt-in.

## Google Play
1. Upload keystore do `Distribution/Android/AlienMatch/upload-keystore.jks` (nový pro tuhle appku).
2. Play Console: appka `com.ol1n.alienmatch`, kategorie Dating, Content rating vyplnit (dating),
   Data safety: žádný tracking, poloha **ne**sbírána (BLUETOOTH_SCAN s `neverForLocation`; do Androidu 11
   je ACCESS_FINE_LOCATION jen kvůli skenování), zdravotní údaje (nálada) volitelně.
3. Zásady ochrany soukromí: `https://lioilsources.github.io/AlienMatch/privacy.html`.

## Firebase App Distribution
1. Android appka `com.ol1n.alienmatch` v projektu Firebase, App ID do secretu `FIREBASE_ANDROID_APP_ID`.

## GitHub secrets
```
Distribution/scripts/setup-gh-secrets.sh --repo lioilsources/AlienMatch --app AlienMatch
```
Nastaví: `IOS_P12_*`, `IOS_PROVISION_PROFILE_BASE64`, `IOS_TEAM_ID`, `IOS_KEYCHAIN_PASSWORD`,
`APP_STORE_CONNECT_API_*`, `ANDROID_KEYSTORE_*`, `ANDROID_KEY_*`, `FIREBASE_*`.

## Build
API adresa se zadává při buildu: `--dart-define=API_BASE_URL=https://…` (doplnit do release workflow,
až poběží backend na JODĚ).
