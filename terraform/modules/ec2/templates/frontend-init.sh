#!/bin/bash
################################################################################
# Frontend Server Initialization Script
# This script sets up Nginx and builds/deploys the React frontend
#
# To re-run this script after initial boot:
#   sudo bash /usr/local/bin/init-frontend.sh
################################################################################

set -e

# Logging
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "=================================="
echo "Frontend Server Initialization"
echo "Started: $$(date)"
echo "=================================="

# Save this script to /usr/local/bin for manual re-runs
if [ ! -f /usr/local/bin/init-frontend.sh ]; then
    cat <<'SCRIPT_EOF' > /usr/local/bin/init-frontend.sh
#!/bin/bash
# This is a saved copy of the user-data script
# Run with: sudo bash /usr/local/bin/init-frontend.sh
exec > >(tee -a /var/log/user-data-manual.log)
exec 2>&1
set -e
SCRIPT_EOF
    
    # Append the rest of this script
    tail -n +32 "$$0" >> /usr/local/bin/init-frontend.sh 2>/dev/null || true
    chmod +x /usr/local/bin/init-frontend.sh
    echo "Script saved to /usr/local/bin/init-frontend.sh for manual re-runs"
fi

# Update system
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
apt-get install -y git curl build-essential nginx

# Install Certbot and Route53 plugin
echo "Installing Certbot with Route53 plugin..."
apt-get install -y certbot python3-certbot-dns-route53 python3-certbot-nginx awscli

# Install Node.js 18.x LTS (needed for building)
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verify installations
node --version
npm --version
nginx -v

# Create application directory
echo "Setting up application..."
APP_DIR="/home/ubuntu/bmi-health-tracker"
mkdir -p $$APP_DIR
cd $$APP_DIR

# Clone repository
echo "Cloning repository..."
git clone -b ${git_branch} ${git_repo} .

# Navigate to frontend directory
cd frontend

# Install dependencies
echo "Installing frontend dependencies..."
npm install

# Build production bundle
echo "Building frontend for production..."
npm run build

