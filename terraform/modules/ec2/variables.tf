# ============================================================================
# EC2 Module - Variables
# ============================================================================

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "frontend_security_group_id" {
  description = "Security group ID for frontend instance"
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group ID for backend instance"
  type        = string
}

variable "database_security_group_id" {
  description = "Security group ID for database instance"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "instance_type_frontend" {
  description = "Instance type for frontend"
  type        = string
}

variable "instance_type_backend" {
  description = "Instance type for backend"
  type        = string
}

variable "instance_type_database" {
  description = "Instance type for database"
  type        = string
}

variable "git_repo_url" {
  description = "Git repository URL"
  type        = string
}

variable "git_branch" {
  description = "Git branch"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database user"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "backend_port" {
  description = "Backend API port"
  type        = number
}

variable "frontend_target_group_arn" {
  description = "Frontend target group ARN"
  type        = string
}

variable "frontend_instance_profile_name" {
  description = "IAM instance profile name for frontend EC2"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
