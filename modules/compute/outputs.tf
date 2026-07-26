output "instance_ids" {
  description = "IDs of the EC2 instances."
  value       = aws_instance.app[*].id
}

output "private_ips" {
  description = "Private IPs of the EC2 instances."
  value       = aws_instance.app[*].private_ip
}

output "public_ips" {
  description = "Public IPs of the EC2 instances (only populated when ec2_subnet_type = \"public\")."
  value       = aws_instance.app[*].public_ip
}

output "security_group_id" {
  description = "ID of the EC2 security group — allow this as the only source on the RDS security group."
  value       = aws_security_group.ec2.id
}
