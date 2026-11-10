# Stav vůči plánu (`Prompts/00-SEZNAMKA_PLAN.md`)

Aktualizováno 2026-11-09.

## Hotovo (část fáze 2: backend jádro)

- `mood`: fúze `0.6·self + 0.4·VL` (VL = průměr energy/valence; ignoruje se při
  confidence < 0.3 nebo vypnutém VL), level HIGH ≥ 0.66 / MID / LOW < 0.33,
  trend = lineární regrese přes posledních 3–5 check-inů (|sklon| < 0.02/den = FLAT),
  čerstvost 36 h, rozpor VL vs. self > 0.35 → „zeptat se zítra znovu“.
- Pauza romantiky: posledních 5 kalendářních dní s check-inem LOW + průměrná valence < 0.33.
  Povzbuzení zůstává, appka ukáže kartu s pomocí.
- `matching`: matice §1.3 (testy: LOW×LOW nikdy, symetrie, každá buňka podle plánu),
  ⚪ buňky vypnuté (`Options.EnableOptional` pro budoucí A/B), povzbuzení jen s oběma opt-iny,
  filtry hledám/generace/status/kraj, sdílený intent povinný, u povzbuzení jen pokec/kafe/čaj.
- Postgres schéma (všechny tabulky z §4) + trigger `matches_guard`: LOW×LOW ani LOW v romantickém
  matchi nejde vložit ani holým SQL (integrační test).
- `alienmatch-api`: `POST /v1/checkins` (režim video/voice), `GET /v1/radar`, migrace při startu, dev auth.

## Rozhodnutí, která jsem udělal sám (k revizi)

- VL skóre do fúze = (energy + valence) / 2.
- Maják může být HIGH↑ i HIGH→ (matice), text plánu zmiňuje jen HIGH↑.
- Pauza romantiky počítá dny s check-inem, ne kalendářní dny za sebou.
- Neznámý level se bere jako LOW (bezpečná strana).

## Místa (Prompts/01-GPS.md)

Backend vrstvy A, katalog Praha a schéma a TTL vrstev B a C: viz `docs/GPS.md`.

## Appka (fáze 3, první řez)

- Flutter `app/` (iOS, Android, web), bundle `com.ol1n.alienmatch`, Distribution pipeline, ikona (FLUX Schnell).
- Onboarding: 18+ a samostatný souhlas čl. 9 → profil jen z ikon (generace, status, děti, intenty, koho hledám,
  maják) → přezdívka → živé zrcadlo MirrorBooth (osa zrcadla, otáčení obrazu, L/R, přední/zadní kamera, všech 24 filtrů zdarma) → kontrola → upload jen složené zrcadlové tváře (čtverec ≤ 1024 px).
- Check-in: škála planeta → supernova, zatím režim `self` (video/hlas přijde s mood-workerem), karta pomoci 116 123.
- Radar: hvězdná mapa, aura podle úrovně, pulz podle trendu, čára ke sdílené hvězdě, slabý signál.
- Moje hvězdy (max 8), „Co o tvé poloze víme“, smazání účtu.
- 10 jazyků v ARB: cs, en, sk, de, pl, es, fr, it, pt, uk.
- Backend: anonymní účet (token, server drží jen SHA-256), profil, fotka (FS, MinIO později), smazání účtu
  ověřené testem přes všechny tabulky s uuid.

## Rozhodnutí Olina k 01-GPS (2026-11-09)

1. Začínáme Prahou.
2. Vrstva B (BLE „Průlet“) **už v MVP**.
3. Beacony: vysvětleno, rozhodnutí o zdarma pro prvních 20 podniků čeká.
4. Limit 8 míst.
5. Název sdíleného místa se po matchi odhalí **automaticky**.

## Zamávání, match a zeď (2026-11-09)

- Zamávat jde jen na planetu, kterou mi radar právě ukazuje (matice + opt-iny platí vždy). Free 5 denně,
  Signál+ / Ol1n Pass bez limitu. Druhá strana se dozví až po oboustranném zamávání.
- Match + zeď v jedné transakci přes DB guard; povzbuzení = jemná zeď s omezenými presety.
  Po matchi se automaticky ukážou názvy sdílených míst. Matchnutí a zablokovaní zmizí z radaru.
- Stickers: vektorový ink (jen geometrie, server odmítne cokoli navíc) nebo preset. Idempotentní
  `client_id` pro frontu pro offline. Posunout a odlepit jde jen vlastní.
- Realtime: WebSocket s jednorázovým lístkem (token nejde do URL), dohnání přes `?after=` po reconnectu.
  Test: doručení do 500 ms.
