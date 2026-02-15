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
git clone --single-branch --depth 1 \
  https://github.com/flecart/overleaf.git "$OVERLEAF_DIR"

cd "$OVERLEAF_DIR/develop"

# --- Configure SMTP/Email environment variables ---
echo "[4/6] Configuring email/SMTP settings..."

# Create .env file with SMTP and S3 configuration
cat > /opt/overleaf/.env << 'ENVEOF'
# SMTP Configuration for Overleaf Email
export OVERLEAF_EMAIL_FROM_ADDRESS=${OVERLEAF_EMAIL_FROM_ADDRESS}
export OVERLEAF_EMAIL_SMTP_HOST=${OVERLEAF_EMAIL_SMTP_HOST}
export OVERLEAF_EMAIL_SMTP_PORT=${OVERLEAF_EMAIL_SMTP_PORT}
export OVERLEAF_EMAIL_SMTP_SECURE=${OVERLEAF_EMAIL_SMTP_SECURE}
export OVERLEAF_EMAIL_SMTP_USER=${OVERLEAF_EMAIL_SMTP_USER}
export OVERLEAF_EMAIL_SMTP_PASS=${OVERLEAF_EMAIL_SMTP_PASS}
export OVERLEAF_EMAIL_SMTP_TLS_REJECT_UNAUTH=${OVERLEAF_EMAIL_SMTP_TLS_REJECT_UNAUTH}
export OVERLEAF_EMAIL_SMTP_IGNORE_TLS=${OVERLEAF_EMAIL_SMTP_IGNORE_TLS}

# User Registration & Access Control
export EMAIL_CONFIRMATION_DISABLED=${EMAIL_CONFIRMATION_DISABLED}
export SHARELATEX_ALLOWED_EMAIL_DOMAINS=${SHARELATEX_ALLOWED_EMAIL_DOMAINS}
ENVEOF

# Add S3 configuration if enabled
if [ "${ENABLE_S3_STORAGE}" = "true" ]; then
  echo "Configuring S3 storage backend..."
  cat >> /opt/overleaf/.env << 'S3EOF'

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

# Source the environment file
source /opt/overleaf/.env

# Create symlink for compatibility with overleaf repo structure
ln -sf /opt/overleaf/.env /opt/overleaf/.env_credentials

if [ -n "${OVERLEAF_EMAIL_SMTP_HOST}" ] && [ -n "${OVERLEAF_EMAIL_SMTP_USER}" ]; then
  echo "SMTP configuration loaded from environment variables"
else
  echo "No SMTP credentials provided, email will be disabled"
fi

# --- Patch docker-compose to disable sandboxed compiles ---
echo "Configuring development environment..."

# The dev.env file may need SANDBOXED_COMPILES=false
if [ -f dev.env ]; then
  # Ensure sandboxed compiles are disabled (Community Edition)
  if grep -q "SANDBOXED_COMPILES" dev.env; then
    sed -i 's/SANDBOXED_COMPILES=.*/SANDBOXED_COMPILES=false/' dev.env
  else
    echo "SANDBOXED_COMPILES=false" >> dev.env
  fi
fi

# --- Fix MongoDB version and configure replica set ---
echo "Ensuring MongoDB 8.0 with replica set configuration..."

# Create docker-compose override for MongoDB configuration
cat > docker-compose.mongo-rs.yml << 'MONGOEOF'
services:
  mongo:
    image: mongo:8.0
    command: ["mongod", "--replSet", "overleaf"]
MONGOEOF

echo "Created MongoDB replica set override configuration"

# Clean old MongoDB data to prevent version conflicts (exit code 62)
# This removes incompatible data from older MongoDB versions
rm -rf ~/mongo_data ~/sharelatex_data
echo "Cleaned old MongoDB data to ensure fresh MongoDB 8.0 start with replica set mode"

# --- Build or pull images ---
echo "[5/6] Building/pulling container images..."
if [ "${USE_PREBUILT_IMAGES}" = "true" ] && [ -n "${DOCKER_IMAGE_PREFIX}" ]; then
  echo "Pulling pre-built images from Docker Hub (~2-5 min)..."
  # Write override to use pre-built images instead of building
  OVERRIDE="docker-compose.prebuilt.yml"
  cat > "$OVERRIDE" << 'OVERRIDEEOF'
services:
  chat:
    image: IMAGEPREFIX-chat:IMAGETAG
  clsi:
    image: IMAGEPREFIX-clsi:IMAGETAG
  contacts:
    image: IMAGEPREFIX-contacts:IMAGETAG
  docstore:
    image: IMAGEPREFIX-docstore:IMAGETAG
  document-updater:
    image: IMAGEPREFIX-document-updater:IMAGETAG
  filestore:
    image: IMAGEPREFIX-filestore:IMAGETAG
  history-v1:
    image: IMAGEPREFIX-history-v1:IMAGETAG
  notifications:
    image: IMAGEPREFIX-notifications:IMAGETAG
  project-history:
    image: IMAGEPREFIX-project-history:IMAGETAG
  real-time:
    image: IMAGEPREFIX-real-time:IMAGETAG
  web:
    image: IMAGEPREFIX-web:IMAGETAG
  webpack:
    image: IMAGEPREFIX-webpack:IMAGETAG
