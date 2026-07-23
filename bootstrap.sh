#!/usr/bin/env bash
set -Eeuo pipefail
exec > >(tee -a /var/log/overleaf-bootstrap.log) 2>&1

DATA_ROOT=/srv/overleaf-data
DATA_SERIAL="${data_volume_serial}"

echo "Waiting for persistent EBS volume $DATA_SERIAL"
DATA_DEVICE=""
for _ in $(seq 1 120); do
  DATA_DEVICE=$(lsblk -dn -o NAME,SERIAL | awk -v serial="$DATA_SERIAL" '$2 == serial { print "/dev/" $1; exit }')
  [[ -n "$DATA_DEVICE" ]] && break
  sleep 5
done
[[ -n "$DATA_DEVICE" ]] || { echo "Persistent EBS volume not found" >&2; exit 1; }

if ! blkid "$DATA_DEVICE" >/dev/null 2>&1; then
  mkfs.ext4 -F -L overleaf-data "$DATA_DEVICE"
fi

mkdir -p "$DATA_ROOT"
DATA_UUID=$(blkid -s UUID -o value "$DATA_DEVICE")
grep -q "UUID=$DATA_UUID " /etc/fstab || echo "UUID=$DATA_UUID $DATA_ROOT ext4 defaults,nofail 0 2" >> /etc/fstab
mountpoint -q "$DATA_ROOT" || mount "$DATA_ROOT"

mkdir -p "$DATA_ROOT/home/ubuntu" "$DATA_ROOT/docker" "$DATA_ROOT/containerd"
rsync -aHAX /home/ubuntu/ "$DATA_ROOT/home/ubuntu/"
chown ubuntu:ubuntu "$DATA_ROOT/home/ubuntu"
grep -qF "$DATA_ROOT/home/ubuntu /home/ubuntu " /etc/fstab || echo "$DATA_ROOT/home/ubuntu /home/ubuntu none bind,x-systemd.requires-mounts-for=$DATA_ROOT 0 0" >> /etc/fstab
mountpoint -q /home/ubuntu || mount --bind "$DATA_ROOT/home/ubuntu" /home/ubuntu

if ! swapon --show=NAME | grep -q '^/swapfile$'; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg rsync jq caddy

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl stop docker.service docker.socket containerd.service || true
install -d -m 0711 "$DATA_ROOT/containerd" /var/lib/containerd
rsync -aHAX /var/lib/containerd/ "$DATA_ROOT/containerd/"
grep -qF "$DATA_ROOT/containerd /var/lib/containerd " /etc/fstab || echo "$DATA_ROOT/containerd /var/lib/containerd none bind,x-systemd.requires-mounts-for=$DATA_ROOT 0 0" >> /etc/fstab
mountpoint -q /var/lib/containerd || mount --bind "$DATA_ROOT/containerd" /var/lib/containerd

install -d -m 0755 /etc/docker
cat >/etc/docker/daemon.json <<EOF
{
  "data-root": "$DATA_ROOT/docker",
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "3" }
}
EOF

usermod -aG docker ubuntu
systemctl enable docker
systemctl start containerd
systemctl restart docker

cat >/etc/caddy/Caddyfile <<'EOF'
:80 {
    reverse_proxy 127.0.0.1:8080
}
EOF
systemctl enable caddy
systemctl restart caddy

cat >/etc/sysctl.d/99-overleaf.conf <<'EOF'
vm.swappiness=10
fs.inotify.max_user_watches=524288
EOF
sysctl --system

touch /var/lib/cloud/overleaf-bootstrap-complete
echo "Overleaf destination bootstrap complete"
