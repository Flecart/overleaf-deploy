output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.overleaf.id
}

output "public_ip" {
  description = "Public IP address of the Overleaf instance (Elastic IP - stable)"
  value       = aws_eip.overleaf.public_ip
}

output "public_dns" {
  description = "AWS-provided public DNS hostname"
  value       = aws_instance.overleaf.public_dns
}

output "overleaf_url" {
  description = "URL to access Overleaf (available after deployment completes, ~15-25 min)"
  value       = "http://${aws_eip.overleaf.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_eip.overleaf.public_ip}"
}

output "check_deployment_logs" {
  description = "Command to check deployment progress after SSH"
  value       = "sudo tail -f /var/log/cloud-init-output.log"
}

# output "data_volume_id" {
#   description = "Persistent data volume ID (preserved across terraform destroy)"
#   value       = aws_ebs_volume.overleaf_data.id
# }
#
# output "data_volume_info" {
#   description = "Data volume information"
#   value       = "Volume ${aws_ebs_volume.overleaf_data.id} (${var.data_volume_size}GB) persists across deployments. Contains MongoDB, uploads, and project files."
# }

output "smtp_configured" {
  description = "Whether SMTP email is configured"
  value       = var.overleaf_smtp_host != "" && var.overleaf_smtp_user != "" ? "Yes (${var.overleaf_smtp_host})" : "No - emails disabled"
  sensitive   = true
}

output "email_from_address" {
  description = "Email sender address (if SMTP configured)"
  value       = var.overleaf_email_from_address != "" ? var.overleaf_email_from_address : "Not configured"
  sensitive   = true
}

output "s3_storage_enabled" {
  description = "Whether S3 storage backend is enabled for data persistence"
  value       = var.enable_s3_storage ? "Yes - Data will persist in S3 buckets" : "No - Using local EBS storage"
}

output "s3_buckets" {
  description = "S3 buckets created for Overleaf storage"
  value = var.enable_s3_storage ? {
    user_files     = aws_s3_bucket.user_files[0].id
    template_files = aws_s3_bucket.template_files[0].id
    project_blobs  = aws_s3_bucket.project_blobs[0].id
    chunks         = aws_s3_bucket.chunks[0].id
  } : {}
}

output "s3_filestore_credentials" {
  description = "S3 credentials for filestore service (sensitive)"
  value = var.enable_s3_storage ? {
    access_key_id     = aws_iam_access_key.filestore[0].id
    secret_access_key = aws_iam_access_key.filestore[0].secret
  } : {}
  sensitive = true
}

output "s3_history_credentials" {
  description = "S3 credentials for history service (sensitive)"
  value = var.enable_s3_storage ? {
    access_key_id     = aws_iam_access_key.history[0].id
    secret_access_key = aws_iam_access_key.history[0].secret
  } : {}
  sensitive = true
}
