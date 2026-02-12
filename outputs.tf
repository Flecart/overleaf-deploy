output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.overleaf.id
}

output "public_ip" {
  description = "Public IP address of the Overleaf instance"
  value       = aws_instance.overleaf.public_ip
}

output "public_dns" {
  description = "Public DNS name of the Overleaf instance"
  value       = aws_instance.overleaf.public_dns
}

output "overleaf_url" {
  description = "URL to access Overleaf (available after deployment completes, ~15-25 min)"
  value       = "http://${aws_instance.overleaf.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.overleaf.public_ip}"
}

output "check_deployment_logs" {
  description = "Command to check deployment progress after SSH"
  value       = "sudo tail -f /var/log/cloud-init-output.log"
}
