# ============================================================================
# Root Module Outputs
# ============================================================================

output "application_url" {
  description = "HTTPS application URL"
  value       = "https://${var.domain_name}"
}

output "application_url_http" {
  description = "HTTP URL — will redirect to HTTPS after certificate is issued"
  value       = "http://${var.domain_name}"
}

# ----------------------------------------------------------------------------
# Frontend
# ----------------------------------------------------------------------------

output "frontend_public_ip" {
  description = "Elastic IP of the frontend server (stable public IP)"
  value       = module.ec2.frontend_public_ip
}

output "frontend_instance_id" {
  description = "Frontend EC2 instance ID"
  value       = module.ec2.frontend_instance_id
}

output "frontend_private_ip" {
  description = "Frontend private IP (within VPC)"
  value       = module.ec2.frontend_private_ip
}

# ----------------------------------------------------------------------------
# Backend
# ----------------------------------------------------------------------------

output "backend_instance_id" {
  description = "Backend EC2 instance ID"
  value       = module.ec2.backend_instance_id
}

output "backend_private_ip" {
  description = "Backend private IP — not reachable from the internet"
  value       = module.ec2.backend_private_ip
}

# ----------------------------------------------------------------------------
# Database
# ----------------------------------------------------------------------------

output "database_instance_id" {
  description = "Database EC2 instance ID"
  value       = module.ec2.database_instance_id
}

output "database_private_ip" {
  description = "Database private IP — not reachable from the internet"
  value       = module.ec2.database_private_ip
}

# ----------------------------------------------------------------------------
# Network
# ----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ip" {
  description = "Elastic IP of the NAT Gateway (outbound IP for private instances)"
  value       = module.vpc.nat_gateway_ip
}

# ----------------------------------------------------------------------------
# DNS
# ----------------------------------------------------------------------------

output "route53_record_fqdn" {
  description = "Fully qualified domain name created in Route53"
  value       = var.domain_name
}

# ----------------------------------------------------------------------------
# SSH Access
# ----------------------------------------------------------------------------

output "ssh_frontend" {
  description = "SSH command for the frontend server (direct, it is public)"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${module.ec2.frontend_public_ip}"
}

output "ssh_backend" {
  description = "SSH command for backend via frontend as ProxyJump"
  value       = "ssh -i ${var.key_name}.pem -J ubuntu@${module.ec2.frontend_public_ip} ubuntu@${module.ec2.backend_private_ip}"
}

output "ssh_database" {
  description = "SSH command for database via frontend as ProxyJump"
  value       = "ssh -i ${var.key_name}.pem -J ubuntu@${module.ec2.frontend_public_ip} ubuntu@${module.ec2.database_private_ip}"
}

# ----------------------------------------------------------------------------
# SSM Connect (no SSH key required)
# ----------------------------------------------------------------------------

output "ssm_connect_frontend" {
  description = "AWS CLI command to open SSM session on frontend"
  value       = "aws ssm start-session --target ${module.ec2.frontend_instance_id} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "ssm_connect_backend" {
  description = "AWS CLI command to open SSM session on backend"
  value       = "aws ssm start-session --target ${module.ec2.backend_instance_id} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "ssm_connect_database" {
  description = "AWS CLI command to open SSM session on database"
  value       = "aws ssm start-session --target ${module.ec2.database_instance_id} --region ${var.aws_region} --profile ${var.aws_profile}"
}

# ----------------------------------------------------------------------------
# Deployment Summary
# ----------------------------------------------------------------------------

output "deployment_summary" {
  description = "Human-readable deployment summary"
  value       = <<-EOT

    ================================================
     Deployment Complete
    ================================================
     App URL (HTTPS) : https://${var.domain_name}
     App URL (HTTP)  : http://${var.domain_name}  →  301 redirect
     Frontend EIP    : ${module.ec2.frontend_public_ip}
     Backend IP      : ${module.ec2.backend_private_ip}  (private)
     Database IP     : ${module.ec2.database_private_ip}  (private)
     VPC             : ${module.vpc.vpc_id}
     NAT Gateway     : ${module.vpc.nat_gateway_ip}
    ------------------------------------------------
     NOTE: Allow 2-3 min for DNS to propagate.
     SSL certificate is managed by Let's Encrypt
     and auto-renews every 60 days via cron.
    ================================================

  EOT
}
