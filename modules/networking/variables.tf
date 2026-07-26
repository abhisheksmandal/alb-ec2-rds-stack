variable "name_prefix" {
  description = "Prefix used when naming/tagging resources created by this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across (1 public + 1 private subnet per AZ)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 6
    error_message = "az_count must be between 1 and 6."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets — must have exactly az_count entries."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == var.az_count
    error_message = "public_subnet_cidrs must have exactly az_count entries."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets — must have exactly az_count entries."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == var.az_count
    error_message = "private_subnet_cidrs must have exactly az_count entries."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateway(s) (and the private routes to them) for outbound internet access from private subnets."
  type        = bool
}

variable "single_nat_gateway" {
  description = "When true, create one shared NAT Gateway for all private subnets (cheaper). When false, create one NAT Gateway per AZ (higher availability, higher cost). Ignored when enable_nat_gateway = false."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
