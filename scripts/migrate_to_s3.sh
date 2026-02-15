#!/bin/bash
# S3 Migration Script for Existing Overleaf Data
# This script helps migrate existing Overleaf data from EBS to S3 storage
# 
# Prerequisites:
# 1. S3 buckets created by Terraform (terraform apply with enable_s3_storage=true)
# 2. SSH access to the Overleaf instance
# 3. AWS CLI installed on the instance
# 4. IAM credentials for S3 access

set -euo pipefail

echo "========================================="
echo "Overleaf S3 Migration Script"
echo "========================================="

# Configuration from Terraform outputs
read -p "Enter S3 user-files bucket name: " S3_USER_FILES_BUCKET
read -p "Enter S3 template-files bucket name: " S3_TEMPLATE_FILES_BUCKET
read -p "Enter S3 project-blobs bucket name: " S3_PROJECT_BLOBS_BUCKET
read -p "Enter S3 chunks bucket name: " S3_CHUNKS_BUCKET
read -p "Enter AWS region: " AWS_REGION
read -sp "Enter Filestore Access Key ID: " S3_FILESTORE_ACCESS_KEY_ID
echo
read -sp "Enter Filestore Secret Access Key: " S3_FILESTORE_SECRET_ACCESS_KEY
echo
read -sp "Enter History Access Key ID: " S3_HISTORY_ACCESS_KEY_ID
echo
read -sp "Enter History Secret Access Key: " S3_HISTORY_SECRET_ACCESS_KEY
echo

echo
echo "========================================="
echo "Migration will perform the following:"
echo "1. Stop Overleaf containers"
echo "2. Copy data from local storage to S3"
echo "3. Update configuration to use S3"
echo "4. Restart containers with S3 backend"
echo "========================================="
echo
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Migration cancelled."
    exit 0
fi

# Ensure we're in the right directory
cd /opt/overleaf/develop

echo
echo "[1/6] Stopping Overleaf containers..."
docker compose down

echo
echo "[2/6] Configuring AWS CLI..."
aws configure set aws_access_key_id "$S3_FILESTORE_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$S3_FILESTORE_SECRET_ACCESS_KEY"
aws configure set region "$AWS_REGION"

echo
echo "[3/6] Copying user files to S3..."
if [ -d ~/sharelatex_data/data/user_files ]; then
    aws s3 sync ~/sharelatex_data/data/user_files/ "s3://${S3_USER_FILES_BUCKET}/" \
        --no-progress || echo "Warning: user_files sync had some errors"
else
    echo "No user_files directory found, skipping..."
fi

echo
echo "[4/6] Copying template files to S3..."
if [ -d ~/sharelatex_data/data/template_files ]; then
    aws s3 sync ~/sharelatex_data/data/template_files/ "s3://${S3_TEMPLATE_FILES_BUCKET}/" \
        --no-progress || echo "Warning: template_files sync had some errors"
else
    echo "No template_files directory found, skipping..."
fi

# Configure for history service
aws configure set aws_access_key_id "$S3_HISTORY_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$S3_HISTORY_SECRET_ACCESS_KEY"

echo
echo "[5/6] Copying project blobs to S3..."
if [ -d ~/sharelatex_data/data/history/overleaf-project-blobs ]; then
    aws s3 sync ~/sharelatex_data/data/history/overleaf-project-blobs/ "s3://${S3_PROJECT_BLOBS_BUCKET}/" \
        --no-progress || echo "Warning: project-blobs sync had some errors"
else
    echo "No project-blobs directory found, skipping..."
fi

echo
echo "[6/6] Copying history chunks to S3..."
if [ -d ~/sharelatex_data/data/history/overleaf-chunks ]; then
    aws s3 sync ~/sharelatex_data/data/history/overleaf-chunks/ "s3://${S3_CHUNKS_BUCKET}/" \
        --no-progress || echo "Warning: chunks sync had some errors"
else
    echo "No chunks directory found, skipping..."
fi

echo
echo "========================================="
echo "Migration Complete!"
echo "========================================="
echo
echo "Next steps:"
echo "1. Verify S3 buckets contain data:"
echo "   aws s3 ls s3://${S3_USER_FILES_BUCKET}/"
echo
echo "2. Update docker-compose environment variables to use S3"
echo "   (This should be done automatically by user_data.sh on next terraform apply)"
echo
echo "3. Restart Overleaf:"
echo "   cd /opt/overleaf/develop"
echo "   docker compose up -d"
echo
echo "4. Test by creating a project and uploading a file"
echo
echo "5. If everything works, you can optionally delete local data:"
echo "   rm -rf ~/sharelatex_data/data/user_files"
echo "   rm -rf ~/sharelatex_data/data/template_files"
echo "   rm -rf ~/sharelatex_data/data/history"
echo
echo "========================================="
