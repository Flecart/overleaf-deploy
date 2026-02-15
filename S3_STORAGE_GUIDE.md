# S3 Storage Configuration Guide

This guide explains how to use S3 storage with your Overleaf Terraform deployment for data persistence across machine rebuilds.

## Why Use S3 Storage?

When you use S3 storage:
- **Data persists** even if you destroy and recreate your EC2 instance
- **Scalability** - S3 handles any amount of data without managing disk space
- **Reliability** - AWS S3 provides 99.999999999% (11 9's) durability
- **Flexibility** - Easy to migrate between instances or regions

Without S3, your data is stored on the EBS volume attached to the EC2 instance. While the EBS volume persists when you run `terraform destroy`, it can still be lost if you need to rebuild completely or migrate to a different setup.

## Architecture

The setup creates:

### 4 S3 Buckets
1. **`{prefix}-user-files`** - Project user files (uploaded files, images, etc.)
2. **`{prefix}-template-files`** - Template files
3. **`{prefix}-project-blobs`** - Project history blobs
4. **`{prefix}-chunks`** - History chunks

### 2 IAM Users with Restricted Permissions
1. **Filestore User** - Access to user-files, template-files, and read-only to project-blobs
2. **History User** - Access to project-blobs and chunks

All buckets are configured with:
- Block public access enabled (private buckets)
- Minimal required permissions following principle of least privilege
- Region-specific deployment

## Configuration

### 1. Enable S3 in terraform.tfvars

```hcl
# Enable S3 storage for data persistence
enable_s3_storage = true

# Choose a globally unique bucket prefix
# Will create: {prefix}-user-files, {prefix}-template-files, 
#              {prefix}-project-blobs, {prefix}-chunks
s3_bucket_prefix = "mycompany-overleaf-prod"
```

**Important**: S3 bucket names must be globally unique across all AWS accounts. Choose a descriptive prefix that's unlikely to conflict.

### 2. Configure AWS Region

Make sure your `aws_region` is set in `terraform.tfvars`:

```hcl
aws_region = "eu-central-1"  # Or your preferred region
```

The S3 buckets will be created in the same region as your EC2 instance for optimal latency.

## Deployment

### First Time Deployment

1. Set `enable_s3_storage = true` in your `terraform.tfvars`
2. Run `terraform apply`
3. Terraform will:
   - Create 4 S3 buckets
   - Create 2 IAM users with access keys
   - Configure Overleaf to use S3 storage
   - Block public access to all buckets

### Migrating from EBS to S3

If you already have an Overleaf instance running with local storage and want to migrate to S3:

**⚠️ Warning**: This will require downtime and careful migration of existing data.

#### Option 1: Fresh Start (Recommended if no critical data)
1. Set `enable_s3_storage = true`
2. Run `terraform destroy` (saves your EBS volume due to `prevent_destroy`)
3. Run `terraform apply` with S3 enabled
4. Start fresh with S3 storage

#### Option 2: Migrate Existing Data
1. Set `enable_s3_storage = true`
2. Run `terraform apply` to create S3 resources
3. Follow the [Overleaf S3 Migration Guide](https://docs.overleaf.com/on-premises/maintenance/s3-migration)
4. Manually copy data from EBS to S3 before switching

### Switching Back to Local Storage

To disable S3 and use local EBS storage:

1. Set `enable_s3_storage = false` in `terraform.tfvars`
2. Run `terraform apply`
3. **Note**: S3 buckets are NOT automatically deleted for safety
4. Manually delete S3 buckets if you no longer need them

## Verifying S3 Configuration

After deployment, verify the S3 setup:

### 1. Check Terraform Outputs

```bash
terraform output s3_storage_enabled
terraform output s3_buckets
```

### 2. SSH into the Instance

```bash
ssh -i your-key.pem ubuntu@<instance-ip>
```

### 3. Check Environment Variables

```bash
cd /opt/overleaf/develop
docker compose exec web env | grep S3
```

You should see:
```
OVERLEAF_FILESTORE_BACKEND=s3
OVERLEAF_FILESTORE_USER_FILES_BUCKET_NAME=your-prefix-user-files
OVERLEAF_FILESTORE_S3_REGION=your-region
...
```

### 4. Verify S3 Connectivity

Create a test project in Overleaf and upload a file. Then check your S3 bucket:

```bash
aws s3 ls s3://your-prefix-user-files/ --region your-region
```

## Cost Considerations

### S3 Storage Costs (us-east-1 pricing, 2026)
- **Storage**: ~$0.023/GB/month for Standard storage
- **Requests**: 
  - PUT/POST: $0.005 per 1,000 requests
  - GET: $0.0004 per 1,000 requests
- **Data Transfer**: 
  - IN: Free
  - OUT to internet: ~$0.09/GB (first 10 TB/month)
  - OUT to EC2 in same region: Free

### Example Cost Estimates

**Small Team (10 users, 50GB data)**
- Storage: 50GB × $0.023 = $1.15/month
- Requests: ~$1-2/month
- **Total: ~$2-3/month**

**Medium Team (50 users, 200GB data)**
- Storage: 200GB × $0.023 = $4.60/month
- Requests: ~$5-10/month
- **Total: ~$10-15/month**

**Large Team (500 users, 1TB data)**
- Storage: 1000GB × $0.023 = $23/month
- Requests: ~$20-40/month
- **Total: ~$50-70/month**

### EBS vs S3 Cost Comparison

**EBS Volume (50GB gp3)**
- Fixed cost: ~$4/month regardless of usage
- Limited to 50GB

**S3 (50GB actual usage)**
- Variable cost: ~$2-3/month
- Unlimited scalability
- Pay only for what you use

## Security Best Practices

1. **Private Buckets**: All buckets are configured with public access blocked
2. **Least Privilege**: IAM users have minimal required permissions
3. **Separate Credentials**: Filestore and History services use different IAM users
4. **Region-Locked**: Buckets are created in your specified region
5. **Encrypted in Transit**: All traffic uses HTTPS/TLS

### Rotating Access Keys

To rotate IAM access keys:

```bash
# 1. Create new keys in AWS Console for the IAM users
# 2. Update terraform.tfvars with enable_s3_storage = true
# 3. Run terraform apply to recreate resources
# 4. Or manually update via AWS CLI:

aws iam create-access-key --user-name overleaf-ai-tutor-filestore
aws iam delete-access-key --user-name overleaf-ai-tutor-filestore --access-key-id OLD_KEY_ID
```

## Troubleshooting

### Issue: "Access Denied" errors in logs

**Solution**: Check IAM permissions and bucket policies

```bash
# SSH into instance
cd /opt/overleaf/develop
docker compose logs web | grep -i "access denied"
docker compose logs filestore | grep -i "access denied"
```

Verify IAM policies match the required permissions.

### Issue: S3 bucket names already exist

**Solution**: S3 bucket names are globally unique. Change your `s3_bucket_prefix` to something unique:

```hcl
s3_bucket_prefix = "mycompany-overleaf-prod-20260215"
```

### Issue: Slow performance

**Solution**: Ensure your S3 buckets are in the same region as your EC2 instance:

```bash
terraform output s3_buckets
aws s3api get-bucket-location --bucket your-bucket-name
```

Cross-region latency can significantly impact performance.

### Issue: Data not appearing in S3

**Solution**: Check that environment variables are properly loaded:

```bash
cd /opt/overleaf/develop
docker compose exec web env | grep OVERLEAF_FILESTORE_BACKEND
```

Should show `s3`. If not, check `/opt/overleaf/.env` file.

## Backup and Recovery

### Backing Up S3 Data

S3 data is already highly durable (11 9's), but you may want additional backups:

```bash
# Enable S3 versioning for protection against accidental deletion
aws s3api put-bucket-versioning \
  --bucket your-prefix-user-files \
  --versioning-configuration Status=Enabled

# Or use S3 replication to another bucket/region
aws s3api put-bucket-replication \
  --bucket your-prefix-user-files \
  --replication-configuration file://replication.json
```

### Recovering from Disaster

If your EC2 instance is completely destroyed:

1. Keep your `terraform.tfstate` file safe
2. Run `terraform apply` again
3. Overleaf will automatically connect to existing S3 buckets
4. All data will be immediately available

## MongoDB Considerations

**Important**: MongoDB data is still stored locally on the EBS volume or instance, not in S3.

The S3 integration stores:
- ✅ Project files (LaTeX, uploaded images, etc.)
- ✅ Project history
- ✅ Templates
- ❌ MongoDB database (user accounts, project metadata)

To fully persist MongoDB:
- The EBS volume (`data_volume_size`) still handles MongoDB
- Consider separate MongoDB backups using `mongodump`
- Or use MongoDB Atlas for fully managed MongoDB

## Advanced Configuration

### Using Self-Hosted S3 (MinIO, Ceph)

To use a self-hosted S3-compatible service instead of AWS S3, you'll need to:

1. Add custom variables for endpoint and path style
2. Update the docker-compose.yml environment variables
3. Set `OVERLEAF_FILESTORE_S3_ENDPOINT` and `OVERLEAF_FILESTORE_S3_PATH_STYLE`

See the [Overleaf S3 documentation](https://docs.overleaf.com/on-premises/configuration/overleaf-toolkit/s3) for details.

### Lifecycle Policies

To automatically transition old data to cheaper storage:

```bash
# Example: Move files to Glacier after 90 days
aws s3api put-bucket-lifecycle-configuration \
  --bucket your-prefix-user-files \
  --lifecycle-configuration file://lifecycle.json
```

Example `lifecycle.json`:
```json
{
  "Rules": [
    {
      "Id": "Archive old files",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

## References

- [Overleaf S3 Configuration Documentation](https://docs.overleaf.com/on-premises/configuration/overleaf-toolkit/s3)
- [Overleaf S3 Migration Guide](https://docs.overleaf.com/on-premises/maintenance/s3-migration)
- [AWS S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
