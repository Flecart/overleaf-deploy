# Quick Start: Enable S3 Storage

This is a quick reference for enabling S3 storage. For complete documentation, see [S3_STORAGE_GUIDE.md](./S3_STORAGE_GUIDE.md).

## What You Get

✅ **Data persists** when you destroy and recreate your EC2 instance  
✅ **Unlimited scalability** without managing disk space  
✅ **99.999999999% durability** from AWS S3  
✅ **Cost-effective** - pay only for what you use (~$2-3/month for 50GB)  

## Enable S3 in 3 Steps

### 1. Edit terraform.tfvars

```hcl
# Enable S3 storage
enable_s3_storage = true

# Choose a globally unique bucket prefix
s3_bucket_prefix = "mycompany-overleaf-prod"
```

### 2. Apply Terraform

```bash
terraform apply
```

Terraform will create:
- 4 S3 buckets (user-files, template-files, project-blobs, chunks)
- 2 IAM users with minimal permissions
- Automatic Overleaf configuration

### 3. Verify (Optional)

```bash
# Check outputs
terraform output s3_storage_enabled
terraform output s3_buckets

# SSH and verify
ssh -i your-key.pem ubuntu@<instance-ip>
cd /opt/overleaf/develop
docker compose exec web env | grep S3
```

## What Gets Stored in S3?

| Data Type | Location |
|---|---|
| ✅ LaTeX project files | S3 |
| ✅ Uploaded images/files | S3 |
| ✅ Project history | S3 |
| ✅ Templates | S3 |
| ❌ MongoDB (user accounts) | EBS volume |

## Costs

**Example for 50GB data:**
- Storage: 50GB × $0.023/GB = $1.15/month
- Requests: ~$1-2/month
- **Total: ~$2-3/month**

Compare to EBS 50GB: ~$4/month (but limited to 50GB)

## Migrating Existing Data

**Already have Overleaf running?**

Choose one:
1. **Fresh start** (if no critical data): `terraform destroy` → `terraform apply` with S3 enabled
2. **Migrate data**: Follow the [detailed migration guide](./S3_STORAGE_GUIDE.md#migrating-from-ebs-to-s3)

## Troubleshooting

### Bucket name conflict
```
Error: Bucket name already exists
```
**Fix**: Choose a more unique prefix in `s3_bucket_prefix`

### Access denied errors
**Fix**: Check IAM permissions were created correctly
```bash
terraform output s3_filestore_credentials
```

### Slow performance
**Fix**: Ensure S3 buckets are in the same region as EC2
```bash
aws_region = "eu-central-1"  # Same for both
```

## Disable S3

To switch back to local storage:

```hcl
enable_s3_storage = false
```

Then `terraform apply`. S3 buckets are NOT deleted automatically for safety.

## Next Steps

- Read the full guide: [S3_STORAGE_GUIDE.md](./S3_STORAGE_GUIDE.md)
- Overleaf docs: https://docs.overleaf.com/on-premises/configuration/overleaf-toolkit/s3
- Set up bucket versioning for extra protection
- Configure lifecycle policies to reduce costs
