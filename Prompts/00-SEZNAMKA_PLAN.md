# SEZNAMKA_PLAN.md — „Seznamka pro Mimozemšťany“ (pracovní kódové jméno: MIMO)

> Handoff pro Opus / Claude Code Director. Cíl: nová appka + služba Ol1n. Postaveno výhradně na
> Ol1nově stacku a na třech existujících projektech: **MirrorBooth** (fotky), **HandWrittenStickers**
> (zprávy), **BiPolarMonitor** (matching podle nálady). Flutter appka (iOS / Android / web),
> Go backend na JODA, VL model na DGX Spark. Ad-free, bez trackingu, free s jasnou IAP politikou.

---

## 0. Proč „pro Mimozemšťany“ (produktová teze)

Všechny seznamky dělají totéž: texty, věk, filtry, swipe. MIMO dělá pravý opak a z toho dělá značku:

| Běžná seznamka | MIMO |
|---|---|
| Vyfocená, vyretušovaná selfie | **Symetrická „mimozemská“ tvář** z MirrorBooth — živě pořízená, nejde ukrást z Instagramu, nejde reverzně vyhledat |
| Text, bio, emoji | **Žádný psaný text.** Zprávy jsou **ručně psané stickers lepené na společnou zeď** |
| Věk jako číslo | Pouze **generační vlajka** (GenZ / Millennial / GenX / BabyBoomer) |
| Match podle vzhledu a filtrů | **Match podle nálady a její dynamiky** — kdo je nahoře a stoupá, může potkat jiného nahoře, nebo někoho dole povzbudit |
| Algoritmus optimalizovaný na engagement | Pravidlo **„nikdy nespojíme dva lidi v depresi“** — produkt chrání uživatele, ne retention |

Tagline kandidáti: *„Nikdo ti nerozumí? Tady taky ne. A je to krásný.“* / *„Seznamka beze slov.“*
Názvy k ověření (ochranné známky, store, domény): **Mimo**, **Ufonka**, **Antény**, **Mimozemšťani**.
Rozhodnout před fází 1; do té doby používat kódové jméno MIMO (`mimo.ol1n.com`).

---

## 1. Tři pilíře a co z existujících repozitářů přebrat

### 1.1 Fotky — MirrorBooth (`lioilsources/MirrorBooth`)
- Profilový obrázek vzniká **jen živým záběrem v appce** (přední kamera), nikdy z galerie.
  → přirozená verifikace proti catfishingu a zároveň privacy (symetrický obličej není biometricky
  shodný s reálným).
- Uživatel dostane 3 varianty: **L+L**, **R+R**, (volitelně originál jen pro sebe/ pro match po odemčení).
  Vybere, která varianta je „jeho mimozemšťan“ — ostatní se neukládají na server.
- Úkol pro Opus: vytáhnout z MirrorBooth modul do samostatného Dart balíčku
  `mirror_face` (detekce obličeje, osa symetrie, kompozice, export PNG/WebP). MirrorBooth ho pak
  konzumuje taky (jedna implementace, dva produkty).
- Server dostane už hotový obrázek (WebP, max 1024 px). Žádné raw snímky na serveru.

### 1.2 Zprávy — HandWrittenStickers (`lioilsources/HandWrittenStickers`)
- Každý match má **společnou zeď** (nekonečné plátno). Komunikace = **lepení ručně psaných stickers**.
- Dva způsoby vzniku stickeru:
  1. **Napsat prstem/stylusem rovnou v appce** → vektorizace tahů → sticker (rychlá cesta, default).
  2. **Vlastní „písmo mimozemšťana“** — jednorázové naskenování rukopisu (stávající `glyph_extractor`
     v Go) → uživatel pak může skládat stickers z vlastních glyfů i rychleji než psát.
- Stickers na zdi mají pozici, rotaci, měřítko, vrstvu. Lze je posouvat, přelepovat, odlepit vlastní.
  Reakce = malé obrázkové stickers (srdce, ufo, kafe…), opět beze slov.
