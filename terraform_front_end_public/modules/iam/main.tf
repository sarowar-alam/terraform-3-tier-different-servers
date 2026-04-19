# ============================================================================
# IAM Module — One role + instance profile per tier
#
# database  : AmazonSSMManagedInstanceCore only
# backend   : AmazonSSMManagedInstanceCore only
# frontend  : AmazonSSMManagedInstanceCore + Route53 (Certbot DNS-01 challenge)
# ============================================================================

# ============================================================================
# Database — SSM only
# ============================================================================

resource "aws_iam_role" "database" {
  name        = "${var.project_name}-database-ssm-role"
  description = "Allows database EC2 to use SSM Session Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-database-ssm-role"
    Tier = "database"
  })
}

resource "aws_iam_role_policy_attachment" "database_ssm" {
  role       = aws_iam_role.database.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "database" {
  name = "${var.project_name}-database-ssm-profile"
  role = aws_iam_role.database.name

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-database-ssm-profile"
    Tier = "database"
  })
}

# ============================================================================
# Backend — SSM only
# ============================================================================

resource "aws_iam_role" "backend" {
  name        = "${var.project_name}-backend-ssm-role"
  description = "Allows backend EC2 to use SSM Session Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-backend-ssm-role"
    Tier = "backend"
  })
}

resource "aws_iam_role_policy_attachment" "backend_ssm" {
  role       = aws_iam_role.backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "backend" {
  name = "${var.project_name}-backend-ssm-profile"
  role = aws_iam_role.backend.name

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-backend-ssm-profile"
    Tier = "backend"
  })
}

# ============================================================================
# Frontend — SSM + Route53 (Certbot DNS-01 challenge)
# ============================================================================

resource "aws_iam_role" "frontend" {
  name        = "${var.project_name}-frontend-certbot-role"
  description = "Allows frontend EC2 to use SSM and manage Route53 for Certbot"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-frontend-certbot-role"
    Tier = "frontend"
  })
}

# SSM Session Manager
resource "aws_iam_role_policy_attachment" "frontend_ssm" {
  role       = aws_iam_role.frontend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Route53 — scoped to the specific hosted zone only (least privilege)
resource "aws_iam_role_policy" "frontend_route53" {
  name = "${var.project_name}-frontend-route53-certbot"
  role = aws_iam_role.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Global read permissions required by certbot-dns-route53
        Sid    = "Route53GlobalRead"
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:GetChange"
        ]
        Resource = "*"
      },
      {
        # Write permission scoped to this hosted zone only
        Sid    = "Route53ZoneWrite"
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

resource "aws_iam_instance_profile" "frontend" {
  name = "${var.project_name}-frontend-certbot-profile"
  role = aws_iam_role.frontend.name

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-frontend-certbot-profile"
    Tier = "frontend"
  })
}
