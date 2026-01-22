# ============================================================================
# Route53 A Record (Alias to ALB)
# ============================================================================

resource "aws_route53_record" "main" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = "dualstack.${var.alb_dns_name}"
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# ============================================================================
# ACM Certificate Validation Records
# ============================================================================
# Certificate validation is handled by Certbot using DNS-01 challenge
# Certbot will automatically create and remove TXT records in Route53
# No manual validation records needed
