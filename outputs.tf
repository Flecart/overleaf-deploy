output "instance_id" {
  value       = aws_instance.overleaf.id
  description = "Destination EC2 instance ID."
}

output "public_ip" {
  value       = aws_eip.overleaf.public_ip
  description = "Elastic IP for validation and the production DNS A record."
}

output "data_volume_id" {
  value       = aws_ebs_volume.data.id
  description = "Deletion-protected persistent EBS data volume."
}

output "ssh_command" {
  value       = "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ubuntu@${aws_eip.overleaf.public_ip}"
  description = "SSH command for the destination host."
}

output "dns_change" {
  value       = "Set ${var.service_hostname} A ${aws_eip.overleaf.public_ip}"
  description = "DNS change to make only after final validation."
}

output "data_layout" {
  value       = "/srv/overleaf-data (Docker data root and persistent /home/ubuntu)"
  description = "Persistent storage layout."
}