- Žádné textové pole v celé appce (výjimka: onboarding/legal/support). Je to **produktové pravidlo**,
  ne technické omezení — chránit ho i v code review.
- Úkol pro Opus: `glyph_extractor` zabalit jako Go službu `stickers-svc` (HTTP), Flutter editor
  vytáhnout do balíčku `sticker_canvas` (zeď + lepení + realtime sync).

### 1.3 Matching — BiPolarMonitor (`lioilsources/BiPolarMonitor`)
- **Normativní dialog**: krátký denní check-in (10–20 s video + hlas), vždy stejné 2–3 výzvy
  („Řekni, jak ti dnes je.“ / „Co tě dnes čeká?“). Normativní = pokaždé stejný protokol, aby bylo
  možné srovnávat den po dni.
- Dvě nezávislá hodnocení:
  - **VL skóre** — VL model (Qwen2.5-VL / Qwen3-VL na Sparku přes vLLM + LiteLLM) dostane
    pár klíčových snímků + transkript (Whisper na Sparku) a vrátí strukturovaný JSON:
    `{energy: 0..1, valence: 0..1, confidence: 0..1}`.
  - **Self skóre** — uživatel po check-inu posune jednu grafickou škálu (obrázková, beze slov;
    od „šedé planety“ po „supernovu“).
- **Fúze**: `mood = w_self * self + w_vl * vl` (start `w_self = 0.6`, `w_vl = 0.4`; váhy
  per-uživatel kalibrovat podle shody v čase). Velký rozpor VL vs. self → appka se mírně zeptá
  znovu zítra, **nikdy uživatele nepřebíjí**.
- **Trend** = sklon přes posledních 3–5 check-inů (lineární regrese). Stav uživatele je dvojice
  `(level, trend)`:

```
level:  HIGH (≥0.66) | MID (0.33–0.66) | LOW (<0.33)
trend:  RISING (+) | FLAT (0) | FALLING (−)
```

- **Matchovací matice** (symetrická, řádek A × sloupec B):

| A \ B | HIGH↑ | HIGH→ | HIGH↓ | MID↑ | MID→/↓ | LOW (jakýkoli trend) |
|---|---|---|---|---|---|---|
| **HIGH↑** | ✅ **Match** | ✅ Match | ✅ Match | ✅ Match | ⚪ volitelně | 💛 **Povzbuzení** (A je maják) |
| **HIGH→** | ✅ | ✅ | ⚪ | ⚪ | ⚪ | 💛 Povzbuzení |
| **HIGH↓** | ✅ | ⚪ | ❌ | ⚪ | ❌ | ❌ |
| **MID↑** | ✅ | ⚪ | ⚪ | ⚪ | ❌ | ❌ |
| **MID→/↓** | ⚪ | ⚪ | ❌ | ❌ | ❌ | ❌ |
| **LOW** | 💛 (B je maják) | 💛 | ❌ | ❌ | ❌ | ❌ **NIKDY** |

  - ✅ Match = oboustranný romantický/přátelský match podle intent-stickerů.
  - 💛 Povzbuzení = **asymetrický, nerománský režim**: uživatel LOW musí mít **explicitně zapnuto**
    „chci, aby mě někdo povzbudil“, uživatel HIGH↑ musí mít zapnuto „můžu být maják“. Zeď
    v tomto režimu je oboustranně viditelná, ale intent-stickers (flirt/sex) jsou vypnuté,
    jen „pokec / kafe / čaj“. Po zlepšení LOW uživatele se vztah může plynule překlopit v běžný match.
  - ❌ LOW × LOW = tvrdé pravidlo v kódu, nikoli nastavení. Test na to psát jako první.
  - ⚪ = zapnout až po datech (A/B), v MVP neaktivní.
- **Čerstvost**: do matchingu vstupuje jen stav mladší než 36 h. Bez check-inu uživatel
  „mizí z radaru“ (jemná motivace k dennímu check-inu, bez notifikačního spamu — max 1 denně).

