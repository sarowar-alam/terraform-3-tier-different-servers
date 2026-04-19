# ============================================================================
# EC2 Module — Three-tier EC2 instances with strict dependency chain
#
# Deployment order:
#   1. aws_instance.database   (private subnet)
#      └─ null_resource.wait_ssm_database  [polls SSM until Online]
#   2. aws_instance.backend    (private subnet, depends on SSM wait above)
#      └─ null_resource.wait_ssm_backend   [polls SSM until Online]
#   3. aws_instance.frontend   (public subnet,  depends on SSM wait above)
#      └─ null_resource.wait_ssm_frontend  [polls SSM until Online]
#   4. aws_eip_association.frontend  (stable public IP attached to frontend)
#
# The cert script is written to /usr/local/bin/generate-certificate.sh during
# frontend user_data. It is triggered LATER by SSM Run Command from root
# main.tf after Route53 is configured.
# ============================================================================

# ----------------------------------------------------------------------------
# Locals — pre-render the certificate script so it can be embedded in
# frontend_setup.sh as a templatefile variable (avoids nested templatefile calls)
# ----------------------------------------------------------------------------

locals {
  cert_script = templatefile("${path.root}/scripts/generate_certificate.sh", {
    domain_name = var.domain_name
    aws_region  = var.aws_region
  })
}

# ----------------------------------------------------------------------------
# Elastic IP — stable public IP for the frontend server
# Created early so Route53 can reference it; associated after instance boots
# ----------------------------------------------------------------------------

resource "aws_eip" "frontend" {
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-frontend-eip"
    Tier = "frontend"
  })
}

# ============================================================================
# 1. DATABASE INSTANCE
# ============================================================================

resource "aws_instance" "database" {
  ami                    = var.ami_id
  instance_type          = var.instance_type_database
  key_name               = var.key_name
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.database_security_group_id]
  iam_instance_profile   = var.database_instance_profile_name

  # Replace instance (not just restart) when user_data changes
  user_data_replace_on_change = true

  user_data = templatefile("${path.root}/scripts/database_setup.sh", {
    db_name    = var.db_name
    db_user    = var.db_user
    db_password = var.db_password
    db_port    = var.db_port
    git_repo   = var.git_repo_url
    git_branch = var.git_branch
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-database"
    Tier = "database"
  })
}

# ----------------------------------------------------------------------------
# Wait: poll SSM until database instance is Online (confirms boot + SSM agent)
# Polls every 20 s, max 30 attempts = up to 10 minutes
# ----------------------------------------------------------------------------

resource "null_resource" "wait_ssm_database" {
  depends_on = [aws_instance.database]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $instanceId = "${aws_instance.database.id}"
      $region     = "${var.aws_region}"
      $profile    = "${var.aws_profile}"

      Write-Host ">>> [DATABASE] Waiting for SSM agent to come Online..."
      Write-Host "    Instance : $instanceId"

      $maxAttempts = 30
      $attempt     = 0
      $status      = ""

      while ($attempt -lt $maxAttempts) {
        $attempt++
        $status = aws ssm describe-instance-information `
          --filters "Key=InstanceIds,Values=$instanceId" `
          --region $region `
          --profile $profile `
          --query "InstanceInformationList[0].PingStatus" `
          --output text 2>$null

        Write-Host "    [$attempt/$maxAttempts] SSM PingStatus = $status"

        if ($status -eq "Online") {
          Write-Host ">>> [DATABASE] SSM Online. Proceeding to backend."
          break
        }

        if ($attempt -lt $maxAttempts) { Start-Sleep -Seconds 20 }
      }

      if ($status -ne "Online") {
        Write-Host "ERROR: Database SSM wait timed out after $maxAttempts attempts."
        Write-Host "Check instance logs: aws ssm start-session --target $instanceId"
        exit 1
      }
    EOT
  }

  triggers = {
    instance_id = aws_instance.database.id
  }
}

# ============================================================================
# 2. BACKEND INSTANCE
#    Only created after database SSM wait passes.
#    user_data smart-polls :5432 before starting Node.js.
# ============================================================================

resource "aws_instance" "backend" {
  ami                    = var.ami_id
  instance_type          = var.instance_type_backend
  key_name               = var.key_name
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.backend_security_group_id]
  iam_instance_profile   = var.backend_instance_profile_name

  # Do not create backend until database SSM is confirmed Online
  depends_on = [null_resource.wait_ssm_database]

  user_data_replace_on_change = true

  user_data = templatefile("${path.root}/scripts/backend_setup.sh", {
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

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-backend"
    Tier = "backend"
  })
}

# ----------------------------------------------------------------------------
# Wait: poll SSM until backend instance is Online
# ----------------------------------------------------------------------------

resource "null_resource" "wait_ssm_backend" {
  depends_on = [aws_instance.backend]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $instanceId = "${aws_instance.backend.id}"
      $region     = "${var.aws_region}"
      $profile    = "${var.aws_profile}"

      Write-Host ">>> [BACKEND] Waiting for SSM agent to come Online..."
      Write-Host "    Instance : $instanceId"

      $maxAttempts = 30
      $attempt     = 0
      $status      = ""

      while ($attempt -lt $maxAttempts) {
        $attempt++
        $status = aws ssm describe-instance-information `
          --filters "Key=InstanceIds,Values=$instanceId" `
          --region $region `
          --profile $profile `
          --query "InstanceInformationList[0].PingStatus" `
          --output text 2>$null

        Write-Host "    [$attempt/$maxAttempts] SSM PingStatus = $status"

        if ($status -eq "Online") {
          Write-Host ">>> [BACKEND] SSM Online. Proceeding to frontend."
          break
        }

        if ($attempt -lt $maxAttempts) { Start-Sleep -Seconds 20 }
      }

      if ($status -ne "Online") {
        Write-Host "ERROR: Backend SSM wait timed out after $maxAttempts attempts."
        Write-Host "Check instance logs: aws ssm start-session --target $instanceId"
        exit 1
      }
    EOT
  }

  triggers = {
    instance_id = aws_instance.backend.id
  }
}

