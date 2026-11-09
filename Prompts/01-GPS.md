# 01-GPS.md — Geolokace bez trackingu (doplněk k SEZNAMKA_PLAN.md, kódové jméno MIMO)

> Cíl: vesmír plný lidí, kteří čekají na stejné zastávce, jezdí stejnou tramvají, chodí do stejného
> podniku, sedí ve stejné škole / kancelářské budově — **aniž by server kdy viděl souřadnice, trasu
> nebo časový průběh pohybu kohokoli.** Tenhle dokument říká, jak toho dosáhnout, co je kompromis,
> a jak to zapadá do matchingu z hlavního plánu.

---

## 0. Principy (nepřekročitelné)

1. **Server nikdy nedostane GPS souřadnici.** Ani zaokrouhlenou, ani geohash, ani „kraj z GPS“.
   Hrubá geografie v hlavním plánu (okres/kraj) se zadává **ručně výběrem**, ne ze senzoru.
2. **Sdílíš místa, ne trasu.** Uživatel si sám vybere konkrétní *místa* (zastávka, linka, podnik,
   budova) z katalogu. To je profilový tag jako „kafe“ nebo „GenZ“, žádné sledování.
3. **„Potkání“ se detekuje lokálně.** Zda jsme spolu jeli tramvají, zjistí telefon sám (Bluetooth),
   server jen zprostředkuje přání se seznámit. Vzor: Apple/Google Exposure Notification (2020).
4. **k-anonymita.** Nikdy neukázat údaj, který by někoho identifikoval vyloučením
   („na zastávce Palmovka je 1 mimozemšťan GenX rozvedený“). Práh **k ≥ 5**, jinak se místo neukáže.
5. **Odhalit až po matchi, se souhlasem obou.** Před matchem se ukazuje jen „sdílíte souhvězdí“.
   Kdy a kde přesně, se neukazuje nikdy; po matchi jen název místa.
6. **Krátká retence.** Dynamické tokeny potkání žijí **14 dní**, pak mizí. Statické výběry míst
   drží uživatel sám a kdykoli je smaže.
7. **Transparentnost ve storu i v appce.** Jedna obrazovka „Co o tvé poloze víme“ ukazuje
   přesně a úplně, co je na serveru (seznam vybraných míst + počet aktivních tokenů). Nic víc tam není.

---

## 1. Tři vrstvy

### Vrstva A — „Souhvězdí“ (statická, výběr z katalogu) → kryje případy 1–4 rovnou

Uživatel přidá do profilu až **8 míst** z katalogu. Na server jde jen `place_id` z katalogu
(jako tag). Žádný senzor není potřeba — funguje i na webu.

| Typ místa | Zdroj katalogu | Příklad `place_id` |
|---|---|---|
| Zastávka MHD | GTFS (PID / ostatní kraje — data.pid.cz, ostatní IDS přes OpenData) | `stop:pid:U1040Z1` |
| Linka MHD (tramvaj/bus/metro/vlak) | GTFS routes | `route:pid:22` |
| Podnik (bar, kavárna, gym, knihovna…) | OpenStreetMap POI (Overpass export → vlastní katalog v Postgresu) | `poi:osm:n123456` |
| Škola / univerzita / fakulta | OSM `amenity=school|university` + ručně kurátorovaný seznam budov | `edu:cvut-fel-dejvice` |
| Kancelářská budova / areál | OSM `building=office` + ruční kurátorství velkých (Karlín, Pankrác…) | `office:rustonka` |
| Partnerský podnik | ruční kurátorství, má navíc beacon (vrstva C) | `partner:u-chrestyse` |

- UI: mapa jen **pro výběr** (Flutter `maplibre`, dlaždice z vlastního tile serveru na JODA nebo
  MapTiler free tier bez trackingu — ověřit TOS). Uživatel klepne na zastávku/podnik → přidá do
  souhvězdí. Mapa se může ale nemusí centrovat podle GPS — pokud ano, **GPS se použije jen
  na zařízení pro centrování mapy, nikdy se neodesílá**.
