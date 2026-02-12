# Overleaf AI Tutor — Terraform AWS Deployment

Deploys the [jiarui-liu/overleaf (add-ai-tutor-frontend)](https://github.com/jiarui-liu/overleaf/tree/add-ai-tutor-frontend) fork on an AWS EC2 instance using Docker.

## Prerequisites

1. **Terraform >= 1.3** installed ([install guide](https://developer.hashicorp.com/terraform/install))
2. **AWS CLI** configured with credentials (`aws configure`)
3. **An EC2 Key Pair** already created in your target AWS region

## Quick Start

```bash
cd overleaf-terraform

# 1. Configure your variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — at minimum set key_name and admin_email

# 2. Initialize and deploy
terraform init
terraform plan
terraform apply
```

Terraform will output the public IP. The full deployment (Docker build + TeX Live install) takes **15–25 minutes** after the instance launches.

## Checking Deployment Progress

```bash
# SSH into the instance
ssh -i <your-key.pem> ubuntu@<public-ip>

# Watch the cloud-init deployment log
sudo tail -f /var/log/overleaf-deploy.log

# Or check Docker containers
cd /opt/overleaf/develop && docker compose ps
```

## Accessing Overleaf

Once deployment is complete, open `http://<public-ip>` in your browser.

The first time, you'll need to activate your admin account. Check the deployment log for the activation URL:

```bash
sudo grep "activate" /var/log/overleaf-deploy.log
```

Replace `127.0.0.1:3000` in the URL with your instance's public IP.

## Manual Post-Deployment Steps (if needed)

If any automated steps failed during cloud-init, SSH in and run:

```bash
cd /opt/overleaf/develop

# Fix upload permissions
docker compose exec --user root web bash -c \
  "mkdir -p /overleaf/services/web/data/uploads && chmod 777 /overleaf/services/web/data/uploads"

# Install TeX Live (if not already installed)
docker compose exec --user root clsi bash -c \
  "apt-get update -qq && apt-get install -y texlive-latex-base texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended latexmk qpdf"

# Create admin user
docker compose exec web bash -c \
  "cd /overleaf && node modules/server-ce-scripts/scripts/create-user.js --admin --email=admin@example.com"
```

## Tear Down

```bash
terraform destroy
```

## Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `instance_type` | `t3.xlarge` | EC2 instance type (4 vCPU / 16GB RAM) |
| `key_name` | — (required) | Existing EC2 Key Pair name |
| `admin_email` | `admin@example.com` | Overleaf admin email |
| `allowed_ssh_cidrs` | `["0.0.0.0/0"]` | CIDRs allowed to SSH |
| `root_volume_size` | `50` | Root EBS volume size in GB |
| `project_name` | `overleaf-ai-tutor` | Name prefix for AWS resources |

## Architecture

```
Internet
    │
    ▼
┌─────────────────────────┐
│   AWS VPC  10.0.0.0/16  │
│  ┌───────────────────┐  │
│  │  Public Subnet     │  │
│  │  10.0.1.0/24       │  │
│  │  ┌──────────────┐  │  │
│  │  │  EC2 Instance │  │  │
│  │  │  (Ubuntu)     │  │  │
│  │  │              │  │  │
│  │  │  Docker:     │  │  │
│  │  │  - web       │  │  │
│  │  │  - mongo     │  │  │
│  │  │  - redis     │  │  │
│  │  │  - clsi      │  │  │
│  │  │  - ...       │  │  │
│  │  └──────────────┘  │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

## Cost Estimate

- **t3.xlarge** in us-east-1: ~$0.1664/hr (~$120/month)
- **50GB gp3 EBS**: ~$4/month
- Remember to `terraform destroy` when not in use!
