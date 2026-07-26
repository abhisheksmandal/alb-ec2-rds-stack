variable "name_prefix" {
  description = "Prefix used when naming/tagging resources created by this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the EC2 security group is created in."
  type        = string
}

variable "ami_id" {
  description = "AMI ID to use for the EC2 instances. No default — must be supplied explicitly."
  type        = string
}

variable "instance_type" {
  description = "Instance type for the EC2 instances."
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of EC2 instances to create (one per subnet, cycling through the available subnet IDs)."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size (GiB)."
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type."
  type        = string
  default     = "gp3"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access. Leave empty to not attach a key pair."
  type        = string
  default     = ""
}

variable "enable_ssm" {
  description = "Whether to attach an IAM instance profile granting AWS Systems Manager Session Manager access — useful for reaching instances that have no SSH path (e.g. private subnet with no NAT). Note: SSM still needs an outbound route to its endpoints (via NAT/IGW or VPC interface endpoints), which this flag alone does not provide."
  type        = bool
  default     = false
}

variable "ec2_subnet_type" {
  description = "Which subnet tier the EC2 instances are placed in: \"public\" or \"private\"."
  type        = string

  validation {
    condition     = contains(["public", "private"], var.ec2_subnet_type)
    error_message = "ec2_subnet_type must be either \"public\" or \"private\"."
  }
}

variable "public_subnet_ids" {
  description = "Public subnet IDs to place instances in when ec2_subnet_type = \"public\"."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs to place instances in when ec2_subnet_type = \"private\"."
  type        = list(string)
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into the EC2 instances. Only used when ec2_subnet_type = \"public\"."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be a valid CIDR block, e.g. 203.0.113.4/32."
  }
}

variable "app_ports" {
  description = "TCP ports the application(s) on these instances listen on (e.g. one per co-located service). Each is only reachable from the ALB security group."
  type        = list(number)

  validation {
    condition     = length(var.app_ports) >= 1
    error_message = "At least one app port must be specified."
  }
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB — the only allowed source for app-port traffic."
  type        = string
}

variable "enable_nat_gateway" {
  description = "Whether a NAT Gateway exists for this environment. Used only to detect the no-outbound-path footgun; has no effect on resources created here."
  type        = bool
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
