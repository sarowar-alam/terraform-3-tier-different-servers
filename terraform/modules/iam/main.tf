# ============================================================================
# IAM Role for Frontend EC2 Instance
# ============================================================================

# IAM Role
resource "aws_iam_role" "frontend_certbot" {
  name = "${var.project_name}-frontend-certbot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-frontend-certbot-role"
    }
  )
}

# IAM Policy for Route53 (DNS Challenge)
resource "aws_iam_role_policy" "route53_certbot" {
  name = "${var.project_name}-route53-certbot-policy"
  role = aws_iam_role.frontend_certbot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:GetChange"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
      }
    ]
  })
}

# IAM Policy for ACM (Certificate Import)
resource "aws_iam_role_policy" "acm_import" {
  name = "${var.project_name}-acm-import-policy"
  role = aws_iam_role.frontend_certbot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm:ImportCertificate",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "acm:AddTagsToCertificate"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "frontend_certbot" {
  name = "${var.project_name}-frontend-certbot-profile"
  role = aws_iam_role.frontend_certbot.name

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-frontend-certbot-profile"
    }
  )
}
