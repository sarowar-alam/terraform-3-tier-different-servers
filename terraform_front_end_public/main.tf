# ============================================================================
# Root Module — Orchestrates all child modules
#
# Execution order enforced by explicit depends_on:
#   vpc + iam (parallel)
#     → security_groups
#       → ec2 (database → backend → frontend, each SSM-gated)
#         → route53
#           → null_resource.generate_certificate (SSM Run Command on frontend)
# ============================================================================

# ----------------------------------------------------------------------------
# Data Sources
# ----------------------------------------------------------------------------

# Route53 hosted zone — needed by both IAM (scoped policy) and Route53 modules
data "aws_route53_zone" "main" {
  name         = var.hosted_zone_name
  private_zone = false
}

locals {
  ami_id = var.ami_id
}

# ----------------------------------------------------------------------------
# VPC Module
# Creates: VPC, IGW, public/private subnets, NAT GW, route tables
# ----------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  common_tags          = var.common_tags
}

# ----------------------------------------------------------------------------
# IAM Module
# Creates: 3 IAM roles + instance profiles
#   database  — SSM only
#   backend   — SSM only
#   frontend  — SSM + Route53 (read-only; kept for future use)
# ----------------------------------------------------------------------------

module "iam" {
  source = "./modules/iam"

  project_name    = var.project_name
  environment     = var.environment
  hosted_zone_id  = data.aws_route53_zone.main.zone_id
  common_tags     = var.common_tags
}

# ----------------------------------------------------------------------------
# Security Groups Module
# Creates: frontend SG, backend SG, database SG (tiered access)
# ----------------------------------------------------------------------------

module "security_groups" {
  source = "./modules/security_groups"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  backend_port      = var.backend_port
  db_port           = var.db_port
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  common_tags       = var.common_tags
}

# ----------------------------------------------------------------------------
# EC2 Module
# Creates: EIP, 3 EC2 instances, 3 SSM-online null_resources (strict chain),
#          EIP association for frontend
#
# Deployment order enforced inside the module:
#   database created → SSM Online wait
#     → backend created → SSM Online wait
#       → frontend created → SSM Online wait
#         → EIP associated
# ----------------------------------------------------------------------------

module "ec2" {
  source = "./modules/ec2"

  # Wait for the ENTIRE vpc module (NAT Gateway + route tables) before creating
  # any EC2 instance. Without this, private instances boot before the NAT GW is
  # ready and can't reach SSM endpoints, causing wait_ssm_* to time out.
  depends_on = [module.vpc, module.iam, module.security_groups]

  project_name = var.project_name
  environment  = var.environment
  ami_id       = local.ami_id
  key_name     = var.key_name
  aws_region   = var.aws_region
  aws_profile  = var.aws_profile
  common_tags  = var.common_tags

  # Subnets — frontend in public, backend + database in private
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  private_subnet_id = module.vpc.private_subnet_ids[0]

  # Security groups
  frontend_security_group_id = module.security_groups.frontend_sg_id
  backend_security_group_id  = module.security_groups.backend_sg_id
  database_security_group_id = module.security_groups.database_sg_id

  # IAM instance profiles (one per tier)
  frontend_instance_profile_name = module.iam.frontend_instance_profile_name
  backend_instance_profile_name  = module.iam.backend_instance_profile_name
  database_instance_profile_name = module.iam.database_instance_profile_name

  # Instance sizing
  instance_type_frontend = var.instance_type_frontend
  instance_type_backend  = var.instance_type_backend
  instance_type_database = var.instance_type_database

  # Application
  git_repo_url = var.git_repo_url
  git_branch   = var.git_branch
  domain_name  = var.domain_name
  backend_port = var.backend_port

  # Database credentials
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
  db_port     = var.db_port

  # Route53 — A record created inside ec2 module before frontend boots
  hosted_zone_id = data.aws_route53_zone.main.zone_id
}

# (Route53 A record and certificate are now handled inside modules/ec2/main.tf
#  and scripts/frontend_setup.sh respectively — no separate resources needed here.)
