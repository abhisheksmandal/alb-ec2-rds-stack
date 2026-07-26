variable "name_prefix" {
  description = "Prefix used when naming/tagging resources created by this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the RDS security group is created in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (needs at least 2, in different AZs)."
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "Security group ID of the EC2 instances — the only allowed source for PostgreSQL traffic."
  type        = string
}

variable "instance_class" {
  description = "Instance class for the RDS PostgreSQL instance."
  type        = string
  default     = "db.t3.micro"
}

variable "engine_version" {
  description = "PostgreSQL engine version for RDS."
  type        = string
  default     = "16"
}

variable "allocated_storage" {
  description = "Allocated storage (GiB) for the RDS instance."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name created on the RDS instance."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS instance. The password is generated and managed by AWS Secrets Manager (manage_master_user_password), never set here."
  type        = string
  default     = "dbadmin"
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot when the RDS instance is destroyed."
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ for the RDS instance (standby in a second AZ, automatic failover)."
  type        = bool
  default     = false
}

variable "storage_encrypted" {
  description = "Whether to encrypt the RDS storage at rest."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups. 0 disables automated backups."
  type        = number
  default     = 7
}

variable "max_allocated_storage" {
  description = "Upper limit (GiB) for RDS storage autoscaling. Set to null to disable autoscaling."
  type        = number
  default     = null
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the RDS instance."
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Whether to apply modifications immediately instead of during the next maintenance window."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
