terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------------------------------------------------
# Data sources
# -------------------------------------------------------------------

# Latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# -------------------------------------------------------------------
# Networking — VPC, subnet, internet gateway, route table
# -------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -------------------------------------------------------------------
# Security group
# -------------------------------------------------------------------

resource "aws_security_group" "overleaf" {
  name        = "${var.project_name}-sg"
  description = "Allow HTTP, HTTPS, and SSH for Overleaf"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# -------------------------------------------------------------------
# Data volume (persists across terraform destroy/apply)
# -------------------------------------------------------------------
# TEMPORARILY DISABLED - Causing deployment issues
# resource "aws_ebs_volume" "overleaf_data" {
#   availability_zone = data.aws_availability_zones.available.names[0]
#   size              = var.data_volume_size
#   type              = "gp3"
#
#   tags = {
#     Name = "${var.project_name}-data"
#   }
#
#   # Prevent accidental deletion of data
#   lifecycle {
#     prevent_destroy = false
#   }
# }
#
# resource "aws_volume_attachment" "overleaf_data" {
#   device_name = "/dev/sdf"
#   volume_id   = aws_ebs_volume.overleaf_data.id
#   instance_id = aws_instance.overleaf.id
#
#   # Don't force detach on destroy (safer)
#   stop_instance_before_detaching = true
# }

# -------------------------------------------------------------------
# Elastic IP (stable IP for domain DNS)
# -------------------------------------------------------------------

resource "aws_eip" "overleaf" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

resource "aws_eip_association" "overleaf" {
  instance_id   = aws_instance.overleaf.id
  allocation_id = aws_eip.overleaf.id
}

# -------------------------------------------------------------------
# S3 Storage for Overleaf Data Persistence
# -------------------------------------------------------------------

# S3 Buckets for Overleaf data storage
resource "aws_s3_bucket" "user_files" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = "${var.s3_bucket_prefix}-user-files"

  tags = {
    Name        = "${var.project_name}-user-files"
    Description = "Overleaf project user files"
  }

  # Prevent accidental deletion of user data
}

resource "aws_s3_bucket" "template_files" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = "${var.s3_bucket_prefix}-template-files"

  tags = {
    Name        = "${var.project_name}-template-files"
    Description = "Overleaf template files"
  }

  # Prevent accidental deletion of template data
}

resource "aws_s3_bucket" "project_blobs" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = "${var.s3_bucket_prefix}-project-blobs"

  tags = {
    Name        = "${var.project_name}-project-blobs"
    Description = "Overleaf project history blobs"
  }

  # Prevent accidental deletion of project history
}

resource "aws_s3_bucket" "chunks" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = "${var.s3_bucket_prefix}-chunks"

  tags = {
    Name        = "${var.project_name}-chunks"
    Description = "Overleaf history chunks"
  }

  # Prevent accidental deletion of history chunks
}

