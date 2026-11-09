#!/usr/bin/env bash
# Deploy alienmatch-api to JODA: cross-compile here, rsync deploy/joda, compose up.
#   deploy/joda/deploy.sh [ssh-host]      (default: joda)
# deploy/joda/.env must already exist on JODA; it is never copied from here.
set -euo pipefail
host=${1:-joda}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../.." && pwd)
dest=deploy/AlienMatch/deploy/joda
version=$(git -C "$repo" describe --tags --always --dirty 2>/dev/null || echo dev)

echo "==> build alienmatch-api $version (linux/amd64)"
mkdir -p "$here/bin"
(cd "$repo/backend" && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o "$here/bin/alienmatch-api" ./cmd/alienmatch-api)

echo "==> sync to $host:$dest"
ssh "$host" "mkdir -p $dest"
rsync -a --exclude .env --exclude data "$here/" "$host:$dest/"

ssh "$host" bash -s -- "$dest" "$version" <<'REMOTE'
set -euo pipefail
cd "$1"
[ -f .env ] || { echo "missing $1/.env: cp .env.example .env, fill it in, chmod 600" >&2; exit 1; }
chmod 600 .env
mkdir -p data/postgres data/media
docker compose up -d --build
for _ in $(seq 1 30); do
    if docker compose exec -T api alienmatch-api healthcheck 2>/dev/null; then ok=1; break; fi
    sleep 2
done
[ -n "${ok:-}" ] || { docker compose logs --tail 50 api >&2; exit 1; }
mkdir -p ~/deploy
printf '{"at":"%s","project":"AlienMatch","service":"alienmatch-api","version":"%s"}\n' "$(date -u +%FT%TZ)" "$2" >> ~/deploy/events.jsonl
echo "==> healthy"
REMOTE
