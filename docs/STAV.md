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

## Zbývá

- Fáze 0: odpovědi na otázky níže, benchmark VL 7B vs 32B.
- Fáze 1: balíčky `mirror_face` (z MirrorBooth), `sticker_canvas`, `stickers-svc` (glyph_extractor).
- Fáze 2: auth (magic-link/Apple/Google), profily + media (MinIO), mood-worker na SPARKu
  (Whisper + VL přes LiteLLM), matching job à 10 min, waves → match, zeď.
- Fáze 3+: Flutter appka, realtime zeď, moderace, IAP, smazání účtu včetně MinIO.

## Rozhodnutí Olina (2026-11-09, §8 hlavního plánu)

1. Název **AlienMatch**, veřejné repo `lioilsources/AlienMatch`. Doména zatím nerozhodnuta.
2. Originální (nesymetrická) fotka se **nikdy** neodemyká.
3. Check-in: video + hlas, nebo fallback **jen hlas** (`mode: voice`). Jiné režimy nejsou.
4. Profily „jen maják“ (nehledají vztah) jsou povolené: sloupec `beacon_only`, nikdy romantický match.
5. Lokalizace do **všech jazyků** od začátku (stickers jsou jazykově neutrální; UI přes ARB).
6. Ol1n Pass kryje Signál+ **lifetime** (`entitlements.source = ol1n_pass`, `expires_at = NULL`).
