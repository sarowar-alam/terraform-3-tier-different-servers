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

# Latest Ubuntu 22.04 LTS AMI from Canonical
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
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Route53 hosted zone — needed by both IAM (scoped policy) and Route53 modules
data "aws_route53_zone" "main" {
  name         = var.hosted_zone_name
  private_zone = false
}

locals {
  # Use explicitly supplied AMI if set, otherwise latest Ubuntu 22.04 LTS
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
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
#   frontend  — SSM + Route53 (for Certbot DNS-01 challenge)
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
}

# ----------------------------------------------------------------------------
# Route53 Module
# Creates: A record  domain_name → frontend EIP
# Only runs after EC2 module is fully complete (instances up + SSM online)
# ----------------------------------------------------------------------------

module "route53" {
  source = "./modules/route53"

  # Wait for the entire EC2 module (SSM waits, EIP association) before
  # creating the DNS record so the IP is stable and instances are live.
  depends_on = [module.ec2]

  project_name     = var.project_name
  environment      = var.environment
  domain_name      = var.domain_name
  hosted_zone_id   = data.aws_route53_zone.main.zone_id
  frontend_ip      = module.ec2.frontend_public_ip
  common_tags      = var.common_tags
}

# ----------------------------------------------------------------------------
# Certificate Generation
# Triggers Certbot on the frontend server via SSM Run Command AFTER the
# Route53 A record exists (required for DNS-01 TXT validation to work).
# ----------------------------------------------------------------------------

resource "null_resource" "generate_certificate" {
  depends_on = [module.route53]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $instanceId = "${module.ec2.frontend_instance_id}"
      $region     = "${var.aws_region}"
      $profile    = "${var.aws_profile}"
      $domain     = "${var.domain_name}"

      Write-Host ""
      Write-Host "=============================================="
      Write-Host " Triggering certificate generation via SSM"
      Write-Host " Instance : $instanceId"
      Write-Host " Domain   : $domain"
      Write-Host "=============================================="

      # Send SSM Run Command to the frontend instance
      $sendOutput = aws ssm send-command `
        --instance-ids $instanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=[\"/usr/local/bin/generate-certificate.sh\"]" `
        --timeout-seconds 600 `
        --region $region `
        --profile $profile `
        --output json

      if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to send SSM Run Command"
        exit 1
      }

      $cmdId = ($sendOutput | ConvertFrom-Json).Command.CommandId
      Write-Host "SSM Command ID : $cmdId"
      Write-Host "Polling for completion (max 10 minutes)..."

      $maxAttempts = 20
      $attempt     = 0
      $finalStatus = "Pending"

      while ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 30
        $attempt++

        $invJson = aws ssm get-command-invocation `
          --command-id $cmdId `
          --instance-id $instanceId `
          --region $region `
          --profile $profile `
          --output json 2>$null

        if ($LASTEXITCODE -eq 0) {
          $inv         = $invJson | ConvertFrom-Json
          $finalStatus = $inv.Status
          Write-Host "[$attempt/$maxAttempts] Status = $finalStatus"

          if ($finalStatus -eq "Success") {
            Write-Host ""
            Write-Host "Certificate generation succeeded!"
            Write-Host "--- stdout ---"
            Write-Host $inv.StandardOutputContent
            break
          }

          if ($finalStatus -in @("Failed","Cancelled","TimedOut","DeliveryTimedOut")) {
            Write-Host "ERROR: Certificate generation failed (status: $finalStatus)"
            Write-Host "--- stderr ---"
            Write-Host $inv.StandardErrorContent
            Write-Host ""
            Write-Host "To retry manually, SSH or SSM connect to the frontend and run:"
            Write-Host "  sudo /usr/local/bin/generate-certificate.sh"
            exit 1
          }
        } else {
          Write-Host "[$attempt/$maxAttempts] Waiting for SSM invocation to appear..."
        }
      }

      if ($finalStatus -ne "Success") {
        Write-Host "WARNING: Certificate generation did not finish in time (status: $finalStatus)"
        Write-Host "Run manually: sudo /usr/local/bin/generate-certificate.sh"
      }
    EOT
  }

  triggers = {
    # Re-run if frontend instance is replaced or domain changes
    frontend_instance_id = module.ec2.frontend_instance_id
    domain_name          = var.domain_name
  }
}