# ============================================================================
# 3. FRONTEND INSTANCE
#    Only created after backend SSM wait passes.
#    user_data smart-polls backend :3000/health before building.
#    Writes /usr/local/bin/generate-certificate.sh but does NOT run it yet.
# ============================================================================

resource "aws_instance" "frontend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type_frontend
  key_name                    = var.key_name
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.frontend_security_group_id]
  iam_instance_profile        = var.frontend_instance_profile_name
  associate_public_ip_address = false # We attach an Elastic IP instead

  # Do not create frontend until backend SSM is confirmed Online
  depends_on = [null_resource.wait_ssm_backend]

  user_data_replace_on_change = true

  user_data = templatefile("${path.root}/scripts/frontend_setup.sh", {
    backend_host = aws_instance.backend.private_ip
    backend_port = var.backend_port
    domain_name  = var.domain_name
    git_repo     = var.git_repo_url
    git_branch   = var.git_branch
    aws_region   = var.aws_region
    cert_script  = local.cert_script
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-frontend"
    Tier = "frontend"
  })
}

# ----------------------------------------------------------------------------
# Wait: poll SSM until frontend instance is Online
# ----------------------------------------------------------------------------

resource "null_resource" "wait_ssm_frontend" {
  depends_on = [aws_instance.frontend]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $instanceId = "${aws_instance.frontend.id}"
      $region     = "${var.aws_region}"
      $profile    = "${var.aws_profile}"

      Write-Host ">>> [FRONTEND] Waiting for SSM agent to come Online..."
      Write-Host "    Instance : $instanceId"

      $maxAttempts = 30
      $attempt     = 0
      $status      = ""

      while ($attempt -lt $maxAttempts) {
        $attempt++
        $status = aws ssm describe-instance-information `
          --filters "Key=InstanceIds,Values=$instanceId" `
          --region $region `
          --profile $profile `
          --query "InstanceInformationList[0].PingStatus" `
          --output text 2>$null

        Write-Host "    [$attempt/$maxAttempts] SSM PingStatus = $status"

        if ($status -eq "Online") {
          Write-Host ">>> [FRONTEND] SSM Online. Ready for Route53 and certificate."
          break
        }

        if ($attempt -lt $maxAttempts) { Start-Sleep -Seconds 20 }
      }

      if ($status -ne "Online") {
        Write-Host "ERROR: Frontend SSM wait timed out after $maxAttempts attempts."
        Write-Host "Check instance logs: aws ssm start-session --target $instanceId"
        exit 1
      }
    EOT
  }

  triggers = {
    instance_id = aws_instance.frontend.id
  }
}

# ----------------------------------------------------------------------------
# Associate Elastic IP with frontend instance
# Both the EIP association and SSM wait must complete before root module
# creates the Route53 record — enforced via depends_on = [module.ec2] in root.
# ----------------------------------------------------------------------------

resource "aws_eip_association" "frontend" {
  instance_id   = aws_instance.frontend.id
  allocation_id = aws_eip.frontend.id

  depends_on = [aws_instance.frontend]
}
