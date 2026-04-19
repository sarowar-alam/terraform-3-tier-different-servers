output "record_name" {
  description = "DNS record name created in Route53"
  value       = aws_route53_record.frontend.name
}

output "record_fqdn" {
  description = "Fully qualified domain name of the Route53 record"
  value       = aws_route53_record.frontend.fqdn
}

output "record_type" {
  description = "DNS record type"
  value       = aws_route53_record.frontend.type
}
