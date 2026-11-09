# Nasazení backendu na JODU

Vzor jako PromoClown: binárka se kříženě zkompiluje na Macu, na JODU jde přes rsync jen `deploy/joda/`,
tam běží `docker compose` (API + vlastní Postgres 17). JODA nic nekompiluje.

## Poprvé (ručně na JODĚ)

1. `ssh joda`, `mkdir -p ~/deploy/AlienMatch/deploy/joda`, zkopíruj `deploy/joda/.env.example` jako `.env`
   a vyplň: `POSTGRES_PASSWORD` (náhodné), `ALIENMATCH_BIND` (LAN adresa JODY z privátních poznámek),
   `ALIENMATCH_ADMIN_TOKEN` (náhodný), volitelně `ALIENMATCH_WS_ORIGINS`. `chmod 600 .env`.
2. Port `8096` je v registru portů volný; zapiš ho do `~/.claude/shared/ports.md` (PR do DevConventions).

## Každé nasazení

```sh
deploy/joda/deploy.sh          # build linux/amd64 → rsync → compose up → healthcheck → ~/deploy/events.jsonl
```

Migrace se aplikují při startu API.

## Veřejný přístup (rozhodnutí Olina)

- Hostname pro API (návrh `api.alienmatch.ol1n.com`) přes existující Cloudflare Tunnel → Caddy → `ALIENMATCH_BIND:8096`.
- Caddy **nesmí** pouštět ven `/admin` a `/v1/admin/*` (jen LAN nebo Cloudflare Access).
- WebSocket `/v1/walls/{id}/ws` musí projít tunelem (Cloudflare WS podporuje).
- Limit těla požadavku v Caddy: 3 MB (check-in s médii má max ~4 MB s rezervou; API si limity hlídá samo).

## Appka

Release build potřebuje `--dart-define=API_BASE_URL=https://<hostname>` (doplnit do `release-*.yml`).
