#!/bin/bash
# Build Overleaf images from the fork and push to Docker Hub or GitHub Container Registry.
# Run this locally or in CI, then set use_prebuilt_images=true in terraform.tfvars.
#
# Prerequisites: 
#   - Docker Desktop with at least 8GB RAM allocated (16GB+ recommended)
#   - Logged in: docker login (Docker Hub) OR docker login ghcr.io (GitHub)
#   - ~20GB free disk space
#
# Usage: ./scripts/build-and-push.sh [PREFIX] [TAG]
#   PREFIX: e.g. myuser/overleaf (Docker Hub) or ghcr.io/myuser/overleaf (GitHub)
#   TAG: e.g. ai-tutor (default: ai-tutor)
#
# Examples:
#   Docker Hub:  ./scripts/build-and-push.sh myuser/overleaf ai-tutor
#   GitHub:      ./scripts/build-and-push.sh ghcr.io/myuser/overleaf ai-tutor
#
# IMPORTANT: This build takes 10-20 minutes and uses significant RAM (~6-8GB).
# If your computer freezes during build, see README troubleshooting section.

set -euo pipefail

PREFIX="${1:-${OVERLEAF_IMAGE_PREFIX:?Set OVERLEAF_IMAGE_PREFIX (e.g. myuser/overleaf) or pass as first arg}}"
TAG="${2:-ai-tutor}"
BRANCH="${OVERLEAF_BRANCH:-add-ai-tutor-frontend}"
BUILD_DIR="${BUILD_DIR:-/tmp/overleaf-build-$$}"
PARALLEL_BUILDS="${DOCKER_BUILD_PARALLEL:-4}"  # Limit parallel builds to avoid freezing

echo "========================================="
echo "Overleaf Image Builder"
echo "========================================="
echo "Target: $PREFIX:$TAG"
echo "Branch: $BRANCH"
echo "Parallel builds: $PARALLEL_BUILDS"
echo ""
echo "⚠️  This build requires 8GB+ RAM and takes 10-20 minutes"
echo "⚠️  Close other applications to avoid system freezing"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Clone the fork
if [ ! -d "$BUILD_DIR" ]; then
  echo "Cloning overleaf ($BRANCH)..."
  git clone --branch "$BRANCH" --single-branch --depth 1 \
    https://github.com/flecart/overleaf.git "$BUILD_DIR"
fi

cd "$BUILD_DIR/develop"

# Workaround: Skip optional pprof package (fails with Node 24+)
# pprof is optional (profiling tool) - Overleaf works fine without it
echo "Configuring build environment..."
export NPM_CONFIG_OMIT=optional
export DOCKER_BUILDKIT=1

# Limit parallel builds to avoid memory exhaustion and system freezing
export COMPOSE_PARALLEL_LIMIT=$PARALLEL_BUILDS

# Build all images
echo ""
echo "Building containers (10-20 min)..."
echo "Note: Build may use 6-8GB RAM. If system freezes, reduce DOCKER_BUILD_PARALLEL:"
echo "  DOCKER_BUILD_PARALLEL=2 ./scripts/build-and-push.sh $PREFIX $TAG"
echo ""

bin/build

# Build texlive
if [ -d texlive ]; then
  echo "Building texlive..."
  docker build texlive -t texlive-full
fi

# Tag and push
# Docker Compose names built images as <project>_<service> (e.g. develop_chat, develop_web)
echo "Tagging and pushing to $PREFIX..."
SERVICES="chat clsi contacts docstore document-updater filestore history-v1 notifications project-history real-time web webpack"
for svc in $SERVICES; do
  # Match develop_<svc> or develop-<svc> (project name from directory)
  LOCAL_IMAGE=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "develop[_-]${svc}|^${svc}:" | head -1)
  if [ -z "$LOCAL_IMAGE" ]; then
    echo "  WARNING: Could not find image for $svc (run 'docker images' to debug)"
    continue
  fi
  TARGET="${PREFIX}-${svc}:${TAG}"
  docker tag "$LOCAL_IMAGE" "$TARGET"
  docker push "$TARGET"
  echo "  Pushed $TARGET"
done

# Texlive
if docker images -q texlive-full | grep -q .; then
  docker tag texlive-full "${PREFIX}-texlive:${TAG}"
  docker push "${PREFIX}-texlive:${TAG}"
  echo "  Pushed ${PREFIX}-texlive:${TAG}"
fi

echo ""
echo "========================================="
echo "✅ Build and push complete!"
echo "========================================="
echo ""
echo "Add to terraform.tfvars:"
echo "  use_prebuilt_images  = true"
echo "  docker_image_prefix  = \"$PREFIX\""
echo "  docker_image_tag     = \"$TAG\""
echo ""
echo "Then deploy with: terraform apply"
echo ""
echo "Cleanup: rm -rf $BUILD_DIR"
echo "========================================="
