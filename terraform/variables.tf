# ============================================================================
# AWS Provider Configuration
# ============================================================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI named profile to use for authentication"
  type        = string
}

# ============================================================================
# Networking Configuration (User Provided)
# ============================================================================

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2 instances"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  type        = string
}

variable "frontend_security_group_id" {
  description = "Security group ID for frontend EC2 instance"
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group ID for backend EC2 instance"
  type        = string
}

variable "database_security_group_id" {
  description = "Security group ID for database EC2 instance"
  type        = string
}

# ============================================================================
# Route53 Configuration
# ============================================================================

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application (e.g., bmi.example.com)"
  type        = string
}

# ============================================================================
# EC2 Configuration
# ============================================================================

variable "instance_type_frontend" {
  description = "EC2 instance type for frontend server"
  type        = string
  default     = "t3.small"
}

variable "instance_type_backend" {
  description = "EC2 instance type for backend server"
  type        = string
  default     = "t3.small"
}

variable "instance_type_database" {
  description = "EC2 instance type for database server"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "ami_id" {
  description = "Ubuntu AMI ID (leave empty to use latest Ubuntu 22.04 LTS)"
  type        = string
  default     = ""
}

# ============================================================================
# Application Configuration
# ============================================================================

variable "git_repo_url" {
  description = "Git repository URL for the application code"
  type        = string
}

variable "git_branch" {
  description = "Git branch to deploy"
  type        = string
  default     = "main"
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "bmidb"
}

variable "db_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = "bmi_user"
}

variable "db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "PostgreSQL database port"
  type        = number
  default     = 5432
}

# ============================================================================
# Backend API Configuration
# ============================================================================

variable "backend_port" {
  description = "Backend API server port"
  type        = number
  default     = 3000
}

# ============================================================================
# Tags
# ============================================================================

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "bmi-health-tracker"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
