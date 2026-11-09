# AlienMatch — seznamka beze slov

V plánech v `Prompts/` vystupuje pod kódovým jménem MIMO.

- **Fotka** = živě pořízená symetrická „mimozemská“ tvář, nikdy z galerie. Originál se nikdy neukáže.
- **Zprávy** = ručně psané stickers lepené na společnou zeď, žádný psaný text.
- **Matching** podle nálady a jejího trendu. Dva lidé „dole“ se nikdy nespojí;
  kdo je nahoře, může (po souhlasu obou) povzbudit někoho dole.
- Bez reklam, bez trackingu, zpracování on-prem.

## Co tu je

| Složka | Obsah |
|---|---|
| `app/` | Flutter appka: onboarding, check-in, radar, místa, nastavení |
| `packages/mirror_face` | symetrická tvář L+L / R+R, sdílená s MirrorBooth |
| `backend/` | Go služba `alienmatch-api`: check-in, stav nálady, radar, Postgres schéma |
| `docs/STAV.md` | stav vůči plánu, otevřené otázky |
| `Prompts/` | produktový a technický plán |

`stickers-svc`, realtime zeď, zamávání a mood-worker na SPARKu teprve přijdou, viz `docs/STAV.md`.

## Spuštění appky

```sh
cd app
flutter run --profile --dart-define=API_BASE_URL=http://localhost:8080
```

Web: [lioilsources.github.io/AlienMatch](https://lioilsources.github.io/AlienMatch/), zásady: [privacy](https://lioilsources.github.io/AlienMatch/privacy.html).

## Spuštění backendu

```sh
cd backend
go test ./...
cp ../.env.example ../.env   # vyplň ALIENMATCH_DATABASE_URL
ALIENMATCH_DATABASE_URL=… ALIENMATCH_DEV_AUTH=1 go run ./cmd/alienmatch-api
```

Migrace se aplikují při startu. `ALIENMATCH_DEV_AUTH=1` je jen pro lokální vývoj
(věří hlavičce `X-AlienMatch-User`); bez něj server zatím odmítá všechny požadavky,
dokud nepřijde skutečné přihlášení.

### API (zatím)

- `GET /healthz`
- `POST /v1/checkins` `{"self":0.7,"vl":{"energy":…,"valence":…,"confidence":…}}` → level, trend, příznaky
- `GET /v1/radar` → planety na radaru (`match` / `encourage`, případně `star` / `weak_signal`), nebo `off_radar` bez check-inu za 36 h
- `GET /v1/places?q=andel` → hledání v katalogu míst ve vlastním regionu
- `PUT /v1/me/places` `{"place_ids":[…]}` → moje souhvězdí (max 8)
- `GET /v1/me/location-data` → všechno, co server ví o mých místech

Souřadnice uživatele server nikdy nepřijímá, viz `docs/GPS.md`.

## Katalog míst

```sh
bin/fetch-catalog-praha.sh            # stáhne PID GTFS + OSM do run/, vypíše počty
bin/fetch-catalog-praha.sh --import   # a zapíše do ALIENMATCH_DATABASE_URL
```

Data: jízdní řády PID © ROPID (CC BY 4.0), mapová data © přispěvatelé OpenStreetMap (ODbL).
