# ============================================================================
# Provider Configuration
# ============================================================================

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
      },
      var.common_tags
    )
  }
}

# ============================================================================
# Data Sources
# ============================================================================

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get Route53 hosted zone
data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}

# Get VPC details
data "aws_vpc" "main" {
  id = var.vpc_id
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================================
# IAM Module - Roles and Instance Profiles
# ============================================================================

module "iam" {
  source = "./modules/iam"

  hosted_zone_id = var.hosted_zone_id
  project_name   = var.project_name
  environment    = var.environment
  common_tags    = local.common_tags
}

# ============================================================================
# EC2 Module - Database, Backend, Frontend Instances
# ============================================================================

module "ec2" {
  source = "./modules/ec2"

  # Networking
  vpc_id                     = var.vpc_id
  private_subnet_ids         = var.private_subnet_ids
  frontend_security_group_id = var.frontend_security_group_id
  backend_security_group_id  = var.backend_security_group_id
  database_security_group_id = var.database_security_group_id

  # Instance Configuration
  ami_id                 = local.ami_id
  key_name               = var.key_name
  instance_type_frontend = var.instance_type_frontend
  instance_type_backend  = var.instance_type_backend
  instance_type_database = var.instance_type_database

  # IAM Configuration
  frontend_instance_profile_name = module.iam.frontend_instance_profile_name

  # Application Configuration
  git_repo_url = var.git_repo_url
  git_branch   = var.git_branch
  domain_name  = var.domain_name
  aws_region   = var.aws_region
  aws_profile  = var.aws_profile

  # Database Configuration
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
  db_port     = var.db_port

  # Backend Configuration
  backend_port = var.backend_port

  # Tags
  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags
}

# ============================================================================
# ALB Module - Application Load Balancer
# ============================================================================
# ALB is created first, then HTTPS listener is added after certificate import

module "alb" {
  source = "./modules/alb"

  # Networking
  vpc_id                = var.vpc_id
  public_subnet_ids     = var.public_subnet_ids
  alb_security_group_id = var.alb_security_group_id

  # Domain Configuration
  domain_name    = var.domain_name
  hosted_zone_id = var.hosted_zone_id

  # Certificate from Certbot import (will be populated after EC2 module completes)
  certificate_arn = module.ec2.imported_certificate_arn

  # Tags
  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags
}

# ============================================================================
# DNS Module - Route53 Records
# ============================================================================

module "dns" {
  source = "./modules/dns"

  # Route53 Configuration
  hosted_zone_id = var.hosted_zone_id
  domain_name    = var.domain_name

  # ALB Configuration
  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id

  # Certificate validation handled by Certbot (no longer needed)
  # certificate_validation_options = module.alb.certificate_validation_options

  # Tags
  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags
}
# ============================================================================
# Target Group Attachment - Frontend to ALB
# ============================================================================
# This resource is created in the root module to avoid circular dependency
# between EC2 and ALB modules. It depends on the certificate being imported.

resource "aws_lb_target_group_attachment" "frontend" {
  target_group_arn = module.alb.target_group_arn
  target_id        = module.ec2.frontend_instance_id
  port             = 80

  # Wait for certificate to be imported before attaching to ALB
  depends_on = [
    module.ec2,
    module.alb
  ]
}