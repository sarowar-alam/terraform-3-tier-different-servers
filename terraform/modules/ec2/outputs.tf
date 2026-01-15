# ============================================================================
# EC2 Module Outputs
# ============================================================================

output "database_instance_id" {
  description = "Database instance ID"
  value       = aws_instance.database.id
}

output "database_private_ip" {
  description = "Database private IP"
  value       = aws_instance.database.private_ip
}

output "backend_instance_id" {
  description = "Backend instance ID"
  value       = aws_instance.backend.id
}

output "backend_private_ip" {
  description = "Backend private IP"
  value       = aws_instance.backend.private_ip
}

output "frontend_instance_id" {
  description = "Frontend instance ID"
  value       = aws_instance.frontend.id
}

output "frontend_private_ip" {
  description = "Frontend private IP"
  value       = aws_instance.frontend.private_ip
}

output "imported_certificate_arn" {
  description = "ARN of the imported Let's Encrypt certificate from Certbot"
  value       = data.aws_acm_certificate.imported.arn
}