# Deploy to Nginx web root
echo "Deploying frontend to Nginx..."
WEB_ROOT="/var/www/bmi-health-tracker"
mkdir -p $$WEB_ROOT
cp -r dist/* $$WEB_ROOT/
chown -R www-data:www-data $$WEB_ROOT
chmod -R 755 $$WEB_ROOT

# Configure Nginx
echo "Configuring Nginx..."
cat > /etc/nginx/sites-available/bmi-health-tracker << 'NGINX_EOF'
server {
    listen 80;
    listen [::]:80;
    server_name ${domain_name};

    root /var/www/bmi-health-tracker;
    index index.html;

    # Hide Nginx version
    server_tokens off;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Frontend - React SPA routing
    location / {
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # Backend API proxy
    location /api/ {
        proxy_pass http://${backend_host}:${backend_port}/api/;
        proxy_http_version 1.1;
        
        # Proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Disable buffering for real-time responses
        proxy_buffering off;
        
        # Don't cache API responses
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Health check endpoint (for ALB)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Custom error pages
    error_page 404 /index.html;
    error_page 500 502 503 504 /index.html;

    # Logs
    access_log /var/log/nginx/bmi-access.log;
    error_log /var/log/nginx/bmi-error.log;
}
NGINX_EOF

# Enable site
ln -sf /etc/nginx/sites-available/bmi-health-tracker /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "Testing Nginx configuration..."
nginx -t

# Restart Nginx
echo "Restarting Nginx..."
systemctl restart nginx
systemctl enable nginx

# Verify Nginx is running
systemctl status nginx --no-pager

# Test frontend
echo "Testing frontend..."
sleep 5
curl -f http://localhost/ || echo "Warning: Frontend health check failed"

# Change ownership
chown -R ubuntu:ubuntu $$APP_DIR

# ============================================================================
# Let's Encrypt Certificate Generation
# ============================================================================

echo "=================================="
echo "Generating Let's Encrypt Certificate"
echo "=================================="

# Extract base domain from full domain
BASE_DOMAIN="$${domain_name#*.}"
if [[ "$$BASE_DOMAIN" == "${domain_name}" ]]; then
    # No subdomain, use as is
    BASE_DOMAIN="${domain_name}"
fi

echo "Domain: ${domain_name}"
echo "Base Domain: $$BASE_DOMAIN"

# Wait for IAM role to propagate
echo "Waiting for IAM role to propagate..."
sleep 30

# Test AWS credentials
echo "Testing AWS credentials..."
aws sts get-caller-identity || echo "Warning: AWS credentials not available yet"

# Issue Let's Encrypt wildcard certificate
echo "Requesting Let's Encrypt certificate..."
certbot certonly \
  --dns-route53 \
  -d ${domain_name} -d "*.$$BASE_DOMAIN" \
  --preferred-challenges dns \
  --agree-tos \
  --non-interactive \
  --email admin@${domain_name} \
  --keep-until-expiring || echo "Warning: Certificate generation failed, will retry later"

# Check if certificate was generated
if [ -f "/etc/letsencrypt/live/${domain_name}/fullchain.pem" ]; then
    echo "Certificate generated successfully!"
    
    # ========================================================================
    # Export Certificate to AWS ACM
    # ========================================================================
    
    echo "Exporting certificate to AWS ACM..."
    
    CERT_ARN=$$(aws acm import-certificate \
      --certificate fileb:///etc/letsencrypt/live/${domain_name}/fullchain.pem \
      --private-key fileb:///etc/letsencrypt/live/${domain_name}/privkey.pem \
      --tags Key=Name,Value=${domain_name}-letsencrypt Key=ManagedBy,Value=Certbot Key=Domain,Value=${domain_name} Key=Project,Value=bmi-health-tracker Key=TerraformManaged,Value=true \
      --region ${aws_region} \
      --query 'CertificateArn' \
      --output text) || echo "Warning: Certificate import failed"
    
    if [ ! -z "$$CERT_ARN" ]; then
        echo "Certificate imported to ACM!"
        echo "Certificate ARN: $$CERT_ARN"
        echo "$$CERT_ARN" > /tmp/certificate-arn.txt
    fi
    
    # Update Nginx to use Let's Encrypt certificates
    echo "Updating Nginx to use HTTPS..."
    
    cat > /etc/nginx/sites-available/bmi-health-tracker << NGINX_HTTPS_EOF
# HTTP - Redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${domain_name};
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${domain_name};

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/${domain_name}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain_name}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    root /var/www/bmi-health-tracker;
    index index.html;

    # Hide Nginx version
    server_tokens off;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Frontend - React SPA routing
    location / {
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # Backend API proxy
    location /api/ {
        proxy_pass http://${backend_host}:${backend_port}/api/;
        proxy_http_version 1.1;
        
        # Proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Disable buffering for real-time responses
        proxy_buffering off;
        
        # Don't cache API responses
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Health check endpoint (for ALB)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Custom error pages
    error_page 404 /index.html;
    error_page 500 502 503 504 /index.html;

    # Logs
    access_log /var/log/nginx/bmi-access.log;
    error_log /var/log/nginx/bmi-error.log;
}
NGINX_HTTPS_EOF
    
    # Test and reload Nginx
    nginx -t && systemctl reload nginx
    echo "Nginx configured for HTTPS"
    
    # Setup automatic certificate renewal
    echo "Setting up automatic certificate renewal..."
    cat > /etc/cron.d/certbot-renew << 'CRON_EOF'
0 0,12 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx && /usr/local/bin/update-acm-cert.sh"
CRON_EOF
    
    # Create ACM update script
    cat > /usr/local/bin/update-acm-cert.sh << 'ACM_UPDATE_EOF'
#!/bin/bash
# Update ACM certificate after renewal
DOMAIN="${domain_name}"
CERT_ARN_FILE="/tmp/certificate-arn.txt"

if [ -f "$$CERT_ARN_FILE" ]; then
    CERT_ARN=$$(cat "$$CERT_ARN_FILE")
    aws acm import-certificate \
      --certificate-arn "$$CERT_ARN" \
      --certificate fileb:///etc/letsencrypt/live/$$DOMAIN/fullchain.pem \
      --private-key fileb:///etc/letsencrypt/live/$$DOMAIN/privkey.pem \
      --region ${aws_region} || echo "Failed to update ACM certificate"
else
    echo "Certificate ARN file not found"
fi
ACM_UPDATE_EOF
    
    chmod +x /usr/local/bin/update-acm-cert.sh
    
else
    echo "Warning: Certificate generation failed. System will retry on next reboot."
fi

echo "=================================="
echo "Frontend Server Initialization Complete"
echo "Completed: $(date)"
echo "=================================="
echo "Frontend URL: http://localhost"
echo "HTTPS URL: https://${domain_name}"
echo "Web Root: $$WEB_ROOT"
echo "Nginx Config: /etc/nginx/sites-available/bmi-health-tracker"
echo "Certificate: /etc/letsencrypt/live/${domain_name}/"
echo "=================================="
echo "Nginx Status:"
systemctl status nginx --no-pager | head -n 10
echo "=================================="