- Report skryje sticker okamžitě (`review`), block ukončí zeď a skryje oba z radaru.
- Fronta neodeslaných stickerů se ukládá do souboru u každé zdi a po restartu appky se odešle se stejným `client_id`.
- Fronta nahlášení: interní stránka `/admin` (token `ALIENMATCH_ADMIN_TOKEN`, bez tokenu routy neexistují).
  Moderátor vidí kresbu nebo preset, případně fotku nahlášeného, a zvolí Vrátit / Odstranit / Uzavřít.
  `/admin` a `/v1/admin/*` patří jen do interní sítě (Caddy je ven nepustí).
- Moderace VL modelem zatím neběží: stickers se doručují hned, sporné řeší report.

## Průlet, vrstva B (2026-11-09)

Server, appka a nativní BLE jsou hotové, podrobnosti v `docs/GPS.md`. Na skutečných telefonech to zatím
nikdo nezkoušel, chybí běh na pozadí.

## Check-in s videem a hlasem (2026-11-09)

- Appka: video + hlas, nebo jen hlas, 14 s, dvě stálé výzvy. Pošle 3 snímky (640 px JPEG) a zvuk
  (AAC 16 kHz mono), žádné video. Nahrávka v telefonu se po načtení smaže. Pak vlastní škála.
  Bez souhlasu čl. 9 nebo když server vyhodnocení nemá, se nic nenahrává a jde jen hodnocení (`self`).
- Backend: `POST /v1/checkins/media` čte multipart proudově do paměti (nikdy dočasné soubory, test
  hlídá `TMPDIR`), zavolá gateway na SPARKu (ASR → přepis, VL → `{energy, valence, confidence}`),
  buffery vynuluje. Při chybě modelu fallback na vlastní hodnocení. `GET /v1/config` řekne appce,
  jestli vyhodnocení běží.
- **Na SPARKu chybí (rozhodnutí Olina, repo AiStack):** broker nemá v katalogu `vl`
  (Qwen2.5-VL-7B je v LiteLLM jako alias `vl`, `deploy/docker-compose.vl.yaml`) a na SPARKu není
  žádná ASR služba (Whisper) s `/v1/audio/transcriptions`. Dokud nebudou, `ALIENMATCH_GATEWAY_URL`
  zůstává prázdné a check-in je jen vlastní hodnocení.

## Nasazení (2026-11-09)

`https://aliens.ol1n.com` běží na JODĚ: web + API + Postgres + vlastní tunel, viz `docs/deploy.md`.
SPARK: `asr` a `vl` jsou v brokeru (projekt `alienmatch`). Backend je spouští **na vyžádání** přes
API brokeru (Olin nechce pevné okno), nahrávka mezitím čeká jen v paměti (max 15 min). Chybí klíč
k LiteLLM gateway (`ALIENMATCH_GATEWAY_KEY`), pak nastavit `ALIENMATCH_GATEWAY_URL` a
`ALIENMATCH_BROKER_URL` v `.env` na JODĚ. Varianta L40S: `docs/PLAN-l40s.md`.

## Zbývá

- Fáze 0: odpovědi na otázky níže, benchmark VL 7B vs 32B.
- Fáze 1: balíčky `mirror_face` (z MirrorBooth), `sticker_canvas`, `stickers-svc` (glyph_extractor).
- Fáze 2: auth (magic-link/Apple/Google), profily + media (MinIO), mood-worker na SPARKu
  (Whisper + VL přes LiteLLM), matching job à 10 min, waves → match, zeď.
- Fáze 3: Průlet na pozadí a test na zařízeních, `vl` + ASR v brokeru (AiStack), kalibrace vah `w_self/w_vl` per uživatel, MinIO, moderace, IAP.

## Rozhodnutí Olina (2026-11-09, §8 hlavního plánu)

1. Název **AlienMatch**, veřejné repo `lioilsources/AlienMatch`. Doména zatím nerozhodnuta.
2. Originální (nesymetrická) fotka se **nikdy** neodemyká.
3. Check-in: video + hlas, nebo fallback **jen hlas** (`mode: voice`). Jiné režimy nejsou.
4. Profily „jen maják“ (nehledají vztah) jsou povolené: sloupec `beacon_only`, nikdy romantický match.
5. Lokalizace do **všech jazyků** od začátku (stickers jsou jazykově neutrální; UI přes ARB).
6. Ol1n Pass kryje Signál+ **lifetime** (`entitlements.source = ol1n_pass`, `expires_at = NULL`).
