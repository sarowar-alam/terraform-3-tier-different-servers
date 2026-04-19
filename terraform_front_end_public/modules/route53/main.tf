# ============================================================================
# Route53 Module — DNS A record pointing to frontend Elastic IP
# This module is only called after module.ec2 is fully complete (including
# SSM waits and EIP association), enforced by depends_on in root main.tf.
# ============================================================================

resource "aws_route53_record" "frontend" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 60 # Short TTL so cert validation resolves quickly

  records = [var.frontend_ip]

  # Allow overwriting if a record already exists (idempotent re-runs)
  allow_overwrite = true
}
