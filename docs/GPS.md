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

## Zbývá

- G1 appka: výběr na mapě (MapLibre) a hledáním, vizualizace hvězd a souhvězdí na radaru.
- G2 (vrstva C): detekce beaconů, `POST` check-inu v podniku, admin pro partnery, rotující token
  (Eddystone-EID nebo denní QR) proti falešným beaconům.
- G3 (vrstva B): BLE TEK/RPI v appce, upload TEK (jen `day = včera`, jeden za den, podepsaný),
  download podle regionu, Průlet a zamávání.
- G4: další kraje a IDS, eventy, partnerský self-service.
- Proxy test payloadů z appky (žádné `lat`, `lon`, geohash ani čas kontaktu) až s integračními testy appky.
- Zveřejnit katalog jako open data (ODbL share-alike).

## Atribuce dat

- Jízdní řády PID: © ROPID, licence CC BY 4.0 (data.pid.cz).
- Mapová data: © přispěvatelé OpenStreetMap, licence ODbL. Odvozená databáze katalogu podléhá ODbL.
