# MIMO — seznamka beze slov

Pracovní kódové jméno. Finální název (Mimo / Ufonka / Antény / …) teprve padne.

- **Fotka** = živě pořízená symetrická „mimozemská“ tvář, nikdy z galerie.
- **Zprávy** = ručně psané stickers lepené na společnou zeď, žádný psaný text.
- **Matching** podle nálady a jejího trendu. Dva lidé „dole“ se nikdy nespojí;
  kdo je nahoře, může (po souhlasu obou) povzbudit někoho dole.
- Bez reklam, bez trackingu, zpracování on-prem.

## Co tu je

| Složka | Obsah |
|---|---|
| `backend/` | Go služba `mimo-api`: check-in, stav nálady, radar, Postgres schéma |
| `docs/STAV.md` | stav vůči plánu, otevřené otázky |
| `Prompts/` | produktový a technický plán |

Appka (Flutter), `stickers-svc`, realtime zeď a mood-worker na SPARKu teprve přijdou, viz `docs/STAV.md`.

## Spuštění backendu

```sh
cd backend
go test ./...
cp ../.env.example ../.env   # vyplň MIMO_DATABASE_URL
MIMO_DATABASE_URL=… MIMO_DEV_AUTH=1 go run ./cmd/mimo-api
```

Migrace se aplikují při startu. `MIMO_DEV_AUTH=1` je jen pro lokální vývoj
(věří hlavičce `X-Mimo-User`); bez něj server zatím odmítá všechny požadavky,
dokud nepřijde skutečné přihlášení.

### API (zatím)

- `GET /healthz`
- `POST /v1/checkins` `{"self":0.7,"vl":{"energy":…,"valence":…,"confidence":…}}` → level, trend, příznaky
- `GET /v1/radar` → planety na radaru (`match` / `encourage`), nebo `off_radar` bez check-inu za 36 h
