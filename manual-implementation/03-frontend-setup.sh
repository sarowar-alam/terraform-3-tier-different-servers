#!/bin/bash
################################################################################
# Frontend Server Setup Script
# 
# This script installs Nginx, builds React app, and configures SSL with Let's Encrypt
# 
# Usage: sudo BACKEND_HOST=<backend-ip> DOMAIN=bmi.ostaddevops.click ./03-frontend-setup.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=================================="
echo "BMI Health Tracker - Frontend Setup"
echo "==================================${NC}"

# Configuration
BACKEND_HOST="${BACKEND_HOST:-localhost}"
BACKEND_PORT="${BACKEND_PORT:-3000}"
DOMAIN="${DOMAIN:-bmi.ostaddevops.click}"
GIT_REPO="${GIT_REPO:-https://github.com/your-username/bmi-health-tracker.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

# Validate required variables
if [ "$BACKEND_HOST" == "localhost" ]; then
    echo -e "${RED}ERROR: BACKEND_HOST not set!${NC}"
    echo "Usage: sudo BACKEND_HOST=<backend-ip> DOMAIN=bmi.ostaddevops.click ./03-frontend-setup.sh"
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Backend: $BACKEND_HOST:$BACKEND_PORT"
echo "  Domain: $DOMAIN"
echo ""

# Update system
echo -e "${GREEN}[1/8] Updating system packages...${NC}"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install packages
echo -e "${GREEN}[2/8] Installing required packages...${NC}"
apt-get install -y git curl build-essential nginx
apt-get install -y certbot python3-certbot-dns-route53 python3-certbot-nginx awscli

# Install Node.js (for building)
echo -e "${GREEN}[3/8] Installing Node.js...${NC}"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

node --version
npm --version

# Setup application
echo -e "${GREEN}[4/8] Setting up application...${NC}"
APP_DIR="/home/ubuntu/bmi-health-tracker"
mkdir -p $APP_DIR
cd $APP_DIR

# Clone repository
echo "Cloning repository..."
git clone -b $GIT_BRANCH $GIT_REPO .

# Build frontend
cd frontend
echo "Installing dependencies..."
npm install

echo "Building production bundle..."
npm run build

# Deploy to Nginx
echo -e "${GREEN}[5/8] Deploying to Nginx...${NC}"
WEB_ROOT="/var/www/bmi-health-tracker"
mkdir -p $WEB_ROOT
cp -r dist/* $WEB_ROOT/
chown -R www-data:www-data $WEB_ROOT
chmod -R 755 $WEB_ROOT

# Configure Nginx (HTTP only initially)
echo -e "${GREEN}[6/8] Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/bmi-health-tracker <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root $WEB_ROOT;
    index index.html;

    server_tokens off;

    # Frontend - React SPA routing
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Backend API proxy
    location /api/ {
        proxy_pass http://$BACKEND_HOST:$BACKEND_PORT/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    access_log /var/log/nginx/bmi-access.log;
    error_log /var/log/nginx/bmi-error.log;
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/bmi-health-tracker /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t
systemctl restart nginx
systemctl enable nginx

# Test frontend
echo "Testing frontend..."
sleep 3
curl -f http://localhost/ || echo -e "${YELLOW}Warning: Health check failed${NC}"

# Let's Encrypt Certificate
echo -e "${GREEN}[7/8] Setting up Let's Encrypt certificate...${NC}"

# Extract base domain
BASE_DOMAIN="${DOMAIN#*.}"
if [[ "$BASE_DOMAIN" == "$DOMAIN" ]]; then
    BASE_DOMAIN="$DOMAIN"
fi

echo "  Domain: $DOMAIN"
echo "  Base Domain: $BASE_DOMAIN"

# Wait for IAM role propagation
echo "  Waiting for IAM role..."
sleep 30

# Test AWS credentials
aws sts get-caller-identity || echo -e "${YELLOW}Warning: No AWS credentials (certificate generation will fail)${NC}"

# Generate certificate
echo "  Requesting certificate..."
certbot certonly \
  --dns-route53 \
  -d $DOMAIN -d "*.$BASE_DOMAIN" \
  --preferred-challenges dns \
  --agree-tos \
  --non-interactive \
  --email admin@$DOMAIN \
  --keep-until-expiring || {
    echo -e "${YELLOW}Certificate generation failed. Will use HTTP only.${NC}"
}

# If certificate exists, configure HTTPS
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo -e "${GREEN}[8/8] Configuring HTTPS...${NC}"
    
    # Export to ACM
    CERT_ARN=$(aws acm import-certificate \
      --certificate fileb:///etc/letsencrypt/live/$DOMAIN/fullchain.pem \
      --private-key fileb:///etc/letsencrypt/live/$DOMAIN/privkey.pem \
      --tags Key=Name,Value=$DOMAIN-letsencrypt Key=ManagedBy,Value=Certbot \
      --region $AWS_REGION \
      --query 'CertificateArn' \
      --output text 2>/dev/null) || echo "ACM import failed"
    
    if [ ! -z "$CERT_ARN" ]; then
        echo "  Certificate ARN: $CERT_ARN"
        echo "$CERT_ARN" > /tmp/certificate-arn.txt
    fi
    
    # Update Nginx config for HTTPS
    cat > /etc/nginx/sites-available/bmi-health-tracker <<EOF
# HTTP - Redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    root $WEB_ROOT;
    index index.html;

    server_tokens off;

    # Frontend
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Backend API proxy
    location /api/ {
        proxy_pass http://$BACKEND_HOST:$BACKEND_PORT/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    add_header Strict-Transport-Security "max-age=31536000" always;
    
    access_log /var/log/nginx/bmi-access.log;
    error_log /var/log/nginx/bmi-error.log;
}
EOF
    
    nginx -t && systemctl reload nginx
    
    # Setup auto-renewal
    cat > /etc/cron.d/certbot-renew <<'CRON_EOF'
0 0,12 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx"
CRON_EOF
    
fi

# Change ownership
chown -R ubuntu:ubuntu $APP_DIR

# Show info
PRIVATE_IP=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}"
echo "=================================="
echo "Frontend Setup Complete!"
echo "=================================="
echo -e "${NC}"
echo "Frontend Details:"
echo "  Private IP: $PRIVATE_IP"
echo "  HTTP: http://$PRIVATE_IP"
echo "  HTTPS: https://$DOMAIN"
echo "  Web Root: $WEB_ROOT"
echo ""
echo "Next Steps:"
echo "  1. Create Application Load Balancer"
echo "  2. Add $PRIVATE_IP to target group"
echo "  3. Create Route53 A record: $DOMAIN → ALB"
echo "  4. Test: https://$DOMAIN"
echo ""
