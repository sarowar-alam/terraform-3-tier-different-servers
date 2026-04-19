# Database
output "database_instance_profile_name" {
  description = "IAM instance profile name for the database server"
  value       = aws_iam_instance_profile.database.name
}

output "database_instance_profile_arn" {
  description = "IAM instance profile ARN for the database server"
  value       = aws_iam_instance_profile.database.arn
}

# Backend
output "backend_instance_profile_name" {
  description = "IAM instance profile name for the backend server"
  value       = aws_iam_instance_profile.backend.name
}

output "backend_instance_profile_arn" {
  description = "IAM instance profile ARN for the backend server"
  value       = aws_iam_instance_profile.backend.arn
}

# Frontend
output "frontend_instance_profile_name" {
  description = "IAM instance profile name for the frontend server (SSM + Certbot)"
  value       = aws_iam_instance_profile.frontend.name
}

output "frontend_instance_profile_arn" {
  description = "IAM instance profile ARN for the frontend server"
  value       = aws_iam_instance_profile.frontend.arn
}

output "frontend_role_arn" {
  description = "IAM role ARN for the frontend server"
  value       = aws_iam_role.frontend.arn
}