#### 1.3.1 Bezpečnostní a etické mantinely (nepřeskakovat)
- Appka **nic nediagnostikuje**. Slovník v UI: „nálada / energie / signál“, nikdy „deprese“,
  „bipolární“, „porucha“. Interní název BiPolarMonitor se do produktu nepropisuje.
- Při opakovaném LOW (≥ 5 dní) + nízké valenci: jemná karta s kontaktem na pomoc
  (CZ: Linka první psychické pomoci 116 123; lokalizovat podle země) a **romantický matching se
  pozastaví**, povzbuzení zůstává k dispozici (pokud ho uživatel chce).
- VL skóre není rozhodující, je poradní. Uživatel kdykoli může VL hodnocení vypnout a jet jen
  na self-skóre (pak je jeho profil označen „bez signálu“, ale funguje).
- **Žádné video/audio se neukládá.** Server uchovává jen skóre, trend a timestampy. Check-in se
  zpracuje na Sparku a payload se maže.
- GDPR: nálada odvozená z obličeje/hlasu = **zvláštní kategorie** (čl. 9). Nutný **explicitní,
  oddělený souhlas** v onboardingu, export + smazání dat na jedno kliknutí, DPIA sepsat před launchem.
  On-prem zpracování (Spark/JODA, bez třetích stran) je tady konkurenční výhoda — napsat to do
  marketingu srozumitelně.

---

## 2. Profil (vše obrázkové, beze slov)

| Pole | Hodnoty | Poznámka |
|---|---|---|
| Fotka | 1× MirrorBooth varianta (L+L nebo R+R) | povinné, živě pořízené |
| Generace | GenZ / Millennial / GenX / BabyBoomer | ikony planet; **bez čísla věku**; + povinné potvrzení 18+ (vyžadují store) |
| Status | single / ženáč–vdaná / rozvedený–á / „je to složité“ | ikony |
| Děti | počet 0–5+, kluci/holky, dvojčata/trojčata flag | ikonová mřížka, volitelné |
| Intent stickers | flirt, sex, pokec, kafe, pivo, víno, čaj, procházka, hraní | multi-select; vlastní ilustrace (ComfyUI pipeline, jeden výtvarný styl) |
| Hledám | generace (multi), status (multi) | opět ikony |
| Signál | aktuální `(level, trend)` jako **vizuální aura kolem fotky** | nikdy číslo; barva + pulz |
| Režim | „můžu být maják“ / „chci povzbudit“ | přepínače, default vypnuto |

Jméno: jen **přezdívka** (jediný text, max 12 znaků, moderovaná) nebo nic — defaultně
generovaná „mimozemská“ přezdívka (např. „Zq-7“).

---

## 3. Toky

1. **Onboarding** (≤ 90 s): souhlasy → živý MirrorBooth záběr → výběr varianty → generace +
   status + děti + intent stickers → první check-in → hotovo.
2. **Radar** (hlavní obrazovka): ne swipe, ale **hvězdná mapa** — profily, které matice pustí,
   jsou vidět jako planety; velikost/jas = síla signálu. Tap → detail. „Zamávat“ = poslat
   úvodní sticker (předpřipravený obrázkový, nebo vlastní ručně psaný).
3. **Match** → vznikne zeď. Oba vidí, kdo komu zamával, až když je to oboustranné.
4. **Zeď**: realtime (WebSocket), offline-first (fronta stickerů), přelepování, reakce.
5. **Denní check-in**: push 1× denně v uživatelem vybraný čas; bez check-inu po 36 h profil zešedne.
6. **Povzbuzení**: speciální zeď s jemnějším vizuálem; po návratu LOW uživatele do MID/HIGH appka
   nabídne oběma překlopení v běžný match (oboustranný souhlas).
7. **Bezpečnost**: report / block ze zdi i profilu; stickers s nahotou/nenávistí filtruje VL model
   před doručením (asynchronně, ≤ 2 s), sporné do fronty pro ruční review (admin web).

