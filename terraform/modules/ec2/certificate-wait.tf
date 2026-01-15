# ============================================================================
# Wait for Certbot Certificate Import
# ============================================================================
# This resource waits for the frontend instance to import the certificate to ACM
# It polls ACM every 30 seconds until the certificate is found

resource "null_resource" "wait_for_certificate" {
  depends_on = [aws_instance.frontend]

  provisioner "local-exec" {
    command = <<-EOT
      $maxAttempts = 20
      $attempt = 0
      $found = $false
      
      Write-Host "Waiting for Certbot to import certificate to ACM..."
      Write-Host "This may take 5-10 minutes..."
      
      while ($attempt -lt $maxAttempts -and -not $found) {
        $attempt++
        Write-Host "Attempt $attempt/$maxAttempts - Checking for certificate..."
        
        $certs = aws acm list-certificates `
          --region ${var.aws_region} `
          --profile ${var.aws_profile} `
          --query "CertificateSummaryList[?contains(DomainName, '${var.domain_name}')].CertificateArn" `
          --output text
        
        if ($certs) {
          # Check if certificate has the Certbot tag
          $tags = aws acm list-tags-for-certificate `
            --certificate-arn $certs `
            --region ${var.aws_region} `
            --profile ${var.aws_profile} `
            --query "Tags[?Key=='ManagedBy' && Value=='Certbot']" `
            --output text
          
          if ($tags) {
            Write-Host "✓ Certificate found: $certs"
            $found = $true
          }
        }
        
        if (-not $found -and $attempt -lt $maxAttempts) {
          Write-Host "Certificate not found yet. Waiting 30 seconds..."
          Start-Sleep -Seconds 30
        }
      }
      
      if (-not $found) {
        Write-Host "ERROR: Certificate not found after $maxAttempts attempts"
        Write-Host "Check frontend instance logs: /var/log/user-data.log"
        exit 1
      }
    EOT

    interpreter = ["PowerShell", "-Command"]
  }

  triggers = {
    frontend_instance_id = aws_instance.frontend.id
  }
}

# ============================================================================
# Data Source: Fetch Imported Certificate
# ============================================================================
# This fetches the certificate that was imported by Certbot

data "aws_acm_certificate" "imported" {
  depends_on = [null_resource.wait_for_certificate]

  domain      = var.domain_name
  most_recent = true
  statuses    = ["ISSUED"]

  # This will only find certificates that match the domain
  # Certbot imports with status ISSUED immediately
}
