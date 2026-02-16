#!/bin/bash
# Quick deployment helper when cloud-init is disabled
# Run this on your LOCAL machine

set -euo pipefail

echo "This script will:"
echo "1. Extract the rendered user_data from Terraform"
echo "2. Copy it to your EC2 instance"
echo "3. Run it to set up Overleaf"
echo

read -p "Enter your instance IP (e.g., 3.64.221.179): " INSTANCE_IP
read -p "Enter path to your SSH key (e.g., overleaf-key.pem): " SSH_KEY

# Get the rendered user_data from terraform
echo "Extracting deployment script from Terraform..."
terraform show -json | jq -r '.values.root_module.resources[] | select(.address=="aws_instance.overleaf") | .values.user_data' > /tmp/deploy_overleaf.sh

echo "Copying script to instance..."
scp -i "$SSH_KEY" /tmp/deploy_overleaf.sh ubuntu@$INSTANCE_IP:/tmp/

echo "Running deployment on instance..."
ssh -i "$SSH_KEY" ubuntu@$INSTANCE_IP "sudo bash /tmp/deploy_overleaf.sh"

echo
echo "============================================"
echo "Deployment complete!"
echo "Access Overleaf at: http://$INSTANCE_IP"
echo "============================================"
