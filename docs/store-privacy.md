# Odpovědi do formulářů: anonymní statistiky

Doplňky App Privacy (App Store Connect) a Data safety (Play Console) pro build
s anonymními statistikami (`docs/telemetry.md`, balíček `ol1n_telemetry`).
**Vyplnit před odesláním toho buildu** a až po zveřejnění nové
`docs/privacy.html`. Odpovídá `app/ios/Runner/PrivacyInfo.xcprivacy`.

Platí navíc k tomu, co appka deklaruje za účet (fotka, profil, nálada, viz
`docs/release.md`). To zůstává, jak je. Před vyplněním porovnej se stavem v
konzolích a aktuálním zněním formulářů.

## App Store Connect → App Privacy

**Do you or your third-party partners collect data from this app?** Yes
(už kvůli účtu).

Přidat přesně tyto řádky:

| Category → type | Linked to the user? | Used for tracking? | Purpose |
|---|---|---|---|
| Usage Data → **Product Interaction** | **No** | **No** | **Analytics** |
| Diagnostics → **Performance Data** | **No** | **No** | **Analytics** |
| Location → **Coarse Location** | **No** | **No** | **Analytics** |

Proč:

- *Product Interaction*: otevření appky, obrazovky a sekundy na nich, první
  použití funkce v relaci, výsledky kroků (účet, profil, fotka, zamávání,
  check-in, místa, smazání účtu), zobrazené chyby.
- *Performance Data*: zatím appka žádné časy načítání neměří (plán §10.5 je
  povoluje). Deklarace je ponechaná podle společné šablony, aby přidání časů
  nevyžadovalo změnu formuláře. Když ji chceš mít přesně, odškrtni ji a
  odstraň `NSPrivacyCollectedDataTypePerformanceData` z manifestu.
- *Coarse Location*: vlastní příjemce vývojáře odvodí z IP adresy připojení
  zemi, uloží jen zemi a IP neukládá. Když se země na příjemci vypne, řádek
  odškrtni a odstraň `NSPrivacyCollectedDataTypeCoarseLocation` z manifestu.
  Pozor: `docs/release.md` dnes říká „Location: not collected“; to už po
  zapnutí statistik neplatí.

**Linked to the user: No** u všech tří. Statistiky nejdou přes API appky,
nenesou token účtu, jeho otisk ani žádné ID a nic z profilu, zdí ani
check-inů; ID relace je náhodné, jen v paměti a nikdy se znovu nepoužije.
Data účtu (fotka, profil, nálada) se vyplňují zvlášť, jak dosud.

**Tracking: No.** Nic se nespojuje s daty jiných firem, žádná reklama, žádný
data broker. ATT dialog není potřeba (`NSPrivacyTracking` je `false`).

## Play Console → Data safety

Statistiky jdou jen na vlastní server vývojáře v EU (Česko), žádná třetí
strana je nedostane: **collected**, **not shared**.

- Is all user data encrypted in transit? **Yes** (klient odmítne host bez
  `https`).
- Do you provide a way for users to request deletion? Beze změny (účet jde
  smazat v appce). Statistiky nenesou identifikátor, takže k člověku nejdou
  dohledat; vypínač v nastavení smaže neodeslané záznamy v telefonu, na
  serveru se mažou po 12 měsících.

Přidat:

| Data type | Collected / shared | Ephemeral? | Required or optional | Purpose |
|---|---|---|---|---|
| App activity → **App interactions** | Collected, not shared | No | **Optional** (Nastavení → Anonymní statistiky) | **Analytics** |
| Location → **Approximate location** | Collected, not shared | No | **Optional** (týž vypínač) | **Analytics** |

Diagnostics (App info and performance) zatím neuvádět: appka žádné časy ani
pády neposílá. Pozor: `docs/release.md` dnes říká „poloha nesbírána“; po
zapnutí statistik se přidává *Approximate location* (jen země z IP, IP se
neukládá). Precise location dál **ne**.

## Mimo repo, ve všech jazycích

- App Store Connect → App Privacy (výše).
- Play Console → Data safety (výše).
- Stránka appky na olin.now (`olin.now/alienmatch`): dnes slibuje „bez
  analytiky“; přepsat na „bez analytiky třetích stran, anonymní statistiky
  nepropojené s účtem jdou vypnout“.
