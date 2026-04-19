# ============================================================================
# All Input Variables
# All values are supplied via terraform.tfvars — no defaults are relied on
# for sensitive or environment-specific settings.
# ============================================================================

# ----------------------------------------------------------------------------
# AWS Authentication
# ----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI named profile to use for authentication"
  type        = string
}

# ----------------------------------------------------------------------------
# Project Metadata
# ----------------------------------------------------------------------------

variable "project_name" {
  description = "Short project identifier used in all resource names and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment (production, staging, dev)"
  type        = string
}

variable "common_tags" {
  description = "Additional tags applied to every resource"
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------
# Networking
# ----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (frontend lives in [0])"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (backend and database live in [0])"
  type        = list(string)
}

variable "availability_zones" {
  description = "AZs to spread subnets across — must match length of subnet CIDR lists"
  type        = list(string)
}

# ----------------------------------------------------------------------------
# EC2 Instances
# ----------------------------------------------------------------------------

variable "ami_id" {
  description = "AMI ID for EC2 instances. Leave empty to auto-select latest Ubuntu 22.04 LTS."
  type        = string
}

variable "instance_type_frontend" {
  description = "EC2 instance type for the frontend server (public)"
  type        = string
}

variable "instance_type_backend" {
  description = "EC2 instance type for the backend server (private)"
  type        = string
}

variable "instance_type_database" {
  description = "EC2 instance type for the database server (private)"
  type        = string
}

variable "key_name" {
  description = "Name of the existing EC2 key pair to attach to all instances"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = <<-EOT
    CIDR(s) allowed to SSH into the frontend server on port 22.
    REQUIRED — restrict to your own IP for security.
    Example: ["203.0.113.5/32"]
  EOT
  type        = list(string)
  # No default — you MUST supply your IP in terraform.tfvars
}

# ----------------------------------------------------------------------------
# Application
# ----------------------------------------------------------------------------

variable "git_repo_url" {
  description = "Git HTTPS URL for the application source code"
  type        = string
}

variable "git_branch" {
  description = "Git branch to clone and deploy"
  type        = string
}

variable "backend_port" {
  description = "TCP port the Node.js backend application listens on"
  type        = number
}

# ----------------------------------------------------------------------------
# DNS / Domain
# ----------------------------------------------------------------------------

variable "domain_name" {
  description = "Fully qualified domain name for the application (e.g. fpub-trfm.ostaddevops.click)"
  type        = string
}

variable "hosted_zone_name" {
  description = "Route53 hosted zone name — the parent domain (e.g. ostaddevops.click)"
  type        = string
}

# ----------------------------------------------------------------------------
# Database
# ----------------------------------------------------------------------------

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
}

variable "db_user" {
  description = "PostgreSQL database username"
  type        = string
}

variable "db_password" {
  description = "PostgreSQL database password — keep strong and never commit to git"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "PostgreSQL port"
  type        = number
}
