variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type. Overleaf needs at least 4GB RAM; t3.xlarge (16GB) recommended for building from source."
  type        = string
  default     = "t3.xlarge"
}

variable "key_name" {
  description = "Name of an existing AWS EC2 Key Pair for SSH access"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB (Overleaf + TexLive needs ~30GB+)"
  type        = number
  default     = 50
}

variable "admin_email" {
  description = "Email address for the initial Overleaf admin user"
  type        = string
  default     = "admin@example.com"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "overleaf-ai-tutor"
}

# -------------------------------------------------------------------
# Pre-built images (faster deployment: ~2-5 min vs 10-20 min build)
# -------------------------------------------------------------------

variable "use_prebuilt_images" {
  description = "Pull pre-built images from a registry instead of building on EC2. Set docker_image_prefix and push images first (see scripts/build-and-push.sh)."
  type        = bool
  default     = false
}

variable "docker_image_prefix" {
  description = "Docker image prefix for pre-built images (e.g. 'flecart/overleaf' for flecart/overleaf-web:tag)"
  type        = string
  default     = ""
}

variable "docker_image_tag" {
  description = "Tag for pre-built images (e.g. 'ai-tutor' or 'latest')"
  type        = string
  default     = "ai-tutor"
}

variable "data_volume_size" {
  description = "Size of the persistent data volume in GB (stores MongoDB, uploads, project files). This volume persists across terraform destroy."
  type        = number
  default     = 50
}

# -------------------------------------------------------------------
# Email / SMTP Configuration
# -------------------------------------------------------------------

variable "overleaf_email_from_address" {
  description = "Email address to send emails from (e.g. 'noreply@example.com')"
  type        = string
  default     = ""
}

variable "overleaf_smtp_host" {
  description = "SMTP server hostname (e.g. smtp.gmail.com)"
  type        = string
  default     = ""
}

variable "overleaf_smtp_port" {
  description = "SMTP server port (typically 587 for TLS)"
  type        = number
  default     = 587
}

variable "overleaf_smtp_secure" {
  description = "Use SSL/TLS connection (true) or STARTTLS (false). Gmail uses false."
  type        = bool
  default     = false
}

variable "overleaf_smtp_user" {
  description = "SMTP username (typically your email address)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "overleaf_smtp_pass" {
  description = "SMTP password or app password (for Gmail, use App Password)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "overleaf_smtp_tls_reject_unauth" {
  description = "Reject unauthorized TLS certificates"
  type        = bool
  default     = true
}

variable "overleaf_smtp_ignore_tls" {
  description = "Ignore TLS (not recommended for production)"
  type        = bool
  default     = false
}

# -------------------------------------------------------------------
# User Registration & Access Control
# -------------------------------------------------------------------

variable "email_confirmation_disabled" {
  description = "Disable email confirmation requirement. Set to false to require email verification (requires SMTP configured)."
  type        = bool
  default     = true
}

variable "allowed_email_domains" {
  description = "Comma-separated list of email domains allowed to register (e.g., 'example.com,university.edu'). Leave empty to allow all domains."
  type        = string
  default     = ""
}

# -------------------------------------------------------------------
# AI Tutor Configuration
# -------------------------------------------------------------------

variable "openai_api_key" {
  description = "OpenAI API key for AI Tutor features (required for paper review functionality)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "openai_base_url" {
  description = "Custom OpenAI API base URL (optional, for using LiteLLM proxy or other OpenAI-compatible endpoints). Leave empty to use default OpenAI API."
  type        = string
  default     = ""
}

variable "litellm_master_key" {
  description = "Master key for LiteLLM proxy authentication (optional, auto-generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key for Claude models (optional, only needed if using Claude via LiteLLM)"
  type        = string
  default     = ""
  sensitive   = true
}

# -------------------------------------------------------------------
# S3 Storage Configuration (for data persistence)
# -------------------------------------------------------------------

variable "enable_s3_storage" {
  description = "Enable S3 storage backend for Overleaf data persistence (recommended for production)"
  type        = bool
  default     = false
}

variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket names (will create: prefix-user-files, prefix-template-files, prefix-project-blobs, prefix-chunks)"
  type        = string
  default     = "overleaf"
}
