# AWS Cost Report - Overleaf Terraform Setup
**Region:** eu-central-1 (Europe - Frankfurt)
**Generated:** 2026-02-15
**Configuration Based On:** terraform.tfvars.example

---

## Summary

| Category | Daily Cost | Monthly Cost (30 days) |
|----------|-----------|------------------------|
| **EC2 Instance** | $1.33 | $39.90 |
| **EBS Storage** | $0.24 | $7.20 |
| **Elastic IP** | $0.12 | $3.60 |
| **S3 Storage** | Variable* | Variable* |
| **VPC & Networking** | $0.00 | $0.00 |
| **IAM Resources** | $0.00 | $0.00 |
| **TOTAL (excluding S3)** | **$1.69** | **$50.70** |

*S3 costs depend on actual storage usage - see detailed breakdown below

---

## Detailed Resource Breakdown

### 1. EC2 Instance (aws_instance.overleaf)

**Instance Type:** t3.medium
**Specifications:** 2 vCPU, 4 GB RAM, up to 5 Gbps bandwidth

| Metric | Value |
|--------|-------|
| Hourly Rate | $0.0554 |
| Daily Cost | $1.33 |
| Monthly Cost | $39.90 |

**AWS Pricing Links:**
- [EC2 On-Demand Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [t3.medium Instance Details - Vantage](https://instances.vantage.sh/aws/ec2/t3.medium)
- [AWS Pricing Calculator](https://calculator.aws/)

**Notes:**
- This is for Linux on-demand instances
- No long-term commitment required
- Pricing is per hour with a minimum of 60 seconds

---

### 2. EBS Volumes

#### Root Volume (attached to EC2)
**Type:** gp3
**Size:** 40 GB
**Provisioned IOPS:** 3,000 (included free)
**Provisioned Throughput:** 125 MB/s (included free)

| Metric | Value |
|--------|-------|
| Storage Cost per GB-month | €0.09394 (~$0.0986*) |
| Daily Cost | $0.13 |
| Monthly Cost | $3.94 |

#### Data Volume (aws_ebs_volume.overleaf_data)
**Type:** gp3
**Size:** 50 GB
**Provisioned IOPS:** 3,000 (included free)
**Provisioned Throughput:** 125 MB/s (included free)
**Lifecycle:** Persists across `terraform destroy` (prevent_destroy = false but intended for data persistence)

| Metric | Value |
|--------|-------|
| Storage Cost per GB-month | €0.09394 (~$0.0986*) |
| Daily Cost | $0.16 |
| Monthly Cost | $4.93 |

#### Combined EBS Costs
| Total Storage | Daily Cost | Monthly Cost |
|---------------|-----------|--------------|
| 90 GB | $0.24 | $7.20** |

**AWS Pricing Links:**
- [EBS Pricing](https://aws.amazon.com/ebs/pricing/)
- [EBS General Purpose (gp3) Volumes](https://aws.amazon.com/ebs/general-purpose/)
- [EBS Pricing Calculator](https://cloudburn.io/tools/amazon-ebs-pricing-calculator)

**Notes:**
- gp3 volumes include baseline performance of 3,000 IOPS and 125 MB/s throughput at no extra cost
- Additional IOPS: €0.00592 per provisioned IOPS-month (beyond 3,000)
- Additional throughput: €0.04697 per provisioned MB/s-month (beyond 125 MB/s)
- *EUR to USD conversion rate: ~1.05 (approximate)
- **Based on €0.09394/GB-month pricing for EU regions

---

### 3. Elastic IP (aws_eip.overleaf)

**Type:** IPv4 Public Address
**Status:** Associated with EC2 instance

| Metric | Value |
|--------|-------|
| Hourly Rate | $0.005 |
| Daily Cost | $0.12 |
| Monthly Cost | $3.60 |

**AWS Pricing Links:**
- [VPC Pricing (includes Elastic IP)](https://aws.amazon.com/vpc/pricing/)
- [AWS Public IPv4 Address Charge Announcement](https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/)
- [Elastic IP Cost Guide](https://financesumit.com/aws-elastic-ip-cost-price-range-savings/)

**Notes:**
- Charged hourly whether associated or idle
- Standard rate across all AWS regions: $0.005/hour
- Effective since February 1, 2024
- Free tier: 750 hours of public IPv4 address usage per month (first 12 months only)

---

### 4. S3 Storage (Conditional - enabled when enable_s3_storage = true)

**Buckets Created:** 4
1. `${s3_bucket_prefix}-user-files` - Overleaf project user files
2. `${s3_bucket_prefix}-template-files` - Overleaf template files
3. `${s3_bucket_prefix}-project-blobs` - Overleaf project history blobs
4. `${s3_bucket_prefix}-chunks` - Overleaf history chunks

**Storage Class:** S3 Standard
**Region:** eu-central-1

#### Pricing Structure

| Storage Tier | Price per GB-month |
|--------------|-------------------|
| First 50 TB | $0.0245 |
| Next 450 TB | $0.0235 |
| Over 500 TB | $0.0225 |

**Daily Cost Calculation:**
- Cost per GB-day: $0.0245 ÷ 30 = $0.000817
- For 10 GB: $0.008/day or $0.245/month
- For 100 GB: $0.082/day or $2.45/month
- For 1 TB: $0.817/day or $24.50/month

**Additional S3 Costs (not included in estimates):**
- **PUT/COPY/POST/LIST requests:** $0.0054 per 1,000 requests
- **GET/SELECT requests:** $0.00043 per 1,000 requests
- **Data transfer OUT to internet:**
  - First 1 GB/month: Free
  - Up to 10 TB/month: $0.09/GB
  - Next 40 TB/month: $0.085/GB
  - Over 150 TB/month: $0.07/GB
- **Data transfer IN from internet:** Free

**AWS Pricing Links:**
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [S3 Pricing Calculator](https://cloudburn.io/tools/amazon-s3-pricing-calculator)
- [AWS S3 Pricing Guide 2026](https://www.hyperglance.com/blog/aws-s3-pricing-guide/)

**Notes:**
- Storage costs are variable and depend on actual usage
- S3 charges for storage, requests, and data transfer
- Pricing shown is for S3 Standard storage class in eu-central-1
- Based on September 2025 pricing data ($0.0245/GB for eu-central-1)

---

### 5. IAM Resources (No Cost)

**Resources Created (when enable_s3_storage = true):**
- 2 IAM Users:
  - `${project_name}-filestore` - For Overleaf filestore service
  - `${project_name}-history` - For Overleaf history service
- 2 IAM Access Keys (1 per user)
- 2 IAM Policies (inline policies attached to users)

**Cost:** $0.00 (IAM users and policies are free)

**AWS Pricing Links:**
- [AWS IAM Pricing](https://aws.amazon.com/iam/pricing/) - Free service

---

### 6. VPC & Networking (No Cost)

**Resources Created:**
- 1 VPC (aws_vpc.main) - CIDR: 10.0.0.0/16
- 1 Internet Gateway (aws_internet_gateway.main)
- 1 Public Subnet (aws_subnet.public) - CIDR: 10.0.1.0/24
- 1 Route Table (aws_route_table.public)
- 1 Route Table Association
- 1 Security Group (aws_security_group.overleaf)
  - Ingress: SSH (22), HTTP (80), HTTPS (443)
  - Egress: All traffic

**Cost:** $0.00

**AWS Pricing Links:**
- [VPC Pricing](https://aws.amazon.com/vpc/pricing/)

**Notes:**
- VPC, subnets, route tables, internet gateways, and security groups are free
- Data transfer charges may apply (see data transfer pricing)
- VPC endpoints, NAT gateways, and VPN connections incur additional costs (not used in this setup)

---

## Cost Optimization Recommendations

### 1. EC2 Instance
- **Consider Reserved Instances:** Save up to 72% with 1-year or 3-year commitments
- **Use Savings Plans:** Flexible pricing model with up to 66% savings
- **Right-size the instance:** Monitor actual CPU/memory usage and downgrade if possible
  - t3.small (2GB RAM): $0.0277/hr = $0.66/day (50% savings)
  - Consider t3.medium only during build; use smaller instance for runtime

### 2. EBS Storage
- **Monitor actual usage:** Delete or resize volumes if over-provisioned
- **Use lifecycle policies:** Archive old snapshots (if created)
- **Consider Throughput Optimized (st1):** $0.045/GB-month for data volume (if sequential access pattern)

### 3. Elastic IP
- **Release when not in use:** If testing/development, release IP when instance is stopped
- **Use IPv6:** IPv6 addresses are free (requires application support)

### 4. S3 Storage
- **Use S3 Lifecycle Policies:**
  - Move old files to S3 Intelligent-Tiering (saves up to 68%)
  - Archive to Glacier for long-term storage (saves up to 95%)
- **Enable S3 Intelligent-Tiering:** Automatic cost optimization for unpredictable access patterns
- **Monitor request patterns:** High request volumes can increase costs significantly

### 5. Use AWS Budgets
- Set up cost alerts to monitor spending
- Enable AWS Cost Explorer for detailed cost analysis

---

## Estimated Monthly Costs by Usage Scenario

### Scenario 1: Light Usage (Testing/Development)
| Resource | Cost |
|----------|------|
| t3.medium EC2 | $39.90 |
| 90 GB gp3 EBS | $7.20 |
| Elastic IP | $3.60 |
| S3 (10 GB) | $0.25 |
| **Total** | **$50.95/month** |

### Scenario 2: Moderate Usage (Small Team)
| Resource | Cost |
|----------|------|
| t3.medium EC2 | $39.90 |
| 90 GB gp3 EBS | $7.20 |
| Elastic IP | $3.60 |
| S3 (100 GB) | $2.45 |
| Data Transfer (5 GB out) | $0.45 |
| **Total** | **$53.60/month** |

### Scenario 3: Heavy Usage (Production)
| Resource | Cost |
|----------|------|
| t3.medium EC2 | $39.90 |
| 90 GB gp3 EBS | $7.20 |
| Elastic IP | $3.60 |
| S3 (1 TB) | $24.50 |
| Data Transfer (50 GB out) | $4.50 |
| S3 Requests (~1M) | $0.50 |
| **Total** | **$80.20/month** |

---

## Additional Costs to Consider

### Data Transfer Costs
**Out to Internet from eu-central-1:**
- First 1 GB/month: Free
- Up to 10 TB/month: $0.09/GB
- Next 40 TB/month: $0.085/GB
- Over 150 TB/month: $0.07/GB

**Data Transfer Links:**
- [EC2 Data Transfer Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [AWS Data Transfer Pricing](https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer)

### Snapshot Costs (if enabled)
- EBS Snapshots: $0.05/GB-month
- Incremental snapshots only charge for changed blocks

---

## References

### Official AWS Pricing Pages
- [EC2 On-Demand Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [EBS Pricing](https://aws.amazon.com/ebs/pricing/)
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [VPC Pricing](https://aws.amazon.com/vpc/pricing/)
- [AWS Pricing Calculator](https://calculator.aws/)

### Third-Party Pricing Tools
- [Vantage - EC2 Instance Comparison](https://instances.vantage.sh/)
- [CloudPrice - Regional Pricing](https://cloudprice.net/aws/ec2)
- [Cloud Burn - EBS Pricing Calculator](https://cloudburn.io/tools/amazon-ebs-pricing-calculator)
- [EBS Pricing by Region](https://cloudkeep-io.github.io/ebs-pricing/)

### Cost Optimization Guides
- [AWS S3 Pricing Guide 2026](https://www.hyperglance.com/blog/aws-s3-pricing-guide/)
- [AWS GP2 vs GP3 Savings Guide](https://cloudfix.com/blog/aws-gp2-vs-gp3/)
- [Elastic IP Cost Guide](https://www.economize.cloud/blog/ec2-elastic-ip-address-pricing/)

---

## Notes

1. **Currency:** All prices in USD unless otherwise noted. European pricing often quoted in EUR (€0.09394/GB-month for gp3).
2. **Pricing Date:** Pricing current as of February 2026. AWS prices are subject to change.
3. **Region:** All pricing is for eu-central-1 (Europe - Frankfurt) region.
4. **Taxes:** Prices exclude VAT and other applicable taxes.
5. **Free Tier:** New AWS accounts receive 12 months of free tier benefits (750 hours t2.micro, 30GB EBS, etc.) - not applicable to this setup using t3.medium.
6. **Variable Costs:** S3 storage and data transfer costs vary based on actual usage and cannot be precisely estimated without usage patterns.

---

**Configuration Source:** `/terraform.tfvars.example`
**Last Updated:** 2026-02-15
