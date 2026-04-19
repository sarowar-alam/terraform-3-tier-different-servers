#!/bin/bash
################################################################################
# Certificate Generation Script
# Templatefile variables: domain_name, aws_region
#
# This script is written to /usr/local/bin/generate-certificate.sh by
# frontend_setup.sh during instance user_data.
#
# It is executed via SSM Run Command from Terraform AFTER the Route53 A
# record is created, ensuring the DNS-01 TXT challenge can propagate.
#
# Can also be re-run manually:
#   sudo /usr/local/bin/generate-certificate.sh
################################################################################

set -e
exec > >(tee -a /var/log/certbot-generate.log) 2>&1

DOMAIN="${domain_name}"
AWS_REGION="${aws_region}"
NGINX_CONF="/etc/nginx/sites-available/bmi-health-tracker"

echo "======================================================"
echo " Let's Encrypt Certificate Generation"
echo " Domain    : $${DOMAIN}"
echo " Region    : $${AWS_REGION}"
echo " Started   : $(date)"
echo "======================================================"

# ----------------------------------------------------------------------------
# Confirm IAM role credentials are available
# ----------------------------------------------------------------------------
echo "[1/5] Checking IAM role credentials..."
MAX_CRED_ATTEMPTS=10
CRED_ATTEMPT=0
while [ $${CRED_ATTEMPT} -lt $${MAX_CRED_ATTEMPTS} ]; do
  CRED_ATTEMPT=$((CRED_ATTEMPT + 1))
  if aws sts get-caller-identity --region "$${AWS_REGION}" > /dev/null 2>&1; then
    echo "  IAM credentials available (attempt $${CRED_ATTEMPT})"
    aws sts get-caller-identity --region "$${AWS_REGION}"
    break
  fi
  echo "  Attempt $${CRED_ATTEMPT}/$${MAX_CRED_ATTEMPTS} — waiting for IAM role propagation..."
  sleep 15
done

if ! aws sts get-caller-identity --region "$${AWS_REGION}" > /dev/null 2>&1; then
  echo "ERROR: No AWS credentials available. Ensure IAM instance profile is attached."
  exit 1
fi

# ----------------------------------------------------------------------------
# Request Let's Encrypt certificate via Route53 DNS-01 challenge
# ----------------------------------------------------------------------------
echo "[2/5] Requesting certificate from Let's Encrypt..."
echo "  Using DNS-01 challenge via Route53 (no port 80/443 required)"

certbot certonly \
  --dns-route53 \
  --dns-route53-propagation-seconds 60 \
  -d "$${DOMAIN}" \
  --agree-tos \
  --non-interactive \
  --email "admin@$${DOMAIN}" \
  --keep-until-expiring \
  --rsa-key-size 4096

if [ ! -f "/etc/letsencrypt/live/$${DOMAIN}/fullchain.pem" ]; then
  echo "ERROR: Certificate files not found after certbot run."
  echo "Check: /var/log/letsencrypt/letsencrypt.log"
  exit 1
fi

echo "Certificate issued successfully!"
openssl x509 -in "/etc/letsencrypt/live/$${DOMAIN}/fullchain.pem" \
  -noout -subject -dates

# ----------------------------------------------------------------------------
# Configure Nginx for HTTPS with HTTP→HTTPS redirect
# ----------------------------------------------------------------------------
echo "[3/5] Updating Nginx for HTTPS..."

# Derive backend proxy pass from existing HTTP config
BACKEND_PROXY=$(grep -oP 'proxy_pass http://\K[^/]+' "$${NGINX_CONF}" | head -1)
if [ -z "$${BACKEND_PROXY}" ]; then
  echo "WARNING: Could not detect backend proxy address from Nginx config."
fi

cat > "$${NGINX_CONF}" << NGINX_HTTPS_EOF
# HTTP — redirect everything to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $${DOMAIN};
    return 301 https://\$host\$request_uri;
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $${DOMAIN};

    # Let's Encrypt certificates
    ssl_certificate     /etc/letsencrypt/live/$${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$${DOMAIN}/privkey.pem;

    # Modern TLS only
    ssl_protocols             TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_session_cache         shared:SSL:10m;
    ssl_session_timeout       10m;

    root  /var/www/bmi-health-tracker;
    index index.html;

    server_tokens off;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript
               application/javascript application/xml+rss application/json;

    # React SPA
    location / {
        try_files \$uri \$uri/ /index.html;

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # Backend API proxy
    location /api/ {
        proxy_pass http://$${BACKEND_PROXY}/api/;
        proxy_http_version 1.1;
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade           \$http_upgrade;
        proxy_set_header Connection        "upgrade";
        proxy_connect_timeout 60s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
        proxy_buffering       off;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options           "SAMEORIGIN"   always;
    add_header X-Content-Type-Options    "nosniff"      always;
    add_header X-XSS-Protection          "1; mode=block" always;

    access_log /var/log/nginx/bmi-access.log;
    error_log  /var/log/nginx/bmi-error.log;
}
NGINX_HTTPS_EOF

nginx -t
systemctl reload nginx
echo "  Nginx reloaded with HTTPS config"

# ----------------------------------------------------------------------------
# Setup automatic certificate renewal
# ----------------------------------------------------------------------------
echo "[4/5] Configuring auto-renewal..."

cat > /etc/cron.d/certbot-renew << 'CRON_EOF'
# Renew Let's Encrypt certificates twice daily
# Certbot will skip if cert is not due for renewal (< 30 days remaining)
0 0,12 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx"
CRON_EOF

chmod 644 /etc/cron.d/certbot-renew
echo "  Cron job written to /etc/cron.d/certbot-renew"

# Test renewal (dry run)
certbot renew --dry-run --quiet 2>&1 && echo "  Dry-run renewal OK" || echo "  WARNING: Dry-run renewal failed (may be too early)"

# ----------------------------------------------------------------------------
# Smoke test
# ----------------------------------------------------------------------------
echo "[5/5] Smoke testing HTTPS..."
sleep 3
HTTP_STATUS=$(curl -sk -o /dev/null -w "%%{http_code}" "https://$${DOMAIN}/health" 2>/dev/null || echo "000")
echo "  https://$${DOMAIN}/health → HTTP $${HTTP_STATUS}"
if [ "$${HTTP_STATUS}" = "200" ]; then
  echo "  HTTPS working correctly!"
else
  echo "  WARNING: HTTPS check returned $${HTTP_STATUS} (DNS may still be propagating)"
fi

echo "======================================================"
echo " Certificate Generation Complete — $(date)"
echo " Certificate : /etc/letsencrypt/live/$${DOMAIN}/"
echo " HTTPS URL   : https://$${DOMAIN}"
echo " Auto-renew  : /etc/cron.d/certbot-renew"
echo "======================================================"
