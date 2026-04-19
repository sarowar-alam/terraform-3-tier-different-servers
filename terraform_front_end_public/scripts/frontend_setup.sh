#!/bin/bash
################################################################################
# Frontend Server Initialization Script
# Templatefile variables:
#   backend_host, backend_port, domain_name, git_repo, git_branch,
#   aws_region, cert_script
#
# This script:
#   1. Installs Nginx, Node.js, snap Certbot (HTTP-01 — no AWS CLI needed)
#   2. Waits for backend health endpoint before building
#   3. Builds and deploys the React frontend
#   4. Configures Nginx with HTTP-only config initially
#   5. Writes /usr/local/bin/generate-certificate.sh (run later via SSM)
#
# Re-run manually:  sudo bash /usr/local/bin/init-frontend.sh
################################################################################

# Allow errors — Nginx or build failures should not abort the whole script
set +e
exec > >(tee -a /var/log/user-data.log) 2>&1

echo "======================================================"
echo " Frontend Server Initialization — $(date)"
echo "======================================================"

# ----------------------------------------------------------------------------
# System update
# ----------------------------------------------------------------------------
echo "[1/8] Updating system packages..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# ----------------------------------------------------------------------------
# Install required packages
# ----------------------------------------------------------------------------
echo "[2/8] Installing Nginx, Node.js, git, snap certbot..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  git curl build-essential nginx netcat-openbsd snapd

# Install certbot via snap — official recommended method on Ubuntu 24.04
# HTTP-01 challenge (--nginx): no AWS credentials or DNS plugin required.
# Requires port 80 open and A record pointing to this server's EIP.
echo "Installing certbot via snap..."
systemctl start snapd.socket 2>/dev/null || true
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot
certbot --version

# Verify SSM agent is running (pre-installed on Ubuntu 24.04 AWS AMIs)
echo "Verifying SSM agent..."
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || true
systemctl start  snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || \
  systemctl start amazon-ssm-agent 2>/dev/null || true

# Install Node.js 20.x LTS (needed to build the React app)
echo "Installing Node.js 20.x LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null
apt-get install -y nodejs
node --version
npm  --version

# ----------------------------------------------------------------------------
# Wait for backend health endpoint before building
# Polls every 10 s, max 30 attempts = up to 5 minutes
# ----------------------------------------------------------------------------
echo "[3/8] Waiting for backend at ${backend_host}:${backend_port}/health..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  if curl -sf "http://${backend_host}:${backend_port}/health" > /dev/null 2>&1; then
    echo "  [$ATTEMPT/$MAX_ATTEMPTS] Backend healthy — continuing"
    break
  fi
  echo "  [$ATTEMPT/$MAX_ATTEMPTS] Not ready yet — retrying in 10 s..."
  sleep 10
done

if ! curl -sf "http://${backend_host}:${backend_port}/health" > /dev/null 2>&1; then
  echo "WARNING: Backend health check failed. Continuing — Nginx proxy will retry."
fi

# ----------------------------------------------------------------------------
# Clone repo and build React frontend
# ----------------------------------------------------------------------------
echo "[4/8] Building React frontend..."
APP_DIR="/home/ubuntu/bmi-health-tracker"
mkdir -p $${APP_DIR}
cd $${APP_DIR}

git clone -b ${git_branch} ${git_repo} . || {
  echo "ERROR: Failed to clone ${git_repo}"
  exit 1
}

cd frontend
npm install
npm run build

# Deploy to Nginx web root
echo "[5/8] Deploying to Nginx web root..."
WEB_ROOT="/var/www/bmi-health-tracker"
mkdir -p $${WEB_ROOT}
cp -r dist/* $${WEB_ROOT}/
chown -R www-data:www-data $${WEB_ROOT}
chmod -R 755 $${WEB_ROOT}

# ----------------------------------------------------------------------------
# Configure Nginx — HTTP only (certificate added later by generate-certificate.sh)
# ----------------------------------------------------------------------------
echo "[6/8] Configuring Nginx (HTTP only)..."
cat > /etc/nginx/sites-available/bmi-health-tracker << 'NGINX_EOF'
server {
    listen 80;
    listen [::]:80;
    server_name ${domain_name};

    root /var/www/bmi-health-tracker;
    index index.html;

    server_tokens off;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript
               application/javascript application/xml+rss application/json;

    # React SPA — serve index.html for unknown routes
    location / {
        try_files $uri $uri/ /index.html;

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # Backend API proxy
    location /api/ {
        proxy_pass http://${backend_host}:${backend_port}/api/;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        "upgrade";
        proxy_connect_timeout 60s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
        proxy_buffering       off;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Health check (used to confirm Nginx is up)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Security headers
    add_header X-Frame-Options       "SAMEORIGIN"  always;
    add_header X-Content-Type-Options "nosniff"    always;
    add_header X-XSS-Protection      "1; mode=block" always;

    access_log /var/log/nginx/bmi-access.log;
    error_log  /var/log/nginx/bmi-error.log;
}
NGINX_EOF

ln -sf /etc/nginx/sites-available/bmi-health-tracker /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl restart nginx
systemctl enable nginx

echo "  HTTP health check:"
sleep 3
curl -sf http://localhost/health && echo "  Nginx OK" || echo "  WARNING: Nginx health check failed"

# ----------------------------------------------------------------------------
# Write the certificate generation script
# (Terraform rendered this template separately; the content is injected here)
# It will be executed later via SSM Run Command from Terraform AFTER Route53
# A record is in place.
# ----------------------------------------------------------------------------
echo "[7/8] Writing /usr/local/bin/generate-certificate.sh..."

cat > /usr/local/bin/generate-certificate.sh << 'GENERATE_CERT_SCRIPT_EOF'
${cert_script}
GENERATE_CERT_SCRIPT_EOF

chmod +x /usr/local/bin/generate-certificate.sh

# Fix ownership
chown -R ubuntu:ubuntu $${APP_DIR}

# Save script for re-runs
echo "[8/8] Saving initialization script..."
cp "$0" /usr/local/bin/init-frontend.sh 2>/dev/null || true
chmod +x /usr/local/bin/init-frontend.sh 2>/dev/null || true

echo "======================================================"
echo " Frontend Initialization Complete — $(date)"
echo " Host     : $(hostname -I | awk '{print $1}')"
echo " Web Root : $${WEB_ROOT}"
echo " Domain   : ${domain_name}"
echo " Cert Cmd : /usr/local/bin/generate-certificate.sh"
echo "======================================================"
echo "Next: Terraform will trigger certificate generation via"
echo "      SSM Run Command once Route53 A record is live."
echo "======================================================"
