variable "project_name" {
  description = "Short project name, used as part of the resource name prefix."
  type        = string
  default     = "alb-ec2-rds"
}

variable "environment" {
  description = "Environment name for this deployment (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across."
  type        = number
  default     = 2
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets — must have exactly az_count entries."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets — must have exactly az_count entries."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateway(s) (and the private routes to them) for outbound internet access from private subnets."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "When true, one shared NAT Gateway for all private subnets. When false, one NAT Gateway per AZ."
  type        = bool
  default     = true
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into the EC2 instances. Only used when ec2_subnet_type = \"public\"."
  type        = string
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

variable "ami_id" {
  description = "AMI ID to use for the EC2 instances. No default — must be supplied explicitly."
  type        = string
}

variable "ec2_instance_type" {
  description = "Instance type for the EC2 instances. Size this per environment (e.g. t3.micro for dev, larger for prod)."
  type        = string
  default     = "t3.micro"
}

variable "ec2_instance_count" {
  description = "Number of EC2 instances to create."
  type        = number
  default     = 2
}

variable "ec2_root_volume_size" {
  description = "Root EBS volume size (GiB) for the EC2 instances."
  type        = number
  default     = 20
}

variable "ec2_root_volume_type" {
  description = "Root EBS volume type for the EC2 instances."
  type        = string
  default     = "gp3"
}

variable "ec2_key_name" {
  description = "EC2 key pair name for SSH access. Leave empty to not attach a key pair."
  type        = string
  default     = ""
}

variable "enable_ssm" {
  description = "Whether to attach an IAM instance profile granting AWS Systems Manager Session Manager access."
  type        = bool
  default     = false
}

variable "ec2_subnet_type" {
  description = "Which subnet tier the EC2 instances are placed in: \"public\" or \"private\"."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private"], var.ec2_subnet_type)
    error_message = "ec2_subnet_type must be either \"public\" or \"private\"."
  }
}

# ---------------------------------------------------------------------------
# Load balancer
# ---------------------------------------------------------------------------

variable "services" {
  description = "Services the ALB routes to via host-based routing (e.g. frontend + backend on the same instances, different ports). Exactly one must have is_default = true."
  type = list(object({
    name         = string
    port         = number
    host_headers = list(string)
    is_default   = optional(bool, false)

    health_check_path                = optional(string, "/")
    health_check_healthy_threshold   = optional(number, 3)
    health_check_unhealthy_threshold = optional(number, 3)
    health_check_interval            = optional(number, 30)
    health_check_timeout             = optional(number, 5)
    health_check_matcher             = optional(string, "200-399")
  }))

  default = [
    {
      name         = "frontend"
      port         = 3000
      host_headers = ["app.example.com"]
      is_default   = true
    },
    {
      name         = "backend"
      port         = 4000
      host_headers = ["api.example.com"]
      is_default   = false
    }
  ]
}

variable "alb_allowed_cidrs" {
  description = "CIDR blocks allowed to reach the ALB on ports 80/443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection on the ALB."
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Whether to create an HTTPS (443) listener on the ALB. Requires certificate_arn."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. Required when enable_https = true."
  type        = string
  default     = ""
}

variable "redirect_http_to_https" {
  description = "When true (and enable_https = true), the HTTP listener redirects to HTTPS instead of forwarding to the target group."
  type        = bool
  default     = false
}

variable "additional_certificate_arns" {
  description = "Extra ACM certificate ARNs attached to the HTTPS listener via SNI, for domains not covered by certificate_arn."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

variable "db_instance_class" {
  description = "Instance class for the RDS PostgreSQL instance. Size this per environment (e.g. db.t3.micro for dev, larger for prod)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Whether to enable Multi-AZ for the RDS instance."
  type        = bool
  default     = false
}

variable "db_storage_encrypted" {
  description = "Whether to encrypt the RDS storage at rest."
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated backups. 0 disables automated backups."
  type        = number
  default     = 1
}

variable "db_max_allocated_storage" {
  description = "Upper limit (GiB) for RDS storage autoscaling. Set to null to disable autoscaling."
  type        = number
  default     = null
}

variable "db_deletion_protection" {
  description = "Whether to enable deletion protection on the RDS instance."
  type        = bool
  default     = false
}

variable "db_apply_immediately" {
  description = "Whether to apply RDS modifications immediately instead of during the next maintenance window."
  type        = bool
  default     = true
}

variable "db_engine_version" {
  description = "PostgreSQL engine version for RDS."
  type        = string
  default     = "16"
}

variable "db_allocated_storage" {
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

variable "db_skip_final_snapshot" {
  description = "Whether to skip the final snapshot when the RDS instance is destroyed."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Common tags applied to all resources, in addition to the automatic Environment tag."
  type        = map(string)
  default = {
    Project   = "alb-ec2-rds-stack"
    ManagedBy = "terraform"
  }
}
