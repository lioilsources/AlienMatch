# AlienMatch („Seznamka pro Mimozemšťany“, v plánech kódové jméno MIMO)

## Účel
Seznamka beze slov: symetrická „mimozemská“ tvář (MirrorBooth), zprávy jako ručně psané
stickers na společné zdi (HandWrittenStickers), matching podle nálady a jejího trendu
(BiPolarMonitor). Plán: `Prompts/00-SEZNAMKA_PLAN.md`, stav: `docs/STAV.md`.

## Build a test
```
cd app && flutter analyze && flutter test        # gate appky
cd packages/mirror_face && flutter test
flutter run --profile --dart-define=API_BASE_URL=http://localhost:8080
cd backend
go vet ./... && go test ./...          # gate
sqlc generate                          # po změně internal/db/queries nebo migrací
ALIENMATCH_TEST_DATABASE_URL=postgres://… go test ./internal/store/   # trigger v DB
```

## Mapa
- `app/` — Flutter appka (iOS, Android, web), l10n v `app/lib/l10n/*.arb`; `packages/mirror_face` — symetrická tvář (z MirrorBooth)
- `backend/internal/mood` — fúze self/VL skóre, level, trend, čerstvost, pauza pro podporu
- `backend/internal/matching` — matice §1.3, kandidáti na radar
- `backend/internal/db` — migrace (embed, golang-migrate), sqlc dotazy, generovaný kód v `sqlc/`
- `backend/internal/places` — souhvězdí, k-anonymita, ranking; `catalog` — import GTFS/OSM
- `backend/cmd/places-import`, `bin/fetch-catalog-praha.sh` — katalog míst (data do `run/`)
- `backend/internal/store` — Postgres adaptér; `service` — use-casy; `api` — HTTP
- `backend/cmd/alienmatch-api` — server
- `Prompts/` — zadání

## Invarianty
- **LOW × LOW nikdy.** Tvrdě v `matching` i triggerem `matches_guard` v DB. Nikdy konfigurovatelné.
- LOW uživatel ani profil „jen maják“ nikdy nedostane romantický match; povzbuzení jen HIGH maják × LOW s oběma opt-iny.
- Zveřejní se jen symetrická varianta tváře; originální fotka se neodemyká nikdy.
- **Žádné textové pole** pro uživatele kromě přezdívky (≤ 12 znaků) a hledání v katalogu míst. Hlídají to widget testy (`app/test/app_test.dart`).
- Profilová fotka jen živě z kamery, nikdy z galerie; server dostane jen zvolenou symetrickou variantu.
- Slovník: nálada / energie / signál. Nikdy „deprese“, „bipolární“, „porucha“; BiPolarMonitor se do produktu nepropisuje.
- Žádné video/audio/raw snímky na serveru; ukládají se jen skóre a timestampy.
- API nevrací čísla nálady, jen level/trend pro auru.
- **Server nikdy nedostane souřadnici uživatele.** `lat/lon` jen v katalogu `places`; API je odmítá. Místa max 8, zobrazení jen při k ≥ 5 a nejvýš jedno. TTL vrstev B a C vynucuje job. Viz `docs/GPS.md`.
- Katalog nikdy neobsahuje zdravotnictví, bydlení, ZŠ ani SŠ.
- Do matchingu jen stav < 36 h. VL je poradní, self skóre má přednost.
- Žádná SDK třetích stran pro tracking/analytiku.
- Nasazenou migraci needitovat, přidat novou. `internal/db/sqlc` ručně needitovat.

## Kam dál
`docs/STAV.md` (co je hotové), `docs/GPS.md` (místa), `docs/release.md` (ruční kroky ve storech), `Prompts/`.
