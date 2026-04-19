# Frontend
output "frontend_public_ip" {
  description = "Elastic IP (stable public IP) of the frontend server"
  value       = aws_eip.frontend.public_ip
}

output "frontend_instance_id" {
  description = "Frontend EC2 instance ID"
  value       = aws_instance.frontend.id
}

output "frontend_private_ip" {
  description = "Frontend private IP within the VPC"
  value       = aws_instance.frontend.private_ip
}

# Backend
output "backend_instance_id" {
  description = "Backend EC2 instance ID"
  value       = aws_instance.backend.id
}

output "backend_private_ip" {
  description = "Backend private IP within the VPC"
  value       = aws_instance.backend.private_ip
}

# Database
output "database_instance_id" {
  description = "Database EC2 instance ID"
  value       = aws_instance.database.id
}

output "database_private_ip" {
  description = "Database private IP within the VPC"
  value       = aws_instance.database.private_ip
}
