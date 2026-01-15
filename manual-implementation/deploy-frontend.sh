#!/bin/bash
################################################################################
# Frontend Server Setup Script
# 
# This script installs Nginx, builds React app, and configures the web server
# 
# Usage: sudo ./deploy-frontend.sh
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
GIT_REPO="${GIT_REPO:-https://github.com/sarowar-alam/terraform-3-tier-different-servers.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"

# Validate required variables
if [ "$BACKEND_HOST" == "localhost" ]; then
    echo -e "${RED}ERROR: BACKEND_HOST not set!${NC}"
    echo "Please edit this script and set BACKEND_HOST to your backend server IP"
    echo "Example: BACKEND_HOST=\"10.0.2.10\""
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Backend: $BACKEND_HOST:$BACKEND_PORT"
echo "  Domain: $DOMAIN"
echo ""

# Update system
echo -e "${GREEN}[1/5] Updating system packages...${NC}"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install packages
echo -e "${GREEN}[2/5] Installing required packages...${NC}"
apt-get install -y git curl build-essential nginx

# Install Node.js (for building)
echo -e "${GREEN}[3/5] Installing Node.js...${NC}"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

node --version
npm --version

# Setup application
echo -e "${GREEN}[4/5] Setting up application...${NC}"
APP_DIR="/home/ubuntu/app"
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
echo -e "${GREEN}[5/5] Deploying to Nginx...${NC}"
WEB_ROOT="/var/www/$DOMAIN"
mkdir -p $WEB_ROOT
cp -r dist/* $WEB_ROOT/
chown -R www-data:www-data $WEB_ROOT
chmod -R 755 $WEB_ROOT

# Configure Nginx
cat > /etc/nginx/sites-available/$DOMAIN <<EOF
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
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t
systemctl restart nginx
systemctl enable nginx

# Test frontend
echo "Testing frontend..."
sleep 3
curl -f http://localhost/ > /dev/null && echo "✅ Frontend accessible" || echo "⚠️ Warning: Frontend check failed"

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
echo "  Domain: $DOMAIN"
echo "  Web Root: $WEB_ROOT"
echo ""
echo "Next Steps:"
echo "  1. Create SSL certificate with Let's Encrypt (see README.md)"
echo "  2. Create Application Load Balancer"
echo "  3. Add $PRIVATE_IP to ALB target group"
echo "  4. Create Route53 A record: $DOMAIN → ALB"
echo "  5. Test: https://$DOMAIN"
echo ""
echo -e "${YELLOW}Certificate setup is MANUAL - follow the guide in README.md${NC}"
