#!/usr/bin/env bash
set -Eeuo pipefail

MODE=${1:?usage: remote_pull.sh workspace|data-online|data-final SOURCE_IP KEY_PATH}
SOURCE_IP=${2:?source IP required}
KEY_PATH=${3:?temporary source key required}
SOURCE_USER=${SOURCE_USER:-ubuntu}

SSH=(ssh -F /dev/null -i "$KEY_PATH" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
RSYNC_SSH="ssh -F /dev/null -i $KEY_PATH -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

case "$MODE" in
  workspace)
    rsync -aHAX --numeric-ids --delete-delay --info=stats2 \
      --exclude='/.ssh/' \
      --exclude='/.aws/' \
      --exclude='/.gnupg/' \
      --exclude='/.docker/config.json' \
      --exclude='/.git-credentials' \
      --exclude='/.bash_history' \
      --exclude='/.python_history' \
      --exclude='/.lesshst' \
      --exclude='/.cache/' \
      --exclude='/.cursor/' \
      --exclude='/.cursor-server/' \
      --exclude='/**/__pycache__/' \
      -e "$RSYNC_SSH" --rsync-path='sudo rsync' \
      "$SOURCE_USER@$SOURCE_IP:/home/ubuntu/" /home/ubuntu/
    chown -R ubuntu:ubuntu /home/ubuntu
    if [[ -f /home/ubuntu/overleaf/.env_credentials ]]; then
      chmod 0600 /home/ubuntu/overleaf/.env_credentials
      chown ubuntu:ubuntu /home/ubuntu/overleaf/.env_credentials
    fi
    ;;
  data-online|data-final)
    mapfile -t volumes < <("${SSH[@]}" "$SOURCE_USER@$SOURCE_IP" \
      "sudo docker volume ls --format '{{.Name}}' | sed -n '/^develop_/p'")
    ((${#volumes[@]} > 0)) || { echo "No develop_* volumes found on source" >&2; exit 1; }

    for volume in "${volumes[@]}"; do
      [[ "$volume" =~ ^develop_[a-zA-Z0-9_.-]+$ ]] || { echo "Unsafe volume name: $volume" >&2; exit 1; }
      if [[ "$MODE" == data-online && ( "$volume" == develop_mongo-data || "$volume" == develop_redis-data ) ]]; then
        echo "Deferring live database volume $volume until the stopped final sync"
        continue
      fi
      docker volume create "$volume" >/dev/null
      destination=$(docker volume inspect "$volume" --format '{{.Mountpoint}}')
      echo "Synchronizing $volume"
      rsync -aHAX --numeric-ids --delete --info=stats2 \
        -e "$RSYNC_SSH" --rsync-path='sudo rsync' \
        "$SOURCE_USER@$SOURCE_IP:/var/lib/docker/volumes/$volume/_data/" "$destination/"
    done
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    exit 2
    ;;
esac
