output "rds_endpoint" {
  description = "Connection endpoint (host:port) of the RDS PostgreSQL instance."
  value       = aws_db_instance.main.endpoint
}

output "rds_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the RDS master credentials."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "ID of the RDS security group."
  value       = aws_security_group.rds.id
}
