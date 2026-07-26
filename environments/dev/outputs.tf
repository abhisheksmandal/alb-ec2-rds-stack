output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer. Point each service's domain (CNAME/ALIAS) at this."
  value       = module.alb.alb_dns_name
}

output "alb_target_group_arns" {
  description = "Map of service name -> target group ARN."
  value       = module.alb.target_group_arns
}

output "rds_endpoint" {
  description = "Connection endpoint (host:port) of the RDS PostgreSQL instance."
  value       = module.database.rds_endpoint
}

output "rds_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the RDS master credentials."
  value       = module.database.rds_master_user_secret_arn
}

output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.networking.private_subnet_ids
}

output "ec2_instance_ids" {
  description = "IDs of the EC2 instances."
  value       = module.compute.instance_ids
}

output "ec2_instance_private_ips" {
  description = "Private IPs of the EC2 instances."
  value       = module.compute.private_ips
}

output "ec2_instance_public_ips" {
  description = "Public IPs of the EC2 instances (only populated when ec2_subnet_type = \"public\")."
  value       = module.compute.public_ips
}
