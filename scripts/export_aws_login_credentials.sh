#!/usr/bin/env bash
set -Eeuo pipefail

# Terraform's AWS SDK does not currently consume AWS CLI login_session entries.
# The AWS CLI does, so expose its active default profile through the standard
# credential_process JSON protocol. The output is read directly by Terraform.
unset AWS_CONFIG_FILE AWS_PROFILE
exec aws configure export-credentials --profile default --format process