- Fuzzy výběr bez mapy: hledání v katalogu („Anděl“, „linka 22“, „ČVUT FEL“) — jediné textové
  pole kromě přezdívky; je to vyhledávání v katalogu, ne komunikace, takže pravidlo „beze slov“ drží.
- Server: tabulka `profile_places(user_id, place_id, kind, added_at)`. Žádný timestamp návštěvy.
- Match efekt: sdílené `place_id` = **souhvězdí**. V radaru se zobrazí jako společná hvězda mezi dvěma
  planetami; ranking kandidátů (kteří prošli maticí nálady) dostane bonus za každé sdílené místo
  (zastávka 3 b, linka 1 b, podnik 2 b, škola/budova 2 b; linky jsou velké množiny, proto málo).
- k-anonymita: souhvězdí se zobrazí jen pokud má místo v daném okamžiku ≥ 5 aktivních členů
  (bez ohledu na filtr). Jinak uživatel vidí „slabý signál“ a místo zůstává jen pro ranking.

### Vrstva B — „Průlet“ (dynamická, Bluetooth, bez polohy) → „opravdu jsme se dnes potkali“

Vrstva A říká „chodíme na stejné místo“. Vrstva B říká **„byli jsme tam zároveň“** — a to **bez
jakékoliv polohy**, čistě přes BLE blízkost. Opt-in, default vypnuto.

Protokol (zjednodušená Exposure Notification):
- Každý den telefon vygeneruje náhodný **denní klíč `TEK_d`** (16 B), nikam ho neposílá.
- Každých 15 min odvodí **`RPI = HMAC(TEK_d, interval)`** a vysílá ho jako BLE advertisement
  (vlastní service UUID). Zároveň skenuje a ukládá **lokálně** cizí RPI + trvání kontaktu + RSSI.
- Klasifikace kontaktu **na zařízení** (nic z toho neopouští telefon):
  - *stejná tramvaj/bus*: kontakt ≥ 8 min, RSSI stabilní, akcelerometr říká „v pohybu“
    (Core Motion / Activity Recognition: `automotive`/`in_vehicle`)
  - *stejná zastávka*: kontakt 2–10 min, stacionární, volitelně uvnitř geofence zastávky z vrstvy A
    (geofence je **lokální**, slouží jen k označení kontaktu typem „zastávka“)
  - *stejný podnik/budova*: kontakt ≥ 20 min, stacionární
- **Kdo chce být potkatelný**, nahrává na server jednou denně své `TEK_{d-1}` (klíč za
  *včerejšek*, nikdy dnešní — útočník tak nemůže sledovat živě). Server drží
  `tek_uploads(user_id, day, tek)` 14 dní.
- Klient si jednou denně stáhne **sadu TEK za svůj ručně zvolený region** (kraj) a **lokálně**
  spočítá, zda některý z pozorovaných RPI patří některému staženému TEK → tím ví: „včera jsem jel
  15 min s držitelem klíče K“.
- Teprve když uživatel chce („Zamávat na toho, s kým jsem jel“), klient pošle serveru
  `(my_user_id, K, kind)`. Server K ↔ user přeloží a vytvoří **Průlet** mezi oběma —
  ale druhé straně ho ukáže **až když ta sama taky nahrála svůj TEK a oba projdou maticí nálady**.
  Nikdo se nedozví o někom, kdo o to nestojí.
- Co server ví: že uživatelé X a Y spolu byli ≥ N minut někdy včera, typ kontaktu. **Ne kde.**
  To je zároveň hranice, kterou říkáme uživateli natvrdo v onboardingu.

Technické poznámky:
- iOS: BLE advertising na pozadí je omezený (iOS dává pozadní advertisement do „overflow
  area“, čitelný jen jinými iOS zařízeními na pozadí přes specifický trik; cross-platform na pozadí
  je slabý). Realistické chování: **plná funkce, když je appka otevřená nebo nedávno použitá;
  degradovaná na pozadí.** Řešení v UX: check-in nálady (hlavní plán) se dělá ráno v MHD →
  appka je otevřená právě v tramvaji. Produkt a technika si tu pomáhají — dát do copy („ranní
  check-in v tramvaji“).
