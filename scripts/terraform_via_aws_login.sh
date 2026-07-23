#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
EXPECTED_ACCOUNT=${AWS_ACCOUNT_ID:-906513713427}
actual_account=$(aws sts get-caller-identity --profile default --query Account --output text)

[[ "$actual_account" == "$EXPECTED_ACCOUNT" ]] || {
  echo "Refusing Terraform operation in account $actual_account; expected $EXPECTED_ACCOUNT" >&2
  exit 1
}

process_config=$(mktemp /tmp/overleaf-terraform-aws.XXXXXX)
cleanup() { rm -f "$process_config"; }
trap cleanup EXIT

cat >"$process_config" <<EOF
[profile terraform-login]
region = us-east-1
credential_process = $ROOT_DIR/scripts/export_aws_login_credentials.sh
EOF

export AWS_CONFIG_FILE=$process_config
export AWS_PROFILE=terraform-login
export AWS_SDK_LOAD_CONFIG=1

terraform "$@"
