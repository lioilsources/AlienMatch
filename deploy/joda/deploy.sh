#!/usr/bin/env bash
# Deploy AlienMatch to JODA (aliens.ol1n.com): API binary + Flutter web built
# here, only deploy/joda is synced. Idempotent: .env secrets, the Cloudflare
# tunnel and its DNS record are created on the first run, on JODA, and never
# leave it.
#   deploy/joda/deploy.sh [ssh-host]      (default: joda)
set -euo pipefail
host=${1:-joda}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../.." && pwd)
dest=deploy/AlienMatch/deploy/joda
public=aliens.ol1n.com
version=$(git -C "$repo" describe --tags --always --dirty 2>/dev/null || echo dev)

echo "==> build alienmatch-api $version (linux/amd64)"
mkdir -p "$here/bin"
(cd "$repo/backend" && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o "$here/bin/alienmatch-api" ./cmd/alienmatch-api)

echo "==> build web app for https://$public"
(cd "$repo/app" && flutter build web --release --dart-define=API_BASE_URL="https://$public" >/dev/null)
rsync -a --delete "$repo/app/build/web/" "$here/web/"

echo "==> sync to $host:$dest"
ssh "$host" "mkdir -p $dest"
rsync -a --delete --exclude .env --exclude data --exclude 'cloudflared/*.json' --exclude cloudflared/config.yml "$here/" "$host:$dest/"

ssh "$host" PUBLIC="$public" VERSION="$version" bash -s -- "$dest" <<'REMOTE'
set -euo pipefail
cd "$1"
if [ ! -f .env ]; then
  # First run: random secrets, generated here and never printed.
  lan=$(hostname -I | tr ' ' '\n' | grep -m1 '^192\.168\.' || echo 127.0.0.1)
  sed -e "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 24)/" \
      -e "s/^ALIENMATCH_ADMIN_TOKEN=.*/ALIENMATCH_ADMIN_TOKEN=$(openssl rand -hex 24)/" \
      -e "s/^ADMIN_BIND=.*/ADMIN_BIND=$lan/" .env.example > .env
  echo "created .env (secrets stay on this host)"
fi
chmod 600 .env
mkdir -p data/postgres data/media

if [ ! -f cloudflared/config.yml ]; then
  # --config /dev/null: never fall back to ~/.cloudflared/config.yml (another tunnel).
  cf() { cloudflared tunnel --config /dev/null --origincert ~/.cloudflared/cert.pem "$@"; }
  tunnel_id() { cf list -o json 2>/dev/null | python3 -c 'import sys,json;print(next((t["id"] for t in json.load(sys.stdin) if t["name"]=="alienmatch"),""))'; }
  ID=$(tunnel_id)
  [ -n "$ID" ] || { cf create alienmatch >/dev/null 2>&1; ID=$(tunnel_id); }
  [ -n "$ID" ] || { echo "tunnel alienmatch not created" >&2; exit 1; }
  install -m 644 ~/.cloudflared/"$ID".json cloudflared/"$ID".json
  sed "s/<TUNNEL-ID>/$ID/g" cloudflared/config.yml.example > cloudflared/config.yml
  cf route dns "$ID" "$PUBLIC" 2>&1 | tail -1 || true
  echo "tunnel alienmatch = $ID"
fi

docker compose up -d --build
ok=
for _ in $(seq 1 30); do
  if docker compose exec -T api alienmatch-api healthcheck 2>/dev/null; then ok=1; break; fi
  sleep 2
done
[ -n "$ok" ] || { docker compose logs --tail 50 api >&2; exit 1; }
mkdir -p ~/deploy
printf '{"at":"%s","project":"AlienMatch","service":"alienmatch","version":"%s","host":"%s"}\n' "$(date -u +%FT%TZ)" "$VERSION" "$PUBLIC" >> ~/deploy/events.jsonl
docker compose ps --format '{{.Name}} {{.Status}}'
REMOTE
echo "==> https://$public"
