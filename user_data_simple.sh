#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/overleaf-deploy.log) 2>&1

echo "========================================="
echo "Overleaf Deployment (Simple 3-Container Setup)"
echo "Started: $(date)"
echo "========================================="

# --- System updates ---
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# --- Install Docker ---
echo "[1/4] Installing Docker..."
apt-get install -y ca-certificates curl gnupg lsb-release

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

echo "[2/4] Docker installed: $(docker --version)"

# --- Set up Overleaf ---
echo "[3/4] Setting up Overleaf..."
OVERLEAF_DIR="/opt/overleaf"
mkdir -p "$OVERLEAF_DIR"
cd "$OVERLEAF_DIR"

# Write the docker-compose.yml from Terraform
cat > docker-compose.yml << 'DOCKERCOMPOSEEOF'
${DOCKER_COMPOSE_CONTENT}
DOCKERCOMPOSEEOF

# Create .env file with configuration
cat > .env << 'ENVEOF'
# Environment variables for Overleaf
export ADMIN_EMAIL=${ADMIN_EMAIL}
export EMAIL_CONFIRMATION_DISABLED=${EMAIL_CONFIRMATION_DISABLED}
export OVERLEAF_ALLOWED_EMAIL_DOMAINS=${SHARELATEX_ALLOWED_EMAIL_DOMAINS}

# SMTP Configuration
export OVERLEAF_EMAIL_FROM_ADDRESS=${OVERLEAF_EMAIL_FROM_ADDRESS}
export OVERLEAF_EMAIL_SMTP_HOST=${OVERLEAF_EMAIL_SMTP_HOST}
export OVERLEAF_EMAIL_SMTP_PORT=${OVERLEAF_EMAIL_SMTP_PORT}
export OVERLEAF_EMAIL_SMTP_SECURE=${OVERLEAF_EMAIL_SMTP_SECURE}
export OVERLEAF_EMAIL_SMTP_USER=${OVERLEAF_EMAIL_SMTP_USER}
export OVERLEAF_EMAIL_SMTP_PASS=${OVERLEAF_EMAIL_SMTP_PASS}
export OVERLEAF_EMAIL_SMTP_TLS_REJECT_UNAUTH=${OVERLEAF_EMAIL_SMTP_TLS_REJECT_UNAUTH}
export OVERLEAF_EMAIL_SMTP_IGNORE_TLS=${OVERLEAF_EMAIL_SMTP_IGNORE_TLS}
ENVEOF

# Add S3 configuration if enabled
if [ "${ENABLE_S3_STORAGE}" = "true" ]; then
  echo "Configuring S3 storage backend..."
  cat >> .env << 'S3EOF'

# S3 Storage Configuration
export OVERLEAF_FILESTORE_BACKEND=s3
export OVERLEAF_FILESTORE_USER_FILES_BUCKET_NAME=${S3_USER_FILES_BUCKET}
export OVERLEAF_FILESTORE_TEMPLATE_FILES_BUCKET_NAME=${S3_TEMPLATE_FILES_BUCKET}
export OVERLEAF_FILESTORE_S3_ACCESS_KEY_ID=${S3_FILESTORE_ACCESS_KEY_ID}
export OVERLEAF_FILESTORE_S3_SECRET_ACCESS_KEY=${S3_FILESTORE_SECRET_ACCESS_KEY}
export OVERLEAF_FILESTORE_S3_REGION=${AWS_REGION}

export OVERLEAF_HISTORY_BACKEND=s3
export OVERLEAF_HISTORY_PROJECT_BLOBS_BUCKET=${S3_PROJECT_BLOBS_BUCKET}
export OVERLEAF_HISTORY_CHUNKS_BUCKET=${S3_CHUNKS_BUCKET}
export OVERLEAF_HISTORY_S3_ACCESS_KEY_ID=${S3_HISTORY_ACCESS_KEY_ID}
export OVERLEAF_HISTORY_S3_SECRET_ACCESS_KEY=${S3_HISTORY_SECRET_ACCESS_KEY}
export OVERLEAF_HISTORY_S3_REGION=${AWS_REGION}
S3EOF
  echo "S3 storage configuration added"
else
  echo "S3 storage disabled, using local storage"
fi

# Source environment variables
source .env

echo "[4/4] Starting Overleaf services..."

# Start Docker Compose
docker compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 30

# Create admin user
echo "Creating admin user: ${ADMIN_EMAIL}..."
docker exec sharelatex /bin/bash -c "cd /overleaf/services/web && node modules/server-ce-scripts/scripts/create-user --admin --email=${ADMIN_EMAIL}" \
  || echo "Admin user creation deferred - may need to run manually"

echo "========================================="
echo "Deployment completed: $(date)"
echo ""
echo "Access Overleaf at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "If admin user creation failed, SSH in and run:"
echo "  cd /opt/overleaf"
echo "  docker exec sharelatex /bin/bash -c \"cd /overleaf/services/web && node modules/server-ce-scripts/scripts/create-user --admin --email=${ADMIN_EMAIL}\""
echo ""
echo "Check service status with:"
echo "  cd /opt/overleaf && docker compose ps"
echo "========================================="
