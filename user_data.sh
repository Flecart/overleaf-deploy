#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/overleaf-deploy.log) 2>&1

echo "========================================="
echo "Overleaf AI Tutor Frontend - Deployment"
echo "Started: $(date)"
echo "========================================="

# --- System updates ---
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# --- Install Docker ---
echo "[1/6] Installing Docker..."
apt-get install -y ca-certificates curl gnupg lsb-release git make

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

echo "[2/6] Docker installed: $(docker --version)"

# --- Clone the Overleaf fork ---
echo "[3/6] Cloning overleaf (add-ai-tutor-frontend branch)..."
OVERLEAF_DIR="/opt/overleaf"
git clone --branch add-ai-tutor-frontend --single-branch --depth 1 \
  https://github.com/jiarui-liu/overleaf.git "$OVERLEAF_DIR"

cd "$OVERLEAF_DIR/develop"

# --- Patch docker-compose to disable sandboxed compiles ---
echo "[4/6] Configuring development environment..."

# The dev.env file may need SANDBOXED_COMPILES=false
if [ -f dev.env ]; then
  # Ensure sandboxed compiles are disabled (Community Edition)
  if grep -q "SANDBOXED_COMPILES" dev.env; then
    sed -i 's/SANDBOXED_COMPILES=.*/SANDBOXED_COMPILES=false/' dev.env
  else
    echo "SANDBOXED_COMPILES=false" >> dev.env
  fi
fi

# --- Build the project ---
echo "[5/6] Building Overleaf containers (this takes 10-20 minutes)..."
bin/build

# Build texlive image if the Dockerfile exists
if [ -d texlive ]; then
  docker build texlive -t texlive-full || echo "texlive build skipped (non-critical)"
fi

# --- Start services ---
echo "[6/6] Starting Overleaf services..."
bin/up -d

# Wait for containers to be healthy
echo "Waiting for services to become healthy..."
sleep 30

# --- Post-start configuration ---
echo "Running post-start configuration..."

# Fix upload directory permissions
docker compose exec -T --user root web bash -c \
  "mkdir -p /overleaf/services/web/data/uploads && chmod 777 /overleaf/services/web/data/uploads" \
  || echo "Upload dir fix will be applied after web is ready"

# Install TeX Live in CLSI container
echo "Installing TeX Live in CLSI container (this takes a few minutes)..."
docker compose exec -T --user root clsi bash -c \
  "apt-get update -qq && apt-get install -y texlive-latex-base texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended latexmk qpdf" \
  || echo "TeX Live install will need to be done manually if CLSI is not ready yet"

# Create admin user
echo "Creating admin user: ${ADMIN_EMAIL}..."
docker compose exec -T web bash -c \
  "cd /overleaf && node modules/server-ce-scripts/scripts/create-user.js --admin --email=${ADMIN_EMAIL}" \
  || echo "Admin user creation deferred - run manually after services are ready"

echo "========================================="
echo "Deployment completed: $(date)"
echo ""
echo "Access Overleaf at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "If admin user creation was deferred, SSH in and run:"
echo "  cd /opt/overleaf/develop"
echo "  docker compose exec web bash"
echo "  node modules/server-ce-scripts/scripts/create-user.js --admin --email=${ADMIN_EMAIL}"
echo ""
echo "Check service status with:"
echo "  cd /opt/overleaf/develop && docker compose ps"
echo "========================================="
