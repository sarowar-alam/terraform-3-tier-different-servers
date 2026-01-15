# ============================================================================
# Database EC2 Instance
# ============================================================================

resource "aws_instance" "database" {
  ami                    = var.ami_id
  instance_type          = var.instance_type_database
  key_name               = var.key_name
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.database_security_group_id]

  user_data = templatefile("${path.module}/templates/database-init.sh", {
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
    db_port     = var.db_port
    git_repo    = var.git_repo_url
    git_branch  = var.git_branch
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-database"
      Tier = "database"
    }
  )

  lifecycle {
    create_before_destroy = false
  }
}

# ============================================================================
# Backend EC2 Instance
# ============================================================================

resource "aws_instance" "backend" {
  ami                    = var.ami_id
  instance_type          = var.instance_type_backend
  key_name               = var.key_name
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.backend_security_group_id]

  user_data = templatefile("${path.module}/templates/backend-init.sh", {
    db_host      = aws_instance.database.private_ip
    db_port      = var.db_port
    db_name      = var.db_name
    db_user      = var.db_user
    db_password  = var.db_password
    backend_port = var.backend_port
    frontend_url = "https://${var.domain_name}"
    git_repo     = var.git_repo_url
    git_branch   = var.git_branch
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-backend"
      Tier = "backend"
    }
  )

  depends_on = [aws_instance.database]

  lifecycle {
    create_before_destroy = false
  }
}

# ============================================================================
# Frontend EC2 Instance
# ============================================================================

resource "aws_instance" "frontend" {
  ami                    = var.ami_id
  instance_type          = var.instance_type_frontend
  key_name               = var.key_name
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.frontend_security_group_id]
  iam_instance_profile   = var.frontend_instance_profile_name

  user_data = templatefile("${path.module}/templates/frontend-init.sh", {
    backend_host = aws_instance.backend.private_ip
    backend_port = var.backend_port
    domain_name  = var.domain_name
    git_repo     = var.git_repo_url
    git_branch   = var.git_branch
    aws_region   = var.aws_region
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-frontend"
      Tier = "frontend"
    }
  )

  depends_on = [aws_instance.backend]

  lifecycle {
    create_before_destroy = false
  }
}

# ============================================================================
# Attach Frontend Instance to Target Group
# ============================================================================

resource "aws_lb_target_group_attachment" "frontend" {
  target_group_arn = var.frontend_target_group_arn
  target_id        = aws_instance.frontend.id
  port             = 80

  depends_on = [aws_instance.frontend]
}
