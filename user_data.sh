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

# --- Install and configure LiteLLM ---
echo "[3/8] Installing LiteLLM proxy server..."
apt-get install -y python3 python3-pip python3-venv
pip3 install --upgrade pip
pip3 install 'litellm[proxy]'

# Create LiteLLM config directory
mkdir -p /opt/litellm
cat > /opt/litellm/config.yaml << 'LITELLMEOF'
model_list:
  # OpenAI GPT-4o models (matches AI Tutor dropdown)
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: ${OPENAI_API_KEY}

  - model_name: gpt-4o-mini
    litellm_params:
      model: openai/gpt-4o-mini
      api_key: ${OPENAI_API_KEY}

  # OpenAI GPT-4.1 models (if available in your OpenAI account)
  - model_name: gpt-4.1
    litellm_params:
      model: openai/gpt-4.1
      api_key: ${OPENAI_API_KEY}

  - model_name: gpt-4.1-mini
    litellm_params:
      model: openai/gpt-4.1-mini
      api_key: ${OPENAI_API_KEY}

  # OpenAI GPT-5.2 models (if available in your OpenAI account)
  - model_name: gpt-5.2
    litellm_params:
      model: openai/gpt-5.2
      api_key: ${OPENAI_API_KEY}

  - model_name: gpt-5.2-chat-latest
    litellm_params:
      model: openai/gpt-5.2-chat-latest
      api_key: ${OPENAI_API_KEY}

  # Legacy models for backwards compatibility
  - model_name: gpt-4
    litellm_params:
      model: openai/gpt-4
      api_key: ${OPENAI_API_KEY}

  - model_name: gpt-4-turbo
    litellm_params:
      model: openai/gpt-4-turbo-preview
      api_key: ${OPENAI_API_KEY}

  - model_name: gpt-3.5-turbo
    litellm_params:
      model: openai/gpt-3.5-turbo
      api_key: ${OPENAI_API_KEY}

  # Anthropic Claude models (optional - uncomment if you have Anthropic API key)
  # - model_name: claude-3-opus
  #   litellm_params:
  #     model: anthropic/claude-3-opus-20240229
  #     api_key: ${ANTHROPIC_API_KEY}
  #
  # - model_name: claude-3-sonnet
  #   litellm_params:
  #     model: anthropic/claude-3-sonnet-20240229
  #     api_key: ${ANTHROPIC_API_KEY}

litellm_settings:
  drop_params: true
  set_verbose: true
  request_timeout: 600

general_settings:
  master_key: ${LITELLM_MASTER_KEY}

  # Cost tracking and budget limits
  max_budget: 0.0  # Maximum total spend in USD (0 = no spending allowed)
  budget_duration: 30d  # Reset budget every 30 days
LITELLMEOF

# Create systemd service for LiteLLM
cat > /etc/systemd/system/litellm.service << 'SERVICEEOF'
[Unit]
Description=LiteLLM Proxy Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/litellm
Environment="OPENAI_API_KEY=${OPENAI_API_KEY}"
Environment="LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}"
Environment="ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}"
ExecStart=/usr/local/bin/litellm --config /opt/litellm/config.yaml --port 4000 --host 0.0.0.0
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Reload systemd and start LiteLLM
systemctl daemon-reload
systemctl enable litellm
systemctl start litellm

echo "LiteLLM proxy server installed and started on port 4000"
echo "LiteLLM status: $(systemctl is-active litellm)"

# --- Clone the Overleaf fork ---
echo "[4/8] Cloning overleaf (add-ai-tutor-frontend branch)..."
OVERLEAF_DIR="/opt/overleaf"
git clone --single-branch --depth 1 \
  https://github.com/flecart/overleaf.git "$OVERLEAF_DIR"

cd "$OVERLEAF_DIR/develop"

# --- Configure SMTP/Email environment variables ---
echo "[5/8] Configuring email/SMTP settings..."

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

