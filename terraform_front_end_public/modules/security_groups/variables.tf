variable "project_name" {
  description = "Project identifier used in resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to create security groups"
  type        = string
}

variable "backend_port" {
  description = "TCP port the backend Node.js application listens on"
  type        = number
}

variable "db_port" {
  description = "TCP port PostgreSQL listens on"
  type        = number
}

variable "ssh_allowed_cidrs" {
  description = "CIDR list allowed to SSH into the frontend server on port 22"
  type        = list(string)
}

variable "common_tags" {
  description = "Tags merged onto every security group"
  type        = map(string)
  default     = {}
}
