#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SOURCE_IP=${SOURCE_IP:-184.73.127.245}
SOURCE_USER=${SOURCE_USER:-ubuntu}
SOURCE_KEY=${SOURCE_KEY:-$HOME/.ssh/backup/overleaf.pem}
TARGET_IP=${TARGET_IP:-}
TARGET_USER=${TARGET_USER:-ubuntu}
TARGET_KEY=${TARGET_KEY:-$HOME/.ssh/new_github}
SERVICE_HOSTNAME=${SERVICE_HOSTNAME:-overleaf.safe.eu}
ARTIFACT_DIR=${ARTIFACT_DIR:-$ROOT_DIR/migration-artifacts}

usage() {
  cat <<'EOF'
Usage: TARGET_IP=x.x.x.x scripts/migrate_overleaf.sh COMMAND

Commands:
  preflight          Record source revision, sizes, services, and DB counts.
  sync-workspace     Copy /home/ubuntu, excluding machine credentials/caches.
  repair-lockfile    Regenerate the inconsistent npm lockfile on target.
  build              Repair the lockfile and build the copied Compose stack.
  configure-hostname Set OVERLEAF_SITE_URL for the destination hostname.
  start-http-test    Start a clean target stack for fake-account HTTP testing.
  stop-http-test     Stop the temporary target stack without deleting volumes.
  sync-data-online   Seed non-database volumes while source remains live.
  final-sync         Stop both stacks, copy volumes consistently, start target.
  validate           Validate revision, containers, DB counts, Redis, and HTTP.
  enable-target-tls  Configure target Caddy for the production hostname.
  proxy-source       Make old Caddy proxy HTTPS traffic to the target IP.
  rollback-proxy     Restore old Caddy and restart the old Compose stack.
EOF
}

