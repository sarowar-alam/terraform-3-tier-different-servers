# ============================================================================
# Security Groups — Tiered access model
#
# frontend SG : SSH (your IP only), 80, 443 from internet
# backend SG  : backend_port + 22 from frontend SG only
# database SG : db_port from backend SG only; 22 from frontend SG only
# ============================================================================

# ----------------------------------------------------------------------------
# Frontend Security Group
# ----------------------------------------------------------------------------

resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-frontend-sg"
  description = "Frontend server — SSH restricted, HTTP/HTTPS open to internet"
  vpc_id      = var.vpc_id

  # SSH — your IP only (enforced via terraform.tfvars)
  ingress {
    description = "SSH — restricted to operator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  # HTTP
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # All outbound (needed for: apt, git, npm, SSM endpoint, Certbot, backend proxy)
  egress {
    description      = "All outbound"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-frontend-sg"
    Tier = "frontend"
  })
}

# ----------------------------------------------------------------------------
# Backend Security Group
# ----------------------------------------------------------------------------

resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Backend server — only reachable from frontend SG"
  vpc_id      = var.vpc_id

  # Application port — from frontend only
  ingress {
    description     = "Node.js app port from frontend"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # SSH — via frontend as ProxyJump
  ingress {
    description     = "SSH via frontend jump host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # All outbound — NAT GW provides internet access for apt/git/npm/SSM
  egress {
    description = "All outbound via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-backend-sg"
    Tier = "backend"
  })
}

# ----------------------------------------------------------------------------
# Database Security Group
# ----------------------------------------------------------------------------

resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg"
  description = "Database server — PostgreSQL from backend only, SSH from frontend only"
  vpc_id      = var.vpc_id

  # PostgreSQL — from backend SG only
  ingress {
    description     = "PostgreSQL from backend"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  # SSH — via frontend as ProxyJump
  ingress {
    description     = "SSH via frontend jump host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # All outbound — NAT GW provides internet access for apt/git/SSM
  egress {
    description = "All outbound via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-database-sg"
    Tier = "database"
  })
}