# Add OpenAI API key to .env_credentials if provided
if [ -n "${OPENAI_API_KEY}" ]; then
  echo "Adding OpenAI API key for AI Tutor features..."
  echo "" >> /opt/overleaf/.env_credentials
  echo "# OpenAI API Key for AI Tutor" >> /opt/overleaf/.env_credentials
  echo "export OPENAI_API_KEY=${OPENAI_API_KEY}" >> /opt/overleaf/.env_credentials
  
  # Add custom base URL if provided (for LiteLLM proxy or other OpenAI-compatible endpoints)
  if [ -n "${OPENAI_BASE_URL}" ]; then
    echo "export OPENAI_BASE_URL=${OPENAI_BASE_URL}" >> /opt/overleaf/.env_credentials
    echo "OpenAI API key and custom base URL configured"
  else
    echo "OpenAI API key configured (using default OpenAI endpoint)"
  fi
else
  echo "No OpenAI API key provided - AI Tutor features will not work"
fi

# Patch AI Tutor to support custom base URL
if [ -n "${OPENAI_BASE_URL}" ]; then
  echo "Patching AI Tutor to use custom OpenAI base URL..."
  AI_TUTOR_FILE="$OVERLEAF_DIR/services/web/app/src/Features/Chat/AiTutorReviewOrchestrator.mjs"
  if [ -f "$AI_TUTOR_FILE" ]; then
    # Replace: const openai = createOpenAI({ apiKey })
    # With: const openai = createOpenAI({ apiKey, baseURL: process.env.OPENAI_BASE_URL })
    sed -i 's/const openai = createOpenAI({ apiKey })/const openai = createOpenAI({ apiKey, baseURL: process.env.OPENAI_BASE_URL })/' "$AI_TUTOR_FILE"
    echo "AI Tutor patched to support custom base URL"
  else
    echo "Warning: AI Tutor file not found at expected location"
  fi
fi

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
else
  # Create dev.env if it doesn't exist
  touch dev.env
  echo "SANDBOXED_COMPILES=false" >> dev.env
fi

# Add customization settings to dev.env
echo "Adding customization settings to dev.env..."
cat >> dev.env << 'CUSTOMEOF'

# Customization Settings
APP_NAME=EuroSafeAI Intelligent Overleaf
OVERLEAF_APP_NAME=EuroSafeAI Intelligent Overleaf
OVERLEAF_NAV_TITLE=EuroSafeAI Intelligent Overleaf
OVERLEAF_HEADER_IMAGE_URL=https://eurosafeai.github.io/images/logo.png
OVERLEAF_ADMIN_EMAIL=eurosafeai.zurich@gmail.com
OVERLEAF_ALLOW_PUBLIC_ACCESS=true

# Email Configuration
EMAIL_CONFIRMATION_DISABLED=${EMAIL_CONFIRMATION_DISABLED}

# Allowed Email Domains (comma-separated, no spaces)
SHARELATEX_ALLOWED_EMAIL_DOMAINS=${SHARELATEX_ALLOWED_EMAIL_DOMAINS}
CUSTOMEOF

echo "Customization settings added to dev.env"

# --- Build or pull images ---
echo "[6/8] Building/pulling container images..."
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
  echo "[6/8] Building Overleaf containers (this takes 10-20 minutes)..."
  bin/build
  # Build texlive image if the Dockerfile exists
  if [ -d texlive ]; then
    docker build texlive -t texlive-full || echo "texlive build skipped (non-critical)"
  fi
fi

# --- Start services ---
echo "[7/8] Starting Overleaf services..."

# Source environment variables before starting docker-compose
if [ -f /opt/overleaf/.env ]; then
  set -a  # Automatically export all variables
  source /opt/overleaf/.env
  set +a
fi

if [ "${USE_PREBUILT_IMAGES}" = "true" ] && [ -n "${DOCKER_IMAGE_PREFIX}" ]; then
  docker compose -f docker-compose.yml -f docker-compose.prebuilt.yml up -d
else
  bin/up -d
fi

# --- Initialize MongoDB Replica Set ---
echo "Waiting for MongoDB to be ready..."
sleep 20