- Android: Foreground service s notifikací „MIMO hledá mimozemšťany v okolí“ — nutné pro BLE scan
  na pozadí od Androidu 12+. Uživatel ho vidí, to je v pořádku a čestné.
- Flutter: `flutter_blue_plus` (scan) + nativní kanál pro advertising (CoreBluetooth /
  `BluetoothLeAdvertiser`) — advertising v pluginech je slabší, počítat s vlastním platformovým kódem.
- Baterie: scan duty-cycle 10 s / 60 s; během `automotive` aktivity zhustit na 10 s / 30 s.

### Vrstva C — „Přistávací plocha“ (beacony v partnerských podnicích) → B2B napojení

- Partner (bar U Chřestýše, kavárna, coworking, knihovna, škola) dostane **iBeacon/Eddystone**
  s UUID MIMO + `major/minor = place_id`. Beacon ~400 Kč, nebo QR na stole jako fallback.
- Telefon beacon zachytí **lokálně** → označí dnešní návštěvu místa `partner:*` bez GPS
  (iOS region monitoring pro iBeacon funguje i na pozadí a je to Apple-posvěcený způsob).
- Volitelný **check-in**: uživatel klepne „jsem tady“ → server dostane `(user, place_id, hour_bucket)`;
  jen na 6 hodin; ostatní přítomní v podniku se zobrazí jako „planety v místnosti“ (opět k ≥ 5,
  jinak jen „slabý signál“).
- B2B model: podnik platí za „Přistávací plochu“ (branding místa v appce, event večery, statistika
  *počtu* návštěv MIMO uživatelů — nikdy identity). Navazuje na sekci 5.6 hlavního plánu.

---

## 2. Co z toho pokrývá původní seznam

| Případ | Vrstva A | Vrstva B | Vrstva C |
|---|---|---|---|
| 1. Čekáme na stejné zastávce | ✅ sdílená `stop:*` | ✅ kontakt typu „zastávka“ | — |
| 2. Jezdíme stejnou tramvají | ✅ sdílená `route:*` (slabé) | ✅ kontakt typu „vozidlo“ (silné — stejný spoj!) | — |
| 3. Chodíme do stejného podniku | ✅ sdílená `poi:*` | ✅ kontakt typu „budova“ | ✅ beacon + check-in |
| 4. Stejná škola / kancelářská budova | ✅ sdílená `edu:*` / `office:*` | ✅ kontakt typu „budova“ | ✅ beacon (partner) |
| 5. Další (viz níže) | | | |

### 5. Další, co jde stejným aparátem
- **Stejný vlak / autobus / letadlo** (vrstva B, kontakt ≥ 30 min v pohybu).
- **Stejný koncert / festival / zápas** — event token: `event:*` z katalogu (vrstva A, dočasný,
  platí 48 h) + beacon/QR na místě (vrstva C). Silný růstový kanál: QR na vstupence/pódiu.
- **Stejné kino, stejná projekce** — kontakt ≥ 90 min, stacionární, večer (vrstva B); pozor na
  k-anonymitu v malých sálech → zobrazit až po 24 h a jen jako „kino“.
- **Stejná posilovna / lezecká stěna / bazén / psí louka / běžecký okruh** (A + B).
- **Stejná čekárna** (úřad, lékař) — raději **ne**; explicitně vyloučit `amenity=hospital|clinic|doctors`
  z katalogu, citlivé místo.
- **Stejná ulice bydliště — nikdy.** Katalog nesmí obsahovat residenční adresy; `building=residential`
  vyloučit. Zastávka u domu je OK (veřejné místo).

---

## 3. Vizualizace ve „vesmíru“ (konzistentní s radarem z hlavního plánu)

