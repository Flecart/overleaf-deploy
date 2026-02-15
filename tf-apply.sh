#!/bin/bash
# Extract AWS credentials from login session and run terraform apply

CREDS=$(find ~/.aws/login/cache -type f -name '*.json' | head -1 | xargs cat | jq -r '.accessToken')

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.accessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.secretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.sessionToken')
export AWS_REGION=eu-central-1

echo "Running terraform apply with AWS credentials from login session..."
terraform apply -auto-approve
