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
| `backend/` | Go služba `alienmatch-api`: check-in, stav nálady, radar, Postgres schéma |
| `docs/STAV.md` | stav vůči plánu, otevřené otázky |
| `Prompts/` | produktový a technický plán |

Appka (Flutter), `stickers-svc`, realtime zeď a mood-worker na SPARKu teprve přijdou, viz `docs/STAV.md`.

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
- `GET /v1/radar` → planety na radaru (`match` / `encourage`), nebo `off_radar` bez check-inu za 36 h
