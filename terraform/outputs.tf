# ============================================================================
# Application URLs
# ============================================================================

output "application_url" {
  description = "Main application URL"
  value       = "https://${var.domain_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name (for testing before DNS propagation)"
  value       = module.alb.alb_dns_name
}

# ============================================================================
# EC2 Instance Information
# ============================================================================

output "database_private_ip" {
  description = "Database server private IP address"
  value       = module.ec2.database_private_ip
}

output "backend_private_ip" {
  description = "Backend server private IP address"
  value       = module.ec2.backend_private_ip
}

output "frontend_private_ip" {
  description = "Frontend server private IP address"
  value       = module.ec2.frontend_private_ip
}

output "database_instance_id" {
  description = "Database EC2 instance ID"
  value       = module.ec2.database_instance_id
}

output "backend_instance_id" {
  description = "Backend EC2 instance ID"
  value       = module.ec2.backend_instance_id
}

output "frontend_instance_id" {
  description = "Frontend EC2 instance ID"
  value       = module.ec2.frontend_instance_id
}

# ============================================================================
# Load Balancer Information
# ============================================================================

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "Frontend target group ARN"
  value       = module.alb.target_group_arn
}

# ============================================================================
# SSL Certificate Information
# ============================================================================

output "certificate_arn" {
  description = "ARN of the imported Let's Encrypt certificate"
  value       = module.ec2.imported_certificate_arn
}

output "certificate_info" {
  description = "Certificate information"
  value = {
    status           = "Certificate created by Certbot and imported to ACM"
    arn              = module.ec2.imported_certificate_arn
    domain           = var.domain_name
    certificate_path = "/etc/letsencrypt/live/${var.domain_name}/fullchain.pem"
    private_key_path = "/etc/letsencrypt/live/${var.domain_name}/privkey.pem"
    renewal_command  = "certbot renew --quiet"
  }
}

# ============================================================================
# IAM Information
# ============================================================================

output "frontend_iam_role" {
  description = "IAM role for frontend EC2 instance"
  value       = module.iam.frontend_role_name
}

output "frontend_iam_role_arn" {
  description = "IAM role ARN for frontend EC2 instance"
  value       = module.iam.frontend_role_arn
}

output "frontend_instance_profile" {
  description = "Instance profile attached to frontend EC2"
  value       = module.iam.frontend_instance_profile_name
}

# ============================================================================
# DNS Information
# ============================================================================

output "route53_record_name" {
  description = "Route53 record name"
  value       = module.dns.record_name
}

output "route53_record_fqdn" {
  description = "Route53 record FQDN"
  value       = module.dns.record_fqdn
}

# ============================================================================
# Connection Information
# ============================================================================

output "ssh_commands" {
  description = "SSH commands to connect to instances (requires bastion or VPN)"
  value = {
    database = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.ec2.database_private_ip}"
    backend  = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.ec2.backend_private_ip}"
    frontend = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.ec2.frontend_private_ip}"
  }
}

# ============================================================================
# Deployment Status
# ============================================================================

output "deployment_info" {
  description = "Deployment information and next steps"
  value = {
    status = "Infrastructure deployed successfully with HTTPS"
    next_steps = [
      "1. Infrastructure deployed in ~10-15 minutes (includes certificate wait time)",
      "2. Terraform automatically waited for Certbot to import certificate",
      "3. ALB is configured with HTTPS and redirects HTTP to HTTPS",
      "4. Test application: https://${var.domain_name}",
      "5. Monitor deployment: SSH to instances and check /var/log/user-data.log",
      "6. Certificate auto-renews via cron job on frontend instance"
    ]
  }
}
