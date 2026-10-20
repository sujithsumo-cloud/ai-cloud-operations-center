variable "project_name" {
  description = "Project name."
  type        = string
  default     = "ai-cloud-operations-center"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS deployment region."
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "admin_cidr" {
  description = "Optional administrator IPv4 CIDR for SSH."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.admin_cidr == null || can(
      regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.admin_cidr)
    )
    error_message = "Use null or a single IPv4 address ending in /32."
  }
}

variable "enable_ai_analysis" {
  description = "Enable optional AI incident analysis."
  type        = bool
  default     = false
}
