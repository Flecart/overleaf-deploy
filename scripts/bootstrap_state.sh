#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE=${AWS_PROFILE:-default}
REGION=${AWS_REGION:-us-east-1}
ACCOUNT_ID=${AWS_ACCOUNT_ID:-906513713427}
BUCKET=${TF_STATE_BUCKET:-eurosafeai-overleaf-tfstate-${ACCOUNT_ID}-${REGION}}

ACTUAL_ACCOUNT=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
[[ "$ACTUAL_ACCOUNT" == "$ACCOUNT_ID" ]] || {
  echo "Refusing to bootstrap state in account $ACTUAL_ACCOUNT; expected $ACCOUNT_ID" >&2
  exit 1
}

if ! aws s3api head-bucket --profile "$PROFILE" --bucket "$BUCKET" 2>/dev/null; then
  aws s3api create-bucket --profile "$PROFILE" --region "$REGION" --bucket "$BUCKET"
fi

aws s3api put-public-access-block --profile "$PROFILE" --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --profile "$PROFILE" --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
aws s3api put-bucket-versioning --profile "$PROFILE" --bucket "$BUCKET" --versioning-configuration Status=Enabled

echo "Terraform state bucket ready: $BUCKET"
