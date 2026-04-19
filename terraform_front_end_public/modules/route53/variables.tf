variable "project_name" {
  description = "Project identifier"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID where the record will be created"
  type        = string
}

variable "domain_name" {
  description = "Fully qualified domain name for the A record"
  type        = string
}

variable "frontend_ip" {
  description = "Elastic IP address of the frontend server"
  type        = string
}

variable "common_tags" {
  description = "Tags (not applicable to Route53 records but kept for consistency)"
  type        = map(string)
  default     = {}
}