---

## 4. Architektura (Ol1n stack)

```
Flutter app (iOS / Android / Web)            Admin web (Flutter web, interní)
   │  REST + WebSocket (JSON)                        │
   ▼                                                 ▼
Caddy ← Cloudflare Tunnel  (mimo.ol1n.com, api.mimo.ol1n.com)
   │
   ├── mimo-api        Go · sqlc · golang-migrate · Postgres   (profily, matching, zeď, IAP)
   ├── mimo-realtime   Go · WebSocket hub (zeď, přítomnost)    (může být v mimo-api, oddělit až při zátěži)
   ├── stickers-svc    Go · glyph_extractor (HandWrittenStickers)
   ├── media           MinIO (S3) na JODA — fotky profilů, stickers (WebP/SVG)
   ├── jobs            NATS JetStream nebo Postgres queue (check-in, moderace, notifikace)
   └── push            FCM + APNs (Go, vlastní, bez Firebase SDK v appce kvůli no-tracking)
                                  │
                                  ▼  (jobs → inference)
DGX Spark
   ├── vLLM: Qwen2.5-VL-7B/32B (mood scoring, moderace stickers)   přes LiteLLM gateway
   ├── Whisper (ASR check-inu)                                     (faster-whisper / vLLM)
   └── mood-worker  Python (převzít z BiPolarMonitor FastAPI; OpenFace nahradit VL, OpenFace nechat jako fallback featury)
```

- **Repo**: nový monorepo `lioilsources/Mimo` (`app/`, `backend/`, `workers/`, `infra/`, `design/`).
  Sdílené Dart balíčky `mirror_face`, `sticker_canvas` v `packages/` s plánem vyčlenit do
  vlastních repozitářů, až je bude konzumovat i MirrorBooth/HandWrittenStickers.
- **DB** (hlavní tabulky): `users`, `profiles`, `profile_tags`, `checkins` (jen skóre),
  `mood_state` (materializovaný `(level, trend, computed_at)`), `waves`, `matches`,
  `walls`, `stickers`, `reports`, `entitlements`, `iap_receipts`.
- **Matching job**: každých 10 min přepočet `mood_state`, kandidáti = průnik
  (matice × hledám × generace × status × vzdálenost hrubá — okres/kraj, ne GPS přesně).
- **Privacy by design**: žádné SDK třetích stran pro analytiku; vlastní minimální metriky
  (počet aktivních, check-inů, matchů) do Postgresu; odpovídá Ol1nově „ad-free, no tracking“.
- **Web verze**: Flutter web pro profil + zeď (ručně psané stickers přes myš/touch fungují),
  check-in jen v mobilní appce (kamera + mikrofon konzistentně). Web je i SEO landing.

---

## 5. Monetizace (rozvedeno)

Zásada: **free jádro je plnohodnotné** (profil, radar, match, zeď, check-in). Platí se za
„víc, dřív, krásněji“ — nikdy za bezpečnost ani za základní komunikaci. Žádné reklamy,
žádný prodej dat. Vše přes store IAP (povinné pro dating kategorii).

### 5.1 Předplatné „Signál+“ (hlavní zdroj)
- Cena: ~129 Kč / měsíc, ~790 Kč / rok (store tier ~ $4.99 / $29.99). Zkušební 7 dní.
- Obsah:
  - **Dosah**: neomezená zamávání (free: 5/den), radar přes víc krajů/zemí („Teleport“).
  - **Kdo mi mával** — vidět příchozí zamávání před matchem.
  - **Vrátit odlepený sticker / zpět poslední krok**.
  - **Můj signál** — vlastní historie nálady, trend, kalendář (hodnota z BiPolarMonitor
    pro uživatele samotného; formulovat jako „deník energie“, ne zdravotní funkce).
  - **Prémiové aury** a animované pozadí zdi.
- Proč funguje: dating subscription je standard, uživatelé to chápou; „Můj signál“ je unikátní
  retention háček, který konkurence nemá.