- Radar = hvězdná mapa planet (lidé). Tento plán přidává **hvězdy** (místa) a **souhvězdí**
  (skupina lidí sdílející hvězdu).
- Moje hvězdy jsou vždy vidět. Cizí planeta se k mé hvězdě přikreslí jen tehdy, když prošla
  maticí nálady **a** hvězda má k ≥ 5 členů.
- Průlet (vrstva B) = **kometa** mezi dvěma planetami s popiskem jen typem: „tramvaj“, „zastávka“,
  „podnik“. Bez času, bez místa. Po matchi lze volitelně odhalit *název* zastávky/linky, pokud oba
  mají dané místo i ve vrstvě A (jinak se název nezná — telefon ho totiž nezná ani sám).
- Žádná mapa s lidmi. Mapa existuje jen při výběru míst a nikdy na ní nejsou cizí uživatelé.

---

## 4. Datový model (přírůstek k hlavnímu plánu)

```
places            (place_id PK, kind, name, lat, lon, region, source, partner_id NULL)   -- katalog, veřejný
profile_places    (user_id, place_id, added_at)                                           -- vrstva A
place_counts      (place_id, region, active_count, computed_at)                           -- materializace pro k≥5
tek_uploads       (user_id, day, tek BYTEA, region)                                       -- vrstva B, TTL 14 d
encounters        (id, user_a, user_b, kind, day, a_waved, b_waved, created_at)           -- vrstva B, TTL 14 d (den, ne čas!)
venue_checkins    (user_id, place_id, hour_bucket, expires_at)                            -- vrstva C, TTL 6 h
partners          (partner_id, place_id, beacon_major, beacon_minor, plan, since)
```

- `lat, lon` jsou **jen u míst v katalogu** (veřejná data OSM/GTFS), nikdy u uživatelů.
- `encounters.day` je den, ne timestamp. Žádná tabulka nemá historii pohybu.
- Všechny TTL vymáhá `pg_cron`/job, ne aplikační dobrá vůle; test na expiraci v CI.
- Export dat (GDPR) = obsah těchto tabulek pro `user_id` — je krátký a srozumitelný, což je featura.

---

## 5. Hrozby a opatření

| Hrozba | Opatření |
|---|---|
| Stalker vyloučením („jediný GenX na mé zastávce“) | k ≥ 5 na zobrazení souhvězdí; nikdy nezobrazit filtrované počty; ranking bonus se nepropisuje do UI |
| Stalker přes Průlet („jel se mnou, teď ho najdu“) | Průlet se zobrazí jen když **obě** strany nahrály TEK, oba projdou maticí a oba zamávají; zpoždění min. do dalšího dne (TEK za včerejšek); nikdy čas ani místo |
| Živé sledování přes BLE (fingerprinting) | RPI rotuje à 15 min a rotuje spolu s BLE MAC adresou (OS to dělá); TEK dnešní nikdy neopouští telefon |
| Operátor serveru (Ol1n) se dozví, kde kdo je | Server vidí jen: vybraná místa (jako tagy), pár „X a Y spolu byli včera“, volitelný check-in u partnera na 6 h. Souřadnice uživatelů v systému **neexistují**, nelze je uniknout ani vydat |
| Korelace více souhvězdí → identifikace (zastávka + škola + bar) | limit 8 míst; souhvězdí se jiným ukazují jen po jednom sdíleném místě, nikdy celý seznam; cizí seznam míst není nikdy vidět před matchem |
| Falešný beacon (někdo si postaví „U Chřestýše“ doma) | beacon UUID + rotující token z partnerského backendu (Eddystone-EID), nebo check-in platí jen s QR s denním kódem |
| Replay nahraných TEK | TEK podepsán klientem, přijímán jen pro `day = yesterday`, jeden na den a uživatele |
| Nezletilí (školy!) | katalog `edu:*` obsahuje **jen VŠ a VOŠ**; střední a základní školy do katalogu nejdou; obecné pravidlo 18+ z hlavního plánu |

