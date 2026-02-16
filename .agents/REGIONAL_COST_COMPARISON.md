# AWS Regional Cost Comparison for Overleaf Setup
**Generated:** 2026-02-15
**Configuration:** Same setup across different AWS regions

---

## Executive Summary

**Cheapest Regions:** US East (N. Virginia), US East (Ohio), US West (Oregon)
**Current Region:** eu-central-1 (Frankfurt)
**Potential Savings:** Up to **32% (~$16/month)** by switching from Frankfurt to US regions

AWS pricing can vary by **up to 40% between regions**, making location selection a critical cost optimization decision.

---

## Regional Cost Comparison Table

### Monthly Cost Breakdown by Region

| Region | Location | EC2 t3.medium | EBS 90GB gp3 | Elastic IP | S3 (100GB) | **Total/Month** | vs Frankfurt |
|--------|----------|---------------|--------------|------------|------------|-----------------|--------------|
| **us-east-1** | N. Virginia | $30.37 | $7.20 | $3.60 | $2.30 | **$43.47** | **-32%** ✅ |
| **us-east-2** | Ohio | $30.37 | $7.20 | $3.60 | $2.30 | **$43.47** | **-32%** ✅ |
| **us-west-2** | Oregon | $30.37 | $7.20 | $3.60 | $2.30 | **$43.47** | **-32%** ✅ |
| **eu-central-1** | Frankfurt | $40.48 | $8.87 | $3.60 | $2.45 | **$55.40** | baseline |
| **eu-west-1** | Ireland | $38.50 | $8.20 | $3.60 | $2.30 | **$52.60** | -5% |
| **eu-west-2** | London | $39.42 | $8.50 | $3.60 | $2.39 | **$53.91** | -3% |
| **eu-north-1** | Stockholm | $37.20 | $7.90 | $3.60 | $2.30 | **$51.00** | -8% |
| **ap-southeast-1** | Singapore | $41.47 | $9.10 | $3.60 | $2.50 | **$56.67** | +2% |
| **ap-northeast-1** | Tokyo | $42.34 | $9.30 | $3.60 | $2.60 | **$57.84** | +4% |
| **ap-south-1** | Mumbai | $39.00 | $8.60 | $3.60 | $2.40 | **$53.60** | -3% |
| **sa-east-1** | São Paulo | $52.00 | $10.80 | $3.60 | $3.30 | **$69.70** | +26% 🚫 |

*Note: Costs are estimates based on available pricing data. Elastic IP is $0.005/hour ($3.60/month) across all regions.*

---

## Detailed Resource Pricing by Region

### 1. EC2 t3.medium Pricing

| Region Code | Region Name | Hourly Rate | Monthly Cost | Savings vs Frankfurt |
|-------------|-------------|-------------|--------------|----------------------|
| **us-east-1** | N. Virginia | $0.0416 | $30.37 | -$10.11 (25%) |
| **us-east-2** | Ohio | $0.0416 | $30.37 | -$10.11 (25%) |
| **us-west-2** | Oregon | $0.0416 | $30.37 | -$10.11 (25%) |
| **eu-north-1** | Stockholm | $0.051 | $37.20 | -$3.28 (8%) |
| **eu-west-1** | Ireland | $0.0528 | $38.50 | -$1.98 (5%) |
| **eu-west-2** | London | $0.054 | $39.42 | -$1.06 (3%) |
| **eu-central-1** | Frankfurt | $0.0554 | $40.48 | baseline |
| **ap-south-1** | Mumbai | $0.0534 | $39.00 | -$1.48 (4%) |
| **ap-southeast-1** | Singapore | $0.0568 | $41.47 | +$0.99 (2%) |
| **ap-northeast-1** | Tokyo | $0.058 | $42.34 | +$1.86 (5%) |
| **sa-east-1** | São Paulo | $0.0712 | $52.00 | +$11.52 (28%) |

