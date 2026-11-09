# MIMO (kódové jméno, „Seznamka pro Mimozemšťany“)

## Účel
Seznamka beze slov: symetrická „mimozemská“ tvář (MirrorBooth), zprávy jako ručně psané
stickers na společné zdi (HandWrittenStickers), matching podle nálady a jejího trendu
(BiPolarMonitor). Plán: `Prompts/00-SEZNAMKA_PLAN.md`, stav: `docs/STAV.md`.

## Build a test
```
cd backend
go vet ./... && go test ./...          # gate
sqlc generate                          # po změně internal/db/queries nebo migrací
MIMO_TEST_DATABASE_URL=postgres://… go test ./internal/store/   # trigger v DB
```

## Mapa
- `backend/internal/mood` — fúze self/VL skóre, level, trend, čerstvost, pauza pro podporu
- `backend/internal/matching` — matice §1.3, kandidáti na radar
- `backend/internal/db` — migrace (embed, golang-migrate), sqlc dotazy, generovaný kód v `sqlc/`
- `backend/internal/store` — Postgres adaptér; `service` — use-casy; `api` — HTTP
- `backend/cmd/mimo-api` — server
- `Prompts/` — zadání

## Invarianty
- **LOW × LOW nikdy.** Tvrdě v `matching` i triggerem `matches_guard` v DB. Nikdy konfigurovatelné.
- LOW uživatel nikdy nedostane romantický match; povzbuzení jen HIGH maják × LOW s oběma opt-iny.
- **Žádné textové pole** pro uživatele kromě přezdívky (≤ 12 znaků, moderovaná). Hlídat v review.
- Slovník: nálada / energie / signál. Nikdy „deprese“, „bipolární“, „porucha“; BiPolarMonitor se do produktu nepropisuje.
- Žádné video/audio/raw snímky na serveru; ukládají se jen skóre a timestampy.
- API nevrací čísla nálady, jen level/trend pro auru.
- Do matchingu jen stav < 36 h. VL je poradní, self skóre má přednost.
- Žádná SDK třetích stran pro tracking/analytiku.
- Nasazenou migraci needitovat, přidat novou. `internal/db/sqlc` ručně needitovat.

## Kam dál
`docs/STAV.md` (co je hotové, otevřené otázky), `Prompts/00-SEZNAMKA_PLAN.md`.
