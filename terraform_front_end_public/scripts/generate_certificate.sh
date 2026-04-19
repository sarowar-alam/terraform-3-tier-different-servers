#!/bin/bash
################################################################################
# Certificate Generation Script — HTTP-01 via certbot --nginx
# Manual re-run only. certbot runs automatically during instance user_data.
#
# Usage:  sudo /usr/local/bin/generate-certificate.sh [domain]
# If no domain given, reads server_name from Nginx config.
################################################################################

set -e
exec > >(tee -a /var/log/certbot-generate.log) 2>&1

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  DOMAIN=$(grep -m1 'server_name' /etc/nginx/sites-available/bmi-health-tracker \
    2>/dev/null | awk '{print $2}' | tr -d ';' || echo "")
fi
if [ -z "$DOMAIN" ]; then
  echo "ERROR: Cannot detect domain. Run: sudo $0 yourdomain.com"
  exit 1
fi

echo "======================================================"
echo " Let's Encrypt Certificate (HTTP-01 via certbot --nginx)"
echo " Domain  : $DOMAIN"
echo " Started : $(date)"
echo "======================================================"

echo "[1/4] Ensuring Nginx is running..."
systemctl is-active nginx || systemctl start nginx

echo "[2/4] Requesting certificate from Let's Encrypt..."
certbot --nginx \
  -d "$DOMAIN" \
  --agree-tos \
  --non-interactive \
  --email "admin@$DOMAIN" \
  --keep-until-expiring \
  --redirect

if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  echo "ERROR: Certificate not found. Check /var/log/letsencrypt/letsencrypt.log"
  exit 1
fi

echo "Certificate issued successfully!"
openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" -noout -subject -dates

echo "[3/4] Configuring auto-renewal cron job..."
cat > /etc/cron.d/certbot-renew << 'CRON_EOF'
0 0,12 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx"
CRON_EOF
chmod 644 /etc/cron.d/certbot-renew

echo "[4/4] Smoke testing HTTPS endpoint..."
sleep 3
HTTP_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://$DOMAIN/health" 2>/dev/null || echo "000")
echo "  https://$DOMAIN/health -> HTTP $HTTP_STATUS"

echo "======================================================"
echo " Certificate Generation Complete — $(date)"
echo " HTTPS URL : https://$DOMAIN"
echo "======================================================"

