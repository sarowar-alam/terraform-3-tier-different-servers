output "frontend_sg_id" {
  description = "Security group ID for the frontend server"
  value       = aws_security_group.frontend.id
}

output "backend_sg_id" {
  description = "Security group ID for the backend server"
  value       = aws_security_group.backend.id
}

output "database_sg_id" {
  description = "Security group ID for the database server"
  value       = aws_security_group.database.id
}