[[ $# -eq 1 ]] || { usage; exit 2; }
COMMAND=$1

source_key_copy=""
cleanup_local() {
  [[ -z "$source_key_copy" ]] || rm -f "$source_key_copy"
}
trap cleanup_local EXIT

source_key_copy=$(mktemp /tmp/overleaf-source-key.XXXXXX)
install -m 0600 "$SOURCE_KEY" "$source_key_copy"

SSH_SOURCE=(ssh -F /dev/null -i "$source_key_copy" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$SOURCE_USER@$SOURCE_IP")
SSH_TARGET=(ssh -F /dev/null -i "$TARGET_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$TARGET_USER@$TARGET_IP")
SCP_TARGET=(scp -F /dev/null -i "$TARGET_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

need_target() {
  [[ -n "$TARGET_IP" ]] || { echo "TARGET_IP is required" >&2; exit 2; }
}

with_pull_key() {
  local mode=$1 tmp marker public_line
  need_target
  tmp=$(mktemp -d /tmp/overleaf-migration-key.XXXXXX)
  marker="overleaf-migration-$(date +%s)-$$"
  ssh-keygen -q -t ed25519 -N '' -f "$tmp/key"
  public_line="$(cat "$tmp/key.pub") $marker"

  cleanup_pull_key() {
    "${SSH_SOURCE[@]}" "sed -i '/$marker/d' ~/.ssh/authorized_keys" >/dev/null 2>&1 || true
    "${SSH_TARGET[@]}" "sudo rm -f /tmp/overleaf-migration-key /tmp/remote_pull.sh" >/dev/null 2>&1 || true
    rm -rf "$tmp"
  }
  trap 'cleanup_pull_key; cleanup_local' EXIT

  printf '%s\n' "$public_line" | "${SSH_SOURCE[@]}" 'cat >> ~/.ssh/authorized_keys'
  "${SCP_TARGET[@]}" "$tmp/key" "$TARGET_USER@$TARGET_IP:/tmp/overleaf-migration-key" >/dev/null
  "${SCP_TARGET[@]}" "$ROOT_DIR/scripts/remote_pull.sh" "$TARGET_USER@$TARGET_IP:/tmp/remote_pull.sh" >/dev/null
  "${SSH_TARGET[@]}" "sudo chmod 0600 /tmp/overleaf-migration-key; sudo chmod 0755 /tmp/remote_pull.sh; sudo /tmp/remote_pull.sh '$mode' '$SOURCE_IP' /tmp/overleaf-migration-key"
  cleanup_pull_key
  trap cleanup_local EXIT
}

case "$COMMAND" in
  preflight)
    mkdir -p "$ARTIFACT_DIR"
    stamp=$(date -u +%Y%m%dT%H%M%SZ)
    output="$ARTIFACT_DIR/source-$stamp.txt"
    "${SSH_SOURCE[@]}" 'set -e
      echo "timestamp=$(date -u +%FT%TZ)"
      echo "instance_id=$(TOKEN=$(curl -fsS -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" http://169.254.169.254/latest/api/token); curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)"
      echo "commit=$(git -C /home/ubuntu/overleaf rev-parse HEAD)"
      echo "git_status_begin"; git -C /home/ubuntu/overleaf status --short; echo "git_status_end"
      echo "compose_hash=$(sha256sum /home/ubuntu/overleaf/develop/docker-compose.yml | cut -d" " -f1)"
      echo "dev_env_hash=$(sha256sum /home/ubuntu/overleaf/develop/dev.env | cut -d" " -f1)"
      echo "home_bytes=$(sudo du -sx --block-size=1 /home/ubuntu | cut -f1)"
      sudo sh -c "du -sx --block-size=1 /var/lib/docker/volumes/develop_*"
      sudo docker ps --format "container={{.Names}} image={{.Image}} status={{.Status}}"
      sudo docker exec develop-mongo-1 mongosh --quiet --eval '\''const d=db.getSiblingDB("sharelatex"); for (const n of ["users","projects","docs"]) print(n+"="+d.getCollection(n).countDocuments({}))'\''
      sudo docker exec develop-redis-1 redis-cli ping' | tee "$output"
    echo "Wrote $output"
    ;;
  sync-workspace)
    with_pull_key workspace
    ;;
  repair-lockfile)
    need_target
    "${SSH_TARGET[@]}" 'set -e
      cd /home/ubuntu/overleaf
      test -f /home/ubuntu/package-lock.json.pre-migration ||
        cp package-lock.json /home/ubuntu/package-lock.json.pre-migration
      sudo docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
        -v /home/ubuntu/overleaf:/work -w /work node:24.13.0 \
        npm install --package-lock-only --ignore-scripts --no-audit --no-fund
      test "$(git diff --name-only)" = package-lock.json
      test -z "$(git diff --cached --name-only)"
      test -z "$(git ls-files --others --exclude-standard)"
      echo "package-lock.json regenerated; original saved outside the repository"'
    ;;
  build)
    need_target
    if "${SSH_TARGET[@]}" 'test -n "$(git -C /home/ubuntu/overleaf diff -- package-lock.json)"'; then
      echo "Using the existing repaired package-lock.json"
    else
      "$0" repair-lockfile
    fi
    "${SSH_TARGET[@]}" 'set -e; test -f /var/lib/cloud/overleaf-bootstrap-complete; cd /home/ubuntu/overleaf/develop; sudo docker compose build --pull'
    ;;
  configure-hostname)
    need_target
    "${SSH_TARGET[@]}" "set -e
      sed -i 's|^OVERLEAF_SITE_URL=.*|OVERLEAF_SITE_URL=https://$SERVICE_HOSTNAME|' /home/ubuntu/overleaf/develop/dev.env
      grep -qx 'OVERLEAF_SITE_URL=https://$SERVICE_HOSTNAME' /home/ubuntu/overleaf/develop/dev.env"
    ;;
  start-http-test)
    need_target
    "$0" configure-hostname
    "${SSH_TARGET[@]}" 'set -e; cd /home/ubuntu/overleaf/develop; sudo docker compose up -d'
    ;;
  stop-http-test)
    need_target
    "${SSH_TARGET[@]}" 'set -e; cd /home/ubuntu/overleaf/develop; sudo docker compose stop'
    ;;
  sync-data-online)
    with_pull_key data-online
    ;;
  final-sync)
    need_target
    "${SSH_SOURCE[@]}" 'cd /home/ubuntu/overleaf/develop && sudo docker compose stop'
    "${SSH_TARGET[@]}" 'cd /home/ubuntu/overleaf/develop && sudo docker compose stop 2>/dev/null || true'
    with_pull_key data-final
    "$0" configure-hostname
    "${SSH_TARGET[@]}" 'cd /home/ubuntu/overleaf/develop && sudo docker compose up -d'
    ;;
  validate)
    need_target
    "${SSH_TARGET[@]}" 'set -e
      test "$(git -C /home/ubuntu/overleaf rev-parse HEAD)" = "4b7445035672fd108bdc04490fe6a2458926161f"
      test "$(git -C /home/ubuntu/overleaf diff --name-only | wc -l)" -eq 2
      test "$(git -C /home/ubuntu/overleaf diff --name-only | grep -cx develop/dev.env)" -eq 1
      test "$(git -C /home/ubuntu/overleaf diff --name-only | grep -cx package-lock.json)" -eq 1
      test -z "$(git -C /home/ubuntu/overleaf diff --cached --name-only)"
      test -z "$(git -C /home/ubuntu/overleaf ls-files --others --exclude-standard)"
      cd /home/ubuntu/overleaf/develop
      expected=$(sudo docker compose config --services | wc -l)
      running=$(sudo docker compose ps --status running --services | wc -l)
      test "$running" -eq "$expected"
      sudo docker exec develop-mongo-1 mongosh --quiet --eval '\''db.hello().isWritablePrimary'\'' | grep -q true
      test "$(sudo docker exec develop-redis-1 redis-cli ping)" = PONG
      sudo docker exec develop-mongo-1 mongosh --quiet --eval '\''const d=db.getSiblingDB("sharelatex"); for (const n of ["users","projects","docs"]) print(n+"="+d.getCollection(n).countDocuments({}))'\''
      curl -fsS --retry 20 --retry-delay 3 http://127.0.0.1:8080/ >/dev/null
      curl -fsS --retry 10 --retry-delay 2 http://127.0.0.1/ >/dev/null
      echo "Target validation passed"'
    ;;
  enable-target-tls)
    need_target
    "${SSH_TARGET[@]}" "sudo tee /etc/caddy/Caddyfile >/dev/null <<EOF
$SERVICE_HOSTNAME {
    reverse_proxy 127.0.0.1:8080
}

http://$TARGET_IP {
    reverse_proxy 127.0.0.1:8080
}
EOF
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy"
    ;;
  proxy-source)
    need_target
    "${SSH_SOURCE[@]}" "sudo test -f /etc/caddy/Caddyfile.pre-migration || sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.pre-migration
sudo tee /etc/caddy/Caddyfile >/dev/null <<EOF
$SERVICE_HOSTNAME {
    reverse_proxy http://$TARGET_IP
}

http://$SOURCE_IP {
    reverse_proxy http://$TARGET_IP
}
EOF
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy"
    ;;
  rollback-proxy)
    "${SSH_SOURCE[@]}" 'set -e; sudo test -f /etc/caddy/Caddyfile.pre-migration; sudo cp /etc/caddy/Caddyfile.pre-migration /etc/caddy/Caddyfile; sudo caddy validate --config /etc/caddy/Caddyfile; sudo systemctl reload caddy; cd /home/ubuntu/overleaf/develop; sudo docker compose up -d'
    ;;
  *)
    usage
    exit 2
    ;;
esac
