variable "project_name" {
  description = "Project identifier used in resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for all EC2 instances"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "aws_region" {
  description = "AWS region — used in SSM wait local-exec commands"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile — used in SSM wait local-exec commands"
  type        = string
}

variable "common_tags" {
  description = "Tags merged onto every EC2 resource"
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------
# Subnets
# ----------------------------------------------------------------------------

variable "public_subnet_id" {
  description = "Subnet ID for the frontend instance (public subnet)"
  type        = string
}

variable "private_subnet_id" {
  description = "Subnet ID for backend and database instances (private subnet)"
  type        = string
}

# ----------------------------------------------------------------------------
# Security Groups
# ----------------------------------------------------------------------------

variable "frontend_security_group_id" {
  description = "Security group ID for the frontend instance"
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group ID for the backend instance"
  type        = string
}

variable "database_security_group_id" {
  description = "Security group ID for the database instance"
  type        = string
}

# ----------------------------------------------------------------------------
# IAM Instance Profiles
# ----------------------------------------------------------------------------

variable "frontend_instance_profile_name" {
  description = "IAM instance profile name for the frontend (SSM + Route53/Certbot)"
  type        = string
}

variable "backend_instance_profile_name" {
  description = "IAM instance profile name for the backend (SSM)"
  type        = string
}

variable "database_instance_profile_name" {
  description = "IAM instance profile name for the database (SSM)"
  type        = string
}

# ----------------------------------------------------------------------------
# Instance Types
# ----------------------------------------------------------------------------

variable "instance_type_frontend" {
  description = "EC2 instance type for the frontend server"
  type        = string
}

variable "instance_type_backend" {
  description = "EC2 instance type for the backend server"
  type        = string
}

variable "instance_type_database" {
  description = "EC2 instance type for the database server"
  type        = string
}

# ----------------------------------------------------------------------------
# Application
# ----------------------------------------------------------------------------

variable "git_repo_url" {
  description = "Git HTTPS URL for the application"
  type        = string
}

variable "git_branch" {
  description = "Git branch to clone"
  type        = string
}

variable "domain_name" {
  description = "Fully qualified domain name for the application"
  type        = string
}

variable "backend_port" {
  description = "Port the Node.js backend listens on"
  type        = number
}

# ----------------------------------------------------------------------------
# Database
# ----------------------------------------------------------------------------

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "PostgreSQL port"
  type        = number
}
