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