### 5.2 Sticker packy (jednorázové, nespotřebitelné)
- Tematické balíčky obrázkových stickers (kafe/víno/vesmír/zvířata…), **ručně psané cursive presety**
  (navazuje na Ol1nův záměr krásných presetů vázaného písma v HandWrittenStickers) — 49–99 Kč.
- **„Můj rukopis“ pack**: jednorázový scan rukopisu → vlastní glyfová sada (spotřebuje GPU na
  Sparku, proto placené, ~149 Kč). Výrazný diferenciátor.
- Cross-sell: stejné packy jdou prodávat i v HandWrittenStickers.

### 5.3 Dárkové stickers (spotřebitelné)
- Prémiový sticker poslaný na zeď druhého (obdoba Super Like, ale hmatatelná a vtipná):
  „Teleportuju ti kafe“, „Raketa“, 29–59 Kč / kus nebo balíček 5 ks.
- Účtovat jen odesílateli; příjemce dárek vidí jako výrazný sticker.

### 5.4 „Světlice“ (boost, spotřebitelný)
- Profil na 30 min svítí na radaru jako nejjasnější planeta v regionu. 59 Kč, 3 ks za 129 Kč.
- Pouze pro uživatele ve stavu MID/HIGH (nikdy neprodávat boost někomu v LOW — etika a brand).

### 5.5 Ol1n Pass (integrace)
- MIMO vstupuje do **Ol1n Pass ($49)**: Pass odemyká Signál+ natrvalo + všechny sticker packy
  (ne spotřebitelné dárky a světlice). Zapsat do PASS_PLAN.md jako první appku s předplatným
  — rozhodnout, zda Pass kryje předplatné „navždy“ nebo jen jednorázové obsahy (návrh: kryje
  Signál+ **lifetime**, protože ekonomicky Pass míří na superfanoušky a jde o malou kohortu).

### 5.6 B2B / licence (navazuje na olin.now/business)
- **White-label „seznamka beze slov“** pro komunity/eventy (festivaly, kongresy, univerzity,
  firmy jako teambuilding): vlastní branding, uzavřený radar jen pro účastníky, časově omezený.
  Cena za event 15–50 tis. Kč + provoz.
- **Mood matching engine jako API** (anonymizované `(level, trend)` + matice) pro jiné appky
  (komunitní, mentoring, buddy programy) — licence měsíčně. Běží na Ol1nově on-prem infrastruktuře,
  prodejní argument = data neopouštějí EU/CZ.
- **„Zeď“ jako komponenta** (sticker canvas + realtime) pro školy, kavárny, agentury.

### 5.7 Offline „Přistání“ (později)
- Placené lokální meetupy pro matchnuté i nematchnuté uživatele v daném městě (ticket 150–300 Kč,
  partnerský podnik — první kandidát bar U Chřestýše). Marketingově silné, ale operativně náročné,
  až po PMF.

### 5.8 Co nedělat
- Reklamy, prodej/sdílení dat, platba za „ověření profilu“ (ověření je díky MirrorBooth zdarma pro
  všechny), platba za blokování/report, platba za odemknutí povzbuzení, dark patterns ve zrušení předplatného.

### 5.9 Odhad jednotkové ekonomiky (hrubý, k revizi s daty)
- Náklady na uživatele: 1 check-in/den ≈ 3–6 s GPU na Sparku (VL + Whisper) → při 10k DAU
  ≈ 10–17 GPU-hodin denně, Spark to utáhne zhruba do ~15–20k DAU, pak škálovat (druhý Spark /
  T-Mobile L40S / CRA). Push, storage, Postgres na JODA zanedbatelné do ~50k uživatelů.
- Konverze na Signál+ u dating appek 3–8 %; při 10k MAU a 5 % × 129 Kč ≈ 65 tis. Kč/měs. brutto
  před store poplatkem (15 % do $1M ročně na obou platformách přes small-business programy).
