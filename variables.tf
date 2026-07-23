variable "aws_account_id" {
  description = "AWS account that must own the deployment (billing safety guard)."
  type        = string
  default     = "906513713427"
}

variable "aws_region" {
  description = "AWS region for the replacement service."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for AWS resource names and tags."
  type        = string
  default     = "overleaf-mentor"
}

variable "instance_type" {
  description = "EC2 type; t3.large matches the live service."
  type        = string
  default     = "t3.large"
}

variable "root_volume_size" {
  description = "Disposable encrypted operating-system disk size in GiB."
  type        = number
  default     = 40
}

variable "data_volume_size" {
  description = "Retained encrypted disk for Docker data and /home/ubuntu, in GiB."
  type        = number
  default     = 120
}

variable "key_name" {
  description = "Name for the Terraform-managed operator EC2 key pair."
  type        = string
  default     = "overleaf-mentor-operator"
}

variable "ssh_public_key_path" {
  description = "Local public key imported into EC2; private material is never read by Terraform."
  type        = string
  default     = "~/.ssh/new_github.pub"
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH. Authentication is enforced by the EC2 key pair."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "service_hostname" {
  description = "Production hostname switched after migration validation."
  type        = string
  default     = "overleaf.safe.eu"
}
