# ============================================================================
# IAM Module for Certificate Management
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for DNS challenge"
  type        = string
}