# Block public access to all S3 buckets
resource "aws_s3_bucket_public_access_block" "user_files" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.user_files[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "template_files" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.template_files[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "project_blobs" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.project_blobs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "chunks" {
  count  = var.enable_s3_storage ? 1 : 0
  bucket = aws_s3_bucket.chunks[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM user for filestore service
resource "aws_iam_user" "filestore" {
  count = var.enable_s3_storage ? 1 : 0
  name  = "${var.project_name}-filestore"

  tags = {
    Name        = "${var.project_name}-filestore"
    Description = "IAM user for Overleaf filestore service"
  }

  # Prevent accidental deletion to maintain stable credentials
}

resource "aws_iam_access_key" "filestore" {
  count = var.enable_s3_storage ? 1 : 0
  user  = aws_iam_user.filestore[0].name
}

# IAM policy for filestore user
resource "aws_iam_user_policy" "filestore" {
  count = var.enable_s3_storage ? 1 : 0
  name  = "${var.project_name}-filestore-policy"
  user  = aws_iam_user.filestore[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.user_files[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.user_files[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.project_blobs[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.template_files[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.template_files[0].arn}/*"
      }
    ]
  })
}

# IAM user for history service
resource "aws_iam_user" "history" {
  count = var.enable_s3_storage ? 1 : 0
  name  = "${var.project_name}-history"

  tags = {
    Name        = "${var.project_name}-history"
    Description = "IAM user for Overleaf history service"
  }

  # Prevent accidental deletion to maintain stable credentials
}

resource "aws_iam_access_key" "history" {
  count = var.enable_s3_storage ? 1 : 0
  user  = aws_iam_user.history[0].name
}

# IAM policy for history user
resource "aws_iam_user_policy" "history" {
  count = var.enable_s3_storage ? 1 : 0
  name  = "${var.project_name}-history-policy"
  user  = aws_iam_user.history[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.project_blobs[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.project_blobs[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.chunks[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.chunks[0].arn}/*"
      }
    ]
  })
}

# -------------------------------------------------------------------
# EC2 instance
# -------------------------------------------------------------------

resource "aws_instance" "overleaf" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.overleaf.id]

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    ADMIN_EMAIL                           = var.admin_email
    USE_PREBUILT_IMAGES                   = var.use_prebuilt_images
    DOCKER_IMAGE_PREFIX                   = var.docker_image_prefix
    DOCKER_IMAGE_TAG                      = var.docker_image_tag
    OVERLEAF_EMAIL_FROM_ADDRESS           = var.overleaf_email_from_address
    OVERLEAF_EMAIL_SMTP_HOST              = var.overleaf_smtp_host
    OVERLEAF_EMAIL_SMTP_PORT              = var.overleaf_smtp_port
    OVERLEAF_EMAIL_SMTP_SECURE            = var.overleaf_smtp_secure
    OVERLEAF_EMAIL_SMTP_USER              = var.overleaf_smtp_user
    OVERLEAF_EMAIL_SMTP_PASS              = var.overleaf_smtp_pass
    OVERLEAF_EMAIL_SMTP_TLS_REJECT_UNAUTH = var.overleaf_smtp_tls_reject_unauth
    OVERLEAF_EMAIL_SMTP_IGNORE_TLS        = var.overleaf_smtp_ignore_tls
    EMAIL_CONFIRMATION_DISABLED           = var.email_confirmation_disabled
    SHARELATEX_ALLOWED_EMAIL_DOMAINS      = var.allowed_email_domains
    # S3 configuration
    ENABLE_S3_STORAGE              = var.enable_s3_storage
    AWS_REGION                     = var.aws_region
    S3_USER_FILES_BUCKET           = var.enable_s3_storage ? aws_s3_bucket.user_files[0].id : ""
    S3_TEMPLATE_FILES_BUCKET       = var.enable_s3_storage ? aws_s3_bucket.template_files[0].id : ""
    S3_PROJECT_BLOBS_BUCKET        = var.enable_s3_storage ? aws_s3_bucket.project_blobs[0].id : ""
    S3_CHUNKS_BUCKET               = var.enable_s3_storage ? aws_s3_bucket.chunks[0].id : ""
    S3_FILESTORE_ACCESS_KEY_ID     = var.enable_s3_storage ? aws_iam_access_key.filestore[0].id : ""
    S3_FILESTORE_SECRET_ACCESS_KEY = var.enable_s3_storage ? aws_iam_access_key.filestore[0].secret : ""
    S3_HISTORY_ACCESS_KEY_ID       = var.enable_s3_storage ? aws_iam_access_key.history[0].id : ""
    S3_HISTORY_SECRET_ACCESS_KEY   = var.enable_s3_storage ? aws_iam_access_key.history[0].secret : ""
  })

  # user_data changes should trigger replacement
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-ec2"
  }

  # The build takes a while; extend the creation timeout
  timeouts {
    create = "30m"
  }
}