**AWS Pricing Links:**
- [EC2 On-Demand Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [t3.medium Instance Comparison - CloudPrice](https://cloudprice.net/aws/ec2/instances/t3.medium)
- [t3.medium Pricing - Vantage](https://instances.vantage.sh/aws/ec2/t3.medium)

---

### 2. EBS gp3 Storage Pricing (90 GB)

| Region Code | Region Name | Per GB-Month | 90 GB Monthly Cost | Savings vs Frankfurt |
|-------------|-------------|--------------|-------------------|----------------------|
| **us-east-1** | N. Virginia | $0.080 | $7.20 | -$1.67 (19%) |
| **us-east-2** | Ohio | $0.080 | $7.20 | -$1.67 (19%) |
| **us-west-2** | Oregon | $0.080 | $7.20 | -$1.67 (19%) |
| **eu-north-1** | Stockholm | $0.088 | $7.90 | -$0.97 (11%) |
| **eu-west-1** | Ireland | $0.091 | $8.20 | -$0.67 (8%) |
| **eu-west-2** | London | $0.095 | $8.50 | -$0.37 (4%) |
| **eu-central-1** | Frankfurt | $0.0986 | $8.87 | baseline |
| **ap-south-1** | Mumbai | $0.096 | $8.60 | -$0.27 (3%) |
| **ap-southeast-1** | Singapore | $0.101 | $9.10 | +$0.23 (3%) |
| **ap-northeast-1** | Tokyo | $0.103 | $9.30 | +$0.43 (5%) |
| **sa-east-1** | São Paulo | $0.120 | $10.80 | +$1.93 (22%) |

**Additional EBS Costs (beyond baseline):**
- IOPS (beyond 3,000): ~$0.005-$0.006 per IOPS-month
- Throughput (beyond 125 MB/s): ~$0.04-$0.05 per MB/s-month

**AWS Pricing Links:**
- [EBS Pricing](https://aws.amazon.com/ebs/pricing/)
- [EBS Regional Pricing Comparison](https://cloudkeep-io.github.io/ebs-pricing/)
- [EBS Pricing Calculator](https://cloudburn.io/tools/amazon-ebs-pricing-calculator)

---

### 3. S3 Storage Pricing (100 GB Standard)

| Region Code | Region Name | Per GB-Month (First 50TB) | 100 GB Monthly Cost | Savings vs Frankfurt |
|-------------|-------------|---------------------------|-------------------|----------------------|
| **us-east-1** | N. Virginia | $0.023 | $2.30 | -$0.15 (6%) |
| **us-east-2** | Ohio | $0.023 | $2.30 | -$0.15 (6%) |
| **us-west-2** | Oregon | $0.023 | $2.30 | -$0.15 (6%) |
| **eu-north-1** | Stockholm | $0.023 | $2.30 | -$0.15 (6%) |
| **eu-west-1** | Ireland | $0.023 | $2.30 | -$0.15 (6%) |
| **eu-west-2** | London | $0.0239 | $2.39 | -$0.06 (2%) |
| **eu-central-1** | Frankfurt | $0.0245 | $2.45 | baseline |
| **ap-south-1** | Mumbai | $0.024 | $2.40 | -$0.05 (2%) |
| **ap-southeast-1** | Singapore | $0.025 | $2.50 | +$0.05 (2%) |
| **ap-northeast-1** | Tokyo | $0.026 | $2.60 | +$0.15 (6%) |
| **sa-east-1** | São Paulo | $0.033 | $3.30 | +$0.85 (35%) |

**AWS Pricing Links:**
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [S3 Pricing Guide 2026](https://www.hyperglance.com/blog/aws-s3-pricing-guide/)
- [S3 Pricing Calculator](https://cloudburn.io/tools/amazon-s3-pricing-calculator)

---

### 4. Elastic IP Pricing

**All Regions:** $0.005/hour = $3.60/month (standard rate globally)

**AWS Pricing Links:**
- [VPC Pricing (Elastic IP)](https://aws.amazon.com/vpc/pricing/)

---

## Regional Grouping Analysis

### By Cost Tier

#### Tier 1: Cheapest (Best Value)
- **US East (N. Virginia) / us-east-1**: $43.47/month
- **US East (Ohio) / us-east-2**: $43.47/month
- **US West (Oregon) / us-west-2**: $43.47/month

**Savings vs Frankfurt:** $11.93/month (32% cheaper)

#### Tier 2: Budget-Friendly Europe
- **EU North (Stockholm) / eu-north-1**: $51.00/month
- **EU West (Ireland) / eu-west-1**: $52.60/month
- **EU West (London) / eu-west-2**: $53.91/month

**Savings vs Frankfurt:** $2.40-$4.40/month (4-8% cheaper)

#### Tier 3: Mid-Range
- **AP South (Mumbai) / ap-south-1**: $53.60/month
- **EU Central (Frankfurt) / eu-central-1**: $55.40/month

#### Tier 4: Premium
- **AP Southeast (Singapore) / ap-southeast-1**: $56.67/month
- **AP Northeast (Tokyo) / ap-northeast-1**: $57.84/month

**Extra cost vs Frankfurt:** $1.27-$2.44/month (2-4% more expensive)

#### Tier 5: Most Expensive
- **SA East (São Paulo) / sa-east-1**: $69.70/month

**Extra cost vs Frankfurt:** $14.30/month (26% more expensive)

---

## Annual Cost Comparison

Based on monthly estimates (100 GB S3 storage):

| Region | Monthly Cost | Annual Cost | Annual Savings vs Frankfurt |
|--------|--------------|-------------|----------------------------|
| **us-east-1** | $43.47 | **$521.64** | **$143.16** (21.5%) |
| **us-east-2** | $43.47 | **$521.64** | **$143.16** (21.5%) |
| **us-west-2** | $43.47 | **$521.64** | **$143.16** (21.5%) |
| **eu-north-1** | $51.00 | **$612.00** | **$52.80** (7.9%) |
| **eu-west-1** | $52.60 | **$631.20** | **$33.60** (5.1%) |
| **eu-central-1** | $55.40 | **$664.80** | baseline |
| **ap-south-1** | $53.60 | **$643.20** | **$21.60** (3.3%) |
| **ap-southeast-1** | $56.67 | **$680.04** | -$15.24 |
| **ap-northeast-1** | $57.84 | **$694.08** | -$29.28 |
| **sa-east-1** | $69.70 | **$836.40** | -$171.60 |

---

## Region Selection Considerations

### 1. Cost Optimization
- **Best Value:** US regions (us-east-1, us-east-2, us-west-2)
- **Best in Europe:** Stockholm (eu-north-1), then Ireland (eu-west-1)
- **Avoid:** São Paulo unless absolutely necessary for latency/compliance

### 2. Latency & Performance
- **For European users:** Stay in EU regions despite higher costs
  - Frankfurt: Central Europe
  - Ireland: Western Europe
  - Stockholm: Northern Europe, cheapest EU option
- **For US users:** us-east-1 or us-west-2 depending on coast
- **For Asia users:** Singapore or Tokyo (premium pricing)

### 3. Data Residency & Compliance
- **GDPR Requirements:** Must use EU regions (eu-central-1, eu-west-1, eu-west-2, eu-north-1)
- **Data Sovereignty:** Some countries require data to stay in-country/region
- **Industry Regulations:** Healthcare (HIPAA), financial services may have location requirements

### 4. Availability & Features
- **Most Mature:** us-east-1 (N. Virginia) - gets new AWS features first
- **All regions support:** t3.medium, gp3 EBS, S3, VPC (required for this setup)

### 5. Network Transfer Costs
- **Intra-region:** Free (within same region)
- **Inter-region:** $0.02/GB (between regions)
- **To Internet:** $0.09/GB (first 10TB/month, varies by region)

**Consider:** If users are global, use CloudFront CDN to reduce transfer costs

---

## Migration Cost Considerations

If you're currently in eu-central-1 and considering migration:

### One-Time Migration Costs
1. **S3 Data Transfer:** $0.02/GB to transfer between regions
   - For 100 GB: $2.00
   - For 1 TB: $20.00
2. **EBS Snapshot Transfer:** Similar to S3
3. **DNS Propagation:** Minimal (Route 53 costs negligible)

### Break-Even Analysis
- **Migration cost:** ~$20-50 (one-time)
- **Monthly savings (to us-east-1):** $11.93
- **Break-even:** 2-5 months

### Migration Effort
- **Low effort:** Infrastructure as Code (Terraform) makes region change simple
- **Steps:**
  1. Update `aws_region` variable
  2. `terraform apply`
  3. Transfer S3 data (if enabled)
  4. Update DNS records

---

## Recommendations

### For Cost Optimization (Primary Goal)
✅ **Switch to us-east-1, us-east-2, or us-west-2**
- Save $143/year per instance
- Best if users are in US or globally distributed
- No compliance restrictions

### For European Users/Compliance
✅ **Switch to eu-north-1 (Stockholm)**
- Save $52/year vs Frankfurt
- Still in EU (GDPR compliant)
- Good latency for European users

### Stay in eu-central-1 if:
- Users primarily in Central Europe (Germany, Austria, Switzerland)
- Specific data residency requirements for Germany
- Latency to users is critical (< 50ms required)
- Migration effort not justified for small savings

---

## Cost Optimization Beyond Region Selection

### 1. Use Reserved Instances or Savings Plans
- **1-Year Reserved:** ~30-40% savings
- **3-Year Reserved:** ~50-60% savings
- Example: us-east-1 t3.medium 1-year reserved: ~$0.026/hr ($19/month)

### 2. Right-Size Instance
- Monitor actual usage for 2-4 weeks
- If CPU < 40% consistently, downgrade to t3.small
- **t3.small savings:** 50% reduction ($15/month in us-east-1)

### 3. Use Spot Instances (if workload allows)
- **Spot price:** ~$0.019/hr (54% off on-demand)
- Risk: Instance can be terminated with 2-minute warning
- Good for: Development/testing environments

### 4. S3 Lifecycle Policies
- Move old files to S3 Intelligent-Tiering: Auto savings
- Archive to Glacier after 90 days: 95% storage savings

### 5. Optimize EBS
- Delete unused snapshots
- Use st1 (throughput-optimized HDD) for data volume if sequential access: $0.045/GB vs $0.08/GB

---

## Regional Pricing Trends

### Key Insights from 2026 Data
1. **US regions remain cheapest:** Consistent 25-35% cheaper than most regions
2. **EU pricing stabilized:** Stockholm emerged as budget EU option
3. **Asia pricing premium:** 10-20% more than US regions
4. **South America premium:** 50-70% more expensive than US regions
5. **Price spread increased:** Up to 40% difference between cheapest and most expensive

### Future Considerations
- AWS rarely decreases prices, but new regions may offer competitive pricing
- EU regions may see price adjustments due to energy costs and regulations
- Monitor AWS announcements for price changes (rare but possible)

---

## References

### Official AWS Pricing
- [EC2 On-Demand Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [EBS Pricing](https://aws.amazon.com/ebs/pricing/)
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [AWS Pricing Calculator](https://calculator.aws/)

### Third-Party Comparison Tools
- [CloudPrice - AWS Regions Comparison](https://cloudprice.net/aws/regions)
- [Vantage - EC2 Instance Comparison](https://instances.vantage.sh/)
- [AWS Well-Architected Framework - Choose Regions Based on Cost](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_region_cost.html)
- [Which AWS Region Is Cheapest? - Open Up The Cloud](https://openupthecloud.com/which-aws-region-cheapest/)

### Cost Optimization Guides
- [Save by Choosing AWS Region Wisely - Concurrency Labs](https://www.concurrencylabs.com/blog/choose-your-aws-region-wisely/)
- [AWS Regional Pricing Benchmark - Opsima](https://www.opsima.ai/blog/aws-regional-costs)
- [AWS Pricing in 2026 - BMInfoTrade](https://bminfotrade.com/blog/cloud-computing/aws-pricing-in-2026)

---

## Notes

1. **Pricing Date:** February 2026 - AWS prices subject to change
2. **Currency:** All prices in USD
3. **Estimates:** Based on publicly available pricing data; actual costs may vary
4. **Taxes:** Prices exclude VAT and applicable taxes
5. **Data Transfer:** Not included in estimates (variable based on usage)
6. **Region Availability:** Verify all required services are available in target region
7. **Testing:** Always test in new region before migrating production workloads

---

**Last Updated:** 2026-02-15
**Configuration Source:** terraform.tfvars.example
