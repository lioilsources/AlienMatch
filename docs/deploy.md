# Nasazení na JODU: aliens.ol1n.com

Běží od 2026-11-09. Na `https://aliens.ol1n.com` je webová verze appky (Flutter web) a pod `/v1` API.

| Kontejner | Co | Limit RAM |
|---|---|---|
| `alienmatch-db` | Postgres 17 (úsporné nastavení) | 192 MB |
| `alienmatch-api` | Go API, distroless | 128 MB |
| `alienmatch-caddy` | web + reverse proxy, `/admin` veřejně 404 | 64 MB |
| `alienmatch-cloudflared` | vlastní tunel `alienmatch` → Caddy | 96 MB |

Ven není publikovaný žádný port kromě moderátorské fronty na LAN adrese JODY (`ADMIN_BIND:8098`,
`http://<JODA-LAN>:8098/admin`, token je v `.env` na JODĚ jako `ALIENMATCH_ADMIN_TOKEN`).

## Nasazení

```sh
deploy/joda/deploy.sh          # API (linux/amd64) + web build na Macu → rsync → compose up → healthcheck
```

Idempotentní: při prvním běhu na JODĚ vzniknou `.env` s náhodnými hesly, Cloudflare tunel `alienmatch`
a DNS záznam `aliens.ol1n.com`. Nic z toho neopouští JODU. Migrace DB se aplikují při startu API.
Každé nasazení se zapíše do `~/deploy/events.jsonl`.

## Data

`~/deploy/AlienMatch/deploy/joda/data/{postgres,media}`. Až Olin založí ZFS dataset `pool/alienmatch`
(sudo), přesunout tam a přepojit volumes.

## Appka

Výchozí `API_BASE_URL` v appce je `https://aliens.ol1n.com`, release workflowy nic navíc nepotřebují.
Lokální vývoj: `--dart-define=API_BASE_URL=http://localhost:8080`.
