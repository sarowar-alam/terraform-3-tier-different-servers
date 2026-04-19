variable "project_name" {
  description = "Project identifier used in resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID — used to scope the Certbot Route53 policy"
  type        = string
}

variable "common_tags" {
  description = "Tags merged onto every IAM resource"
  type        = map(string)
  default     = {}
}
