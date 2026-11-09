# Plán: vyhodnocení check-inu na L40S (varianta k SPARKu)

Stav 2026-11-09: **jen plán, nic nespuštěno.** Fakta od session L40S, co nevíme, je označeno.

## Dnes (SPARK, na vyžádání)

Backend na JODĚ při otevření check-inu požádá broker (`POST /v1/jobs`, lease `asr`+`vl`, projekt
`alienmatch`, priorita 20, preemptible). Nahrávka, která přijde dřív, než modely naběhnou, čeká jen
v paměti (max 15 min, max 24 MB). Skóre se dopočítá a stav nálady přepočítá. Lease se uvolní po
10 min bez check-inu. Kód: `backend/internal/sparklease`, `service.ProcessPending`.

## Co L40S umí (od session L40S)

- vLLM 0.32.0 s OpenAI API; L40S 46 GB, VM 8 vCPU, 23 GB RAM; profily přes `50_vllm/switch.sh`.
- Qwen2.5-VL-7B je v cache (bf16 ~16 GB); chat s obrázky ověřen na Qwen3-VL, na 2.5-VL bez fine-tune ne.
- Whisper large-v3-turbo jako faster-whisper s `/v1/audio/transcriptions` (:8001), ~3–4 GB.
- Oba se vejdou (~20–25 GB) jen jako **dedikovaný profil**; GPU je sdílené (qctl, výplň UC12).
- Studený start profilu desítky sekund až minuty (neměřeno pro tuto dvojici).

## Blokery (rozhodnutí Olina a Directora)

1. **Síť:** VM je jen za OpenVPN (WAN jen UDP 1194 a SSH z domácí IP). JODA se tam dnes nedostane.
   Možnosti: (a) Cloudflare Tunnel z VM + Cloudflare Access service token pro backend; (b) JODA
   jako OpenVPN klient. (a) je jednodušší a nemění síť VM, jen přidá odchozí tunel.
2. **GDPR (čl. 9):** hlas a obličej betatesterů. Fyzická lokace VM a podmínky T-Mobile sandboxu
   (logy, přístup operátora) **nevíme**. Pravidlo Olina: „jen vlastní data“ — data betatesterů
   musí Olin výslovně schválit, jinak L40S nepřichází v úvahu. Marketing slibuje zpracování na
   vlastních serverech v Česku.
3. **Životnost:** sandbox žije ~1 měsíc (od října) → pro betu nespolehlivý; nanejvýš záloha.
4. **Sdílení GPU:** trvalý profil pro AlienMatch by chtěl dohodu s Directorem.

## Pokud ano: kroky

1. Profil `alienmatch` na L40S: vLLM Qwen2.5-VL-7B (`--served-model-name vl`) + faster-whisper
   (`asr`), za jedním OpenAI kompatibilním endpointem (LiteLLM nebo Caddy). Ověřit chat s obrázky na 2.5-VL.
2. Cloudflare Tunnel z VM s hostname `alienmatch-gpu.ol1n.com` za Cloudflare Access; service token
   jen pro JODA backend.
3. Backend: `ALIENMATCH_GATEWAY_URL=https://alienmatch-gpu.ol1n.com` + hlavičky Access
   (rozšířit `moodscore.Gateway` o `CF-Access-Client-Id/Secret`). Broker (`ALIENMATCH_BROKER_URL`)
   nechat prázdný → modely „vždy zapnuté“, nebo přidat druhou implementaci `service.Lease`
   nad `switch.sh`/qctl, pokud má profil naběhnout na vyžádání.
4. Fallback: když L40S neodpovídá, backend už dnes padá na vlastní hodnocení uživatele.
5. Před ostrým provozem: DPIA doplnit o zpracovatele (T-Mobile), privacy page upravit.

**Doporučení:** zůstat na SPARKu (vlastní HW v Česku, broker už hotový) a L40S nechat jako
vývojovou/zátěžovou zálohu bez dat betatesterů.