echo "Initializing MongoDB replica set (required for Overleaf transactions)..."
# Retry up to 10 times to initialize the replica set
for i in {1..10}; do
  if docker compose exec -T mongo mongosh --eval 'rs.initiate({ _id: "overleaf", members: [{ _id: 0, host: "mongo:27017" }] })' 2>&1 | grep -q '"ok"'; then
    echo "MongoDB replica set initialized successfully"
    break
  else
    echo "Attempt $i failed, retrying in 5 seconds..."
    sleep 5
  fi
done

# # Wait for containers to be healthy
# echo "Waiting for services to become healthy..."
# sleep 30

# --- Post-start configuration ---
echo "Running post-start configuration..."

# Fix upload directory permissions
docker compose exec -T --user root web bash -c \
  "mkdir -p /overleaf/services/web/data/uploads && chmod 777 /overleaf/services/web/data/uploads" \
  || echo "Upload dir fix will be applied after web is ready"

# Fix history bucket directory permissions
echo "Setting up history-v1 bucket directories..."
docker compose exec -T --user root history-v1 bash -c \
  "mkdir -p /buckets/project_blobs /buckets/chunks /buckets/analytics /buckets/blobs /buckets/zips && \
   chmod -R 777 /buckets" \
  || echo "History buckets will be fixed after history-v1 is ready"

# Install TeX Live in CLSI container
echo "Installing TeX Live in CLSI container (this takes a few minutes)..."
docker compose exec -T --user root clsi bash -c \
  "apt-get update -qq && apt-get install -y texlive-latex-base texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended latexmk qpdf" \
  || echo "TeX Live install will need to be done manually if CLSI is not ready yet"

# Fix filestore blob path restructuring (from underscore to slash format)
echo "Restructuring blob files for filestore compatibility..."
sudo docker compose exec -T --user root filestore bash -c '
cd /buckets/project_blobs 2>/dev/null || mkdir -p /buckets/project_blobs
if [ -n "$(ls -A 2>/dev/null)" ]; then
  shopt -s nullglob
  for f in *_*; do
    if [ -f "$f" ]; then
      newpath=$(echo "$f" | sed "s/_/\//g")
      dir=$(dirname "$newpath")
      mkdir -p "$dir"
      cp "$f" "$newpath"
    fi
  done
  echo "Blob files restructured successfully"
else
  echo "No blob files found yet (will be created when projects are uploaded)"
fi
' || echo "Blob restructuring will need to be done manually after filestore is ready"

# Create admin user
echo "Creating admin user: ${ADMIN_EMAIL}..."
docker compose exec -T web bash -c \
  "cd /overleaf/services/web && node modules/server-ce-scripts/scripts/create-user.js --admin --email=${ADMIN_EMAIL}" \
  || echo "Admin user creation deferred - run manually after services are ready"

echo "[8/8] Deployment completed!"
echo "========================================="
echo "Deployment completed: $(date)"
echo ""
echo "Access Overleaf at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "LiteLLM Proxy at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):4000"
echo ""
echo "If admin user creation was deferred, SSH in and run:"
echo "  cd /opt/overleaf/develop"
echo "  docker compose exec web bash"
echo "  node modules/server-ce-scripts/scripts/create-user.js --admin --email=${ADMIN_EMAIL}"
echo ""
echo "Useful commands:"
echo "  Check service status:"
echo "    cd /opt/overleaf/develop && docker compose ps"
echo ""
echo "  View logs:"
echo "    docker compose logs web --tail=50 --follow"
echo ""
echo "  Restructure blob files (run after uploading projects with images):"
echo "    docker compose exec --user root filestore bash -c 'cd /buckets/project_blobs && for f in *_*; do newpath=\$(echo \"\$f\" | sed \"s/_/\\//g\"); dir=\$(dirname \"\$newpath\"); mkdir -p \"\$dir\"; cp \"\$f\" \"\$newpath\"; done && echo \"Done\"'"
echo ""
echo "  Clean compile cache (if compilation gets stuck):"
echo "    docker compose exec clsi bash -c \"rm -rf /overleaf/services/clsi/compiles/*/output.* /overleaf/services/clsi/cache/*\""
echo ""
echo "========================================="