OVERRIDEEOF
  sed -i "s|IMAGEPREFIX|${DOCKER_IMAGE_PREFIX}|g" "$OVERRIDE"
  sed -i "s|IMAGETAG|${DOCKER_IMAGE_TAG}|g" "$OVERRIDE"
  docker compose -f docker-compose.yml -f "$OVERRIDE" pull
  # Pull texlive (used by clsi) and tag as texlive-full
  docker pull "${DOCKER_IMAGE_PREFIX}-texlive:${DOCKER_IMAGE_TAG}" 2>/dev/null && \
    docker tag "${DOCKER_IMAGE_PREFIX}-texlive:${DOCKER_IMAGE_TAG}" texlive-full || \
    echo "texlive image not found at registry, building locally..."
  if ! docker images -q texlive-full | grep -q .; then
    [ -d texlive ] && docker build texlive -t texlive-full || true
  fi
  COMPOSE_FILES="-f docker-compose.yml -f $OVERRIDE"
else
  echo "[5/6] Building Overleaf containers (this takes 10-20 minutes)..."
  bin/build
  # Build texlive image if the Dockerfile exists
  if [ -d texlive ]; then
    docker build texlive -t texlive-full || echo "texlive build skipped (non-critical)"
  fi
fi

# --- Start services ---
echo "[6/6] Starting Overleaf services..."

# Source environment variables before starting docker-compose
if [ -f /opt/overleaf/.env ]; then
  set -a  # Automatically export all variables
  source /opt/overleaf/.env
  set +a
fi

if [ "${USE_PREBUILT_IMAGES}" = "true" ] && [ -n "${DOCKER_IMAGE_PREFIX}" ]; then
  docker compose -f docker-compose.yml -f docker-compose.prebuilt.yml -f docker-compose.mongo-rs.yml up -d
else
  # For local builds, also include MongoDB replica set override
  docker compose -f docker-compose.yml -f docker-compose.mongo-rs.yml up -d
fi

# --- Initialize MongoDB Replica Set ---
echo "Waiting for MongoDB to be ready..."
sleep 30

echo "Initializing MongoDB replica set (required for Overleaf transactions)..."
# Compose file references for commands
COMPOSE_CMD="docker compose -f docker-compose.yml -f docker-compose.mongo-rs.yml"
if [ "${USE_PREBUILT_IMAGES}" = "true" ] && [ -n "${DOCKER_IMAGE_PREFIX}" ]; then
  COMPOSE_CMD="docker compose -f docker-compose.yml -f docker-compose.prebuilt.yml -f docker-compose.mongo-rs.yml"
fi

# Retry up to 15 times to initialize the replica set
for i in {1..15}; do
  # First check if MongoDB is accepting connections
  if $COMPOSE_CMD exec -T mongo mongosh --quiet --eval 'db.adminCommand("ping")' 2>/dev/null | grep -q 'ok.*1'; then
    echo "MongoDB is responding, attempting to initialize replica set..."
    # Try to initialize the replica set
    RESULT=$($COMPOSE_CMD exec -T mongo mongosh --quiet --eval 'rs.initiate({ _id: "overleaf", members: [{ _id: 0, host: "mongo:27017" }] })' 2>&1)
    if echo "$RESULT" | grep -q '"ok".*1\|already initialized'; then
      echo "MongoDB replica set initialized successfully"
      break
    else
      echo "Attempt $i: Replica set init failed: $RESULT"
    fi
  else
    echo "Attempt $i: MongoDB not ready yet..."
  fi
  sleep 10
done

# Wait for containers to be healthy
echo "Waiting for services to become healthy..."
sleep 30

# --- Post-start configuration ---
echo "Running post-start configuration..."

# Fix upload directory permissions
$COMPOSE_CMD exec -T --user root web bash -c \
  "mkdir -p /overleaf/services/web/data/uploads && chmod 777 /overleaf/services/web/data/uploads" \
  || echo "Upload dir fix will be applied after web is ready"

# Install TeX Live in CLSI container
echo "Installing TeX Live in CLSI container (this takes a few minutes)..."
$COMPOSE_CMD exec -T --user root clsi bash -c \
  "apt-get update -qq && apt-get install -y texlive-latex-base texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended latexmk qpdf" \
  || echo "TeX Live install will need to be done manually if CLSI is not ready yet"

# Create admin user
echo "Creating admin user: ${ADMIN_EMAIL}..."
$COMPOSE_CMD exec -T web bash -c \
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
echo "  cd /opt/overleaf/develop && $COMPOSE_CMD ps"
echo "========================================="
