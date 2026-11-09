# Místa bez trackingu: stav implementace

Zadání: `Prompts/01-GPS.md`. Tady je, co z něj v backendu existuje a jak.

## Hotovo (G1 backend: vrstva A, katalog)

- **Katalog `places`** (veřejná data). Importuje se příkazem `backend/cmd/places-import`,
  stažení a import pro Prahu dělá `bin/fetch-catalog-praha.sh` (data jdou do gitignorovaného `run/`).
  - GTFS PID: nástupiště se slučují do uzlu (`stop:pid:N<asw_node_id>`), aby lidé z nástupišť A a B
    jedné zastávky sdíleli jedno místo a k-anonymita se nedrobila. Region podle tarifního pásma:
    P/0/B = `CZ-PHA`, zbytek PID = `CZ-STC`. Linky jsou `route:pid:<route_id>`.
  - OSM přes Overpass (dotaz na obdélník Prahy, některé mirrory nemají data území): podniky (`poi:`),
    VŠ a VOŠ (`edu:`), kancelářské budovy (`office:`). V Praze OSM značí desítky středních škol jako
    `amenity=college`, proto `college` projde jen s „VOŠ / vyšší odborná“ v názvu. Cokoli se znakem
    střední školy (gymnázium, SOŠ, SOU, SPŠ, SUŠ, OA, konzervatoř…) nebo koleje v názvu vypadne,
    včetně společných budov typu „VOŠ, SOŠ a Gymnázium“.
  - Stav importu 2026-11-09: 8 344 zastávek (1 505 Praha), 872 linek, 6 526 podniků, 86 VŠ/VOŠ, 91 budov.
  - Nikdy do katalogu: zdravotnictví (`hospital|clinic|doctors|dentist|pharmacy`, jakýkoli `healthcare`),
    bydlení (`building=residential|house|apartments|…`, `landuse=residential`), ZŠ, SŠ a školky,
    `access=private`, místa bez jména. Pravidla jsou v `internal/catalog`, testy na každé z nich.
- **Souhvězdí:** uživatel má nejvýš **8 míst** (kontroluje to service i trigger v DB).
  Ukládá se jen `place_id` a `added_at`, žádný čas návštěvy.
- **k-anonymita (k ≥ 5):** `place_counts` přepočítává job každých 10 min. Počítají se jen aktivní
  členové (check-in < 36 h). Planeta na radaru ukáže nejvýš **jedno** sdílené místo (`star`), a to jen
  z vlastních míst volajícího s ≥ 5 členy. Jinak dostane jen `weak_signal`. Počty ani skóre rankingu
  nikdy neodcházejí ze serveru.
- **Ranking:** kandidáti, kteří prošli maticí nálady, se řadí podle bonusu za sdílená místa
  (zastávka 3, linka 1, podnik/škola/budova/partner/event 2).
- **Žádné souřadnice od uživatele:** API odmítá neznámá pole v JSON (`lat`, `location`…)
  i dotazové parametry `lat|lon|lng|latitude|longitude|geohash|gps|location|coords`.
  Integrační test prochází `information_schema` a selže, když se mimo `places` objeví sloupec
  podobný souřadnici.
- **„Co o tvé poloze víme“:** `GET /v1/me/location-data` vrátí vybraná místa, počet aktivních
  BLE klíčů, aktivní check-iny v podnicích a prázdné `coordinates`.
- **Schéma vrstev B a C** (`tek_uploads`, `encounters` jen se dnem, `venue_checkins`, `partners`)
  s TTL. Mazání (TEK a potkání po 14 dnech, check-iny v podniku po 6 h, eventy po expiraci)
  vynucuje housekeeping job v `alienmatch-api`, ne aplikační dobrá vůle. Testy TTL jsou integrační.

## Vrstva B „Průlet“ (MVP, rozhodnutí 2026-11-09)

- Opt-in v Nastavení, výchozí stav vypnuto. Vypnutí smaže klíče a potkání na serveru i v telefonu.
- **Protokol:** denní klíč TEK (16 B, náhodný, v keystore) → každých 15 min RPI = HMAC-SHA256(TEK,
  „AM-RPI“ ‖ interval)[0:12]. RPI má 12 B, protože 128bitové UUID služby + RPI se musí vejít do 31B
  scan response. Server přijme jen klíč za **včerejšek**, jeden denně (`POST /v1/flyby/keys`).
- **Rádio (nativní, bez knihovny):**
  - Android vysílá UUID služby v reklamě a RPI ve scan response (service data).
  - iOS service data vysílat neumí, RPI proto vystaví jako GATT charakteristiku a skener si ji krátce
    přečte (connect → read → disconnect, cache 5 min). Kód je v `ios/Runner/AppDelegate.swift`
    a `android/…/FlybyRadio.kt`.
  - Android skenuje s `neverForLocation`, polohu nečte.
- **Klasifikace v telefonu:** spoj ≥ 8 min v pohybu (akcelerometr), zastávka 2–10 min stojíc,
  podnik ≥ 20 min stojíc. RPI se točí, takže jedna jízda je víc RPI; spojují se mezery do 5 min.
- **Párování v telefonu:** `GET /v1/flyby/keys` vrátí klíče ostatních z mého regionu (14 dní),
  telefon z nich spočítá RPI a porovná s tím, co viděl. Server se nedozví, co telefon viděl.
- **Zamávání na průlet:** `POST /v1/flyby/waves {day, tek, kind}`. Odpověď je vždy stejná (202),
  ať klíč existuje, nebo ne. Kometa ☄️ se na radaru ukáže, až když klíč nahráli oba, oba zamávali
  a oba projdou maticí nálady (LOW×LOW nikdy). Ukáže se jen typ kontaktu, nikdy čas ani místo.
- **Omezení MVP:** běží jen s otevřenou appkou (iOS na pozadí BLE omezuje, background modes zatím
  nejsou; Android foreground service později).
- **Knihovna:** `flutter_blue_plus` 2.x má od 2026 licenci placenou pro komerční použití a posílá
  při buildu telemetrii, proto je BLE napsané nativně.

## Zbývá

- G1 appka: výběr na mapě (MapLibre) a hledáním, vizualizace hvězd a souhvězdí na radaru.
- G2 (vrstva C): detekce beaconů, `POST` check-inu v podniku, admin pro partnery, rotující token
  (Eddystone-EID nebo denní QR) proti falešným beaconům.
- G3 dokončení: běh na pozadí (iOS background modes + Android foreground service), test na dvou
  skutečných telefonech (iOS↔iOS, iOS↔Android, Android↔Android), baterie (duty-cycle 10 s / 60 s).
- G4: další kraje a IDS, eventy, partnerský self-service.
- Proxy test payloadů z appky (žádné `lat`, `lon`, geohash ani čas kontaktu) až s integračními testy appky.
- Zveřejnit katalog jako open data (ODbL share-alike).

## Atribuce dat

- Jízdní řády PID: © ROPID, licence CC BY 4.0 (data.pid.cz).
- Mapová data: © přispěvatelé OpenStreetMap, licence ODbL. Odvozená databáze katalogu podléhá ODbL.
