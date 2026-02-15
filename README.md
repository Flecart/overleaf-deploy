# Overleaf AI Tutor — Terraform AWS Deployment

Deploys the [flecart/overleaf (add-ai-tutor-frontend)](https://github.com/flecart/overleaf/tree/add-ai-tutor-frontend) fork on an AWS EC2 instance using Docker.

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

# 2. (Optional) Test SMTP credentials if configuring email
python3 scripts/test_gmail_smtp.py

# 3. Initialize and deploy
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
| `data_volume_size` | `50` | Persistent data volume size in GB |
| `project_name` | `overleaf-ai-tutor` | Name prefix for AWS resources |
| `use_prebuilt_images` | `false` | Use pre-built Docker images |
| `docker_image_prefix` | `""` | Docker registry prefix for images |
| `docker_image_tag` | `"ai-tutor"` | Docker image tag |

### S3 Storage Configuration (Recommended for Production)

| Variable | Default | Description |
|---|---|---|
| `enable_s3_storage` | `true` | Enable S3 storage backend for data persistence |
| `s3_bucket_prefix` | `"overleaf"` | Prefix for S3 bucket names (must be globally unique) |

**Why use S3?**
- Data persists even when EC2 instance is destroyed and recreated
- Unlimited scalability without managing disk space
- 99.999999999% (11 9's) durability
- Pay only for what you use (~$2-3/month for 50GB)

See [S3_STORAGE_GUIDE.md](./S3_STORAGE_GUIDE.md) for detailed setup and migration instructions.

### Email / SMTP Configuration (Optional)

| Variable | Default | Description |
|---|---|---|
| `overleaf_email_from_address` | `""` | Email address shown as sender |
| `overleaf_smtp_host` | `""` | SMTP server hostname (e.g., smtp.gmail.com) |
| `overleaf_smtp_port` | `587` | SMTP port (587 for STARTTLS) |
| `overleaf_smtp_secure` | `false` | Use SSL/TLS (false = STARTTLS) |
| `overleaf_smtp_user` | `""` | SMTP username (sensitive) |
| `overleaf_smtp_pass` | `""` | SMTP password/app password (sensitive) |
| `overleaf_smtp_tls_reject_unauth` | `true` | Reject unauthorized TLS certs |
| `overleaf_smtp_ignore_tls` | `false` | Ignore TLS (not recommended) |

**Gmail Setup:**
1. Enable 2-Step Verification on your Google account
2. Create an App Password at https://myaccount.google.com/apppasswords
3. Test credentials with: `python3 scripts/test_gmail_smtp.py`
4. Add credentials to `terraform.tfvars`

## Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────┐
│   AWS VPC  10.0.0.0/16                  │
│  ┌───────────────────────────────────┐  │
│  │  Public Subnet 10.0.1.0/24         │  │
│  │  ┌──────────────────────────────┐  │  │
│  │  │  EC2 Instance (Ubuntu)        │  │  │
│  │  │                               │  │  │
│  │  │  Docker Compose:              │  │  │
│  │  │  - web (Overleaf app)         │◄─┼──┼─── S3 Buckets (optional)
│  │  │  - mongo (MongoDB 8.0)        │  │  │    - user-files
│  │  │  - redis (cache)              │  │  │    - template-files
│  │  │  - clsi (LaTeX compiler)      │  │  │    - project-blobs
│  │  │  - filestore, history, etc.   │  │  │    - chunks
│  │  │                               │  │  │
│  │  │  EBS Volume (persistent)      │  │  │
│  │  │  - MongoDB data               │  │  │
│  │  └──────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

**Storage Options:**
- **EBS Only**: Data volume persists with `prevent_destroy` lifecycle
- **EBS + S3** (Recommended): Project files in S3, MongoDB on EBS
  - Enables easy migration and rebuilds without data loss
  - See [S3_STORAGE_GUIDE.md](./S3_STORAGE_GUIDE.md) for details

## Cost Estimate

### Compute & Storage
- **t3.xlarge** in us-east-1: ~$0.1664/hr (~$120/month)
- **50GB gp3 EBS**: ~$4/month

### S3 Storage (if enabled)
- **Storage**: ~$0.023/GB/month (~$1.15/month for 50GB)
- **Requests**: ~$1-2/month for typical usage
- **Total S3**: ~$2-3/month for small team

**Total (with S3)**: ~$126/month for continuous use

**Tip**: Run `terraform destroy` when not in use to save costs!