---

## 6. Oprávnění, právo, store

- **iOS**: *Poloha jen při používání* (pro mapu výběru a lokální geofence) — nikdy „Vždy“. Bluetooth
  (`NSBluetoothAlwaysUsageDescription`). Core Motion pro klasifikaci pohybu. Beacony přes
  `CLBeaconRegion` (region monitoring je pozadí-přátelský).
  App Privacy nutrition label: *Location — not collected* (pravdivě: neopouští zařízení);
  *Contacts/Identifiers — none*. Uvést „Bluetooth proximity, not linked to location“.
- **Android**: `ACCESS_FINE_LOCATION` je od Androidu 12 pro BLE scan **nepotřebné** díky
  `BLUETOOTH_SCAN` s `neverForLocation` — použít, ať se v Data safety nemusí hlásit poloha.
  Foreground service typu `connectedDevice`. Geofencing API jen lokálně.
- **Web**: pouze vrstva A (výběr z katalogu). Žádné Geolocation API — ani pro centrování
  (prohlížečový prompt na polohu kazí důvěru; mapa se centruje podle ručně zvoleného regionu).
- **GDPR**: vybraná místa = osobní údaj (ne zvláštní kategorie), zpracování na základě souhlasu,
  oddělený toggle pro vrstvu A, B, C. Doplnit DPIA z hlavního plánu o vrstvu B (síť kontaktů je
  citlivá, i bez polohy). GTFS data PID: licence CC BY 4.0 — uvést atribuci. OSM: ODbL — atribuce
  a share-alike platí pro odvozenou databázi katalogu míst (katalog zveřejnit jako open data, což
  je v souladu s Ol1novou open-source linkou).

---

## 7. Fáze (zapadá mezi fáze hlavního plánu)

| Fáze | Co | Kdy |
|---|---|---|
| **G1 — Katalog + vrstva A** | import GTFS PID + OSM POI/edu/office pro Prahu, `places` tabulka, výběr na mapě/hledáním, `profile_places`, souhvězdí v radaru, k≥5 | v rámci fáze 2–3 hlavního plánu (+1 týden) |
| **G2 — Vrstva C** | iBeacon detekce, check-in, první partner U Chřestýše, admin pro partnery | po betě (fáze 4), +1 týden |
| **G3 — Vrstva B** | BLE protokol (TEK/RPI), lokální klasifikace kontaktů, upload/download TEK, Průlet v radaru, baterie | po launchi, +3 týdny; nejdřív Android, pak iOS popředí, iOS pozadí jako „best effort“ |
| **G4 — Rozšíření katalogu** | další kraje (IDS JMK, IDSOK…), eventy, partnerský self-service | průběžně |

Testování soukromí (přidat do Definition of done):
- Proxy/MITM test: v žádném requestu z appky se nevyskytuje `lat`/`lon`/geohash/čas kontaktu (grep na CI nad zachycenými payloady z integračních testů).
- Audit DB: žádný sloupec se souřadnicí mimo `places`.
- Test k-anonymity: místo se 4 členy se nikdy nezobrazí jako souhvězdí.
- Test TTL: po 14 dnech `encounters`/`tek_uploads` prázdné.

---

## 8. Otevřené otázky pro Ol1na

1. Praha only v G1, nebo rovnou všechny kraje s GTFS? (Praha stačí pro betu; katalog ostatních IDS je ruční práce.)
2. Je vrstva B pro MVP, nebo ji necháme jako „velkou featuru 2.0“? Je technicky nejtěžší (iOS pozadí) a zároveň nejvíc „mimozemská“.
3. Partnerské beacony dávat zdarma prvním 20 podnikům výměnou za QR na stolech?
4. Limit 8 míst — nebo méně (5), aby se korelace ještě ztížila?
5. Má se po matchi odhalovat název sdíleného místa automaticky, nebo až na explicitní „ukaž mu, kde se potkáváme“ sticker?
