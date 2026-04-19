#!/bin/bash
################################################################################
# Certificate Generation Script — HTTP-01 via certbot --nginx
# Templatefile variables: domain_name, aws_region
#
# Written to /usr/local/bin/generate-certificate.sh by frontend_setup.sh.
# Executed via SSM Run Command from Terraform AFTER the Route53 A record
# resolves to this server's EIP so the HTTP-01 challenge can complete.
#
# Re-run manually:  sudo /usr/local/bin/generate-certificate.sh
################################################################################

set -e
exec > >(tee -a /var/log/certbot-generate.log) 2>&1

DOMAIN="${domain_name}"

echo "======================================================"
echo " Let's Encrypt Certificate Generation (HTTP-01)"
echo " Domain  : $${DOMAIN}"
echo " Started : $(date)"
echo "======================================================"

# Nginx must be running so certbot can serve the HTTP-01 challenge on port 80
echo "[1/4] Ensuring Nginx is running..."
systemctl is-active nginx || systemctl start nginx

# Request certificate — certbot --nginx handles the challenge + HTTPS config
echo "[2/4] Requesting certificate from Let's Encrypt..."
certbot --nginx \
  -d "$${DOMAIN}" \
  --agree-tos \
  --non-interactive \
  --email "admin@$${DOMAIN}" \
  --keep-until-expiring \
  --redirect

if [ ! -f "/etc/letsencrypt/live/$${DOMAIN}/fullchain.pem" ]; then
  echo "ERROR: Certificate not found after certbot run"
  echo "Check /var/log/letsencrypt/letsencrypt.log for details"
  exit 1
fi

echo "Certificate issued successfully!"
openssl x509 -in "/etc/letsencrypt/live/$${DOMAIN}/fullchain.pem" \
  -noout -subject -dates

# Auto-renewal (certbot snap also installs a systemd timer; cron is belt+suspenders)
echo "[3/4] Configuring auto-renewal cron job..."
cat > /etc/cron.d/certbot-renew << 'CRON_EOF'
0 0,12 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx"
CRON_EOF
chmod 644 /etc/cron.d/certbot-renew

# Smoke test
echo "[4/4] Smoke testing HTTPS endpoint..."
sleep 3
HTTP_STATUS=$(curl -sk -o /dev/null -w "%%{http_code}" "https://$${DOMAIN}/health" 2>/dev/null || echo "000")
echo "  https://$${DOMAIN}/health → HTTP $${HTTP_STATUS}"

echo "======================================================"
echo " Certificate Generation Complete — $(date)"
echo " Certificate : /etc/letsencrypt/live/$${DOMAIN}/"
echo " HTTPS URL   : https://$${DOMAIN}"
echo "======================================================"