- Cíl prvního roku: pokrýt náklady + ověřit, že „Můj signál“ zvedá retenci 30. dne nad 20 %.

---

## 6. Store & právní checklist
- Kategorie Dating → Apple 17+, Google „Dating“ s vyplněným Content rating. Vyžadováno:
  potvrzení 18+ (bez zadání věku je OK, ale checkbox musí být), moderace obsahu, report/block,
  smazání účtu v appce, zásady ochrany soukromí (zvláštní kategorie dat explicitně).
- Developer name **„Ol1n“** na obou storech (Apple jméno zatím dořešit — viz profil).
- Ochranná známka názvu + doména před launchem; `.ol1n.com` subdoména stačí pro beta.
- DPIA + záznam o činnostech zpracování (GDPR) před veřejnou betou.

---

## 7. Fáze a milníky

| Fáze | Výstup | Odhad |
|---|---|---|
| **0 — Rozhodnutí** | název, VL model (7B vs 32B benchmark na 50 testovacích check-inech), rozsah MVP | 1 týden |
| **1 — Balíčky** | `mirror_face`, `sticker_canvas` vyčleněné a otestované; `stickers-svc` běží na JODA | 2 týdny |
| **2 — Backend jádro** | mimo-api (auth magic-link/Apple/Google bez trackingu, profily, tagy, media), migrace, sqlc; mood-worker na Sparku vrací JSON skóre; matching job + **testy matice (LOW×LOW nikdy)** | 3 týdny |
| **3 — Appka MVP** | onboarding, radar, check-in, match, zeď realtime, report/block, smazání účtu | 4 týdny |
| **4 — Beta** | TestFlight + Play internal; 30–50 lidí (Ol1nův Discord), ladění vah `w_self/w_vl`, moderace | 3 týdny |
| **5 — Monetizace** | Signál+, sticker packy, světlice, Ol1n Pass entitlementy, RevenueCat-free vlastní ověření receiptů v Go | 2 týdny |
| **6 — Launch** | web landing `mimo.ol1n.com`, store listing (ikonové, beze slov i v marketingu), TikTok/YouTube klipy „zeď v akci“ | 2 týdny |

Celkem ~17 týdnů jedním vývojářem s Claude Code; Director rozdělí fáze 1–3 na paralelní
sub-sessions (`packages`, `backend`, `app`) přes agent hub.

---

## 8. Otevřené otázky pro Ol1na (zodpovědět před fází 1)
1. Název a doména (Mimo / Ufonka / Antény / jiné)?
2. Má být originální (nesymetrická) fotka vůbec kdy odemknutelná pro match, nebo princip „jen mimozemšťan“ platí navždy?
3. Check-in: video + hlas povinně, nebo i hlas-only / foto-only fallback pro stydlivé?
4. Povzbuzení: povolit i pro uživatele, kteří nehledají vztah (čistě „maják“ profily)? Zvedlo by to bezpečnou kohortu HIGH↑.
5. Geografie v MVP: jen CZ/SK, nebo rovnou EN lokalizace (stickers jsou jazykově neutrální — výhoda)?
6. Ol1n Pass: kryje Signál+ lifetime, nebo jen jednorázové packy?

---

## 9. Definition of done pro MVP
- Nový uživatel projde onboardingem za < 90 s bez napsání jediného slova (kromě přezdívky).
- Check-in → skóre do 5 s; žádné médium nezůstává na disku Sparku/JODA po zpracování (ověřit testem).
- Test suite matice prochází; LOW×LOW match není možné vytvořit ani ručně přes DB funkci.
- Zeď synchronizuje sticker mezi dvěma zařízeními do 500 ms na LAN, offline fronta funguje.
- Report → sticker skryt do 2 s, admin ho vidí ve frontě.
- Smazání účtu odstraní vše včetně médií v MinIO (ověřit skriptem).
- Store listing i UI bez tracking SDK; privacy manifest (Apple) a Data safety (Google) vyplněny „no data collected for tracking“.
