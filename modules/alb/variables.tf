variable "name_prefix" {
  description = "Prefix used when naming/tagging resources created by this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the ALB and its security group are created in."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs the ALB is deployed across (needs at least 2, in different AZs)."
  type        = list(string)
}

variable "services" {
  description = "Services the ALB routes to via host-based routing. Each gets its own target group; requests are forwarded based on the Host header matching host_headers. Exactly one service must have is_default = true — it's used as the listener's fallback for requests matching no host_headers."
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

  validation {
    condition     = length(var.services) >= 1
    error_message = "At least one service must be defined."
  }

  validation {
    condition     = length(distinct([for s in var.services : s.name])) == length(var.services)
    error_message = "Service names must be unique."
  }

  validation {
    condition     = length([for s in var.services : s if s.is_default]) == 1
    error_message = "Exactly one service must have is_default = true."
  }
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

  validation {
    condition     = var.enable_https == false || var.certificate_arn != ""
    error_message = "certificate_arn must be set when enable_https = true."
  }
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

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
