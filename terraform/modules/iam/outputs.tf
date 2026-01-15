# ============================================================================
# IAM Module Outputs
# ============================================================================

output "frontend_instance_profile_name" {
  description = "Instance profile name for frontend EC2"
  value       = aws_iam_instance_profile.frontend_certbot.name
}

output "frontend_instance_profile_arn" {
  description = "Instance profile ARN for frontend EC2"
  value       = aws_iam_instance_profile.frontend_certbot.arn
}

output "frontend_role_arn" {
  description = "IAM role ARN for frontend EC2"
  value       = aws_iam_role.frontend_certbot.arn
}

output "frontend_role_name" {
  description = "IAM role name for frontend EC2"
  value       = aws_iam_role.frontend_certbot.name
}
