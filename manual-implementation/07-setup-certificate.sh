#!/bin/bash
################################################################################
# Certificate Setup and Export Script
# 
# This script generates Let's Encrypt certificate and exports to ACM
# 
# Run this script on the frontend server
# Usage: sudo DOMAIN=bmi.ostaddevops.click ./07-setup-certificate.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=================================="
echo "Certificate Setup - Let's Encrypt"
echo "==================================${NC}"

# Configuration
DOMAIN="${DOMAIN:-bmi.ostaddevops.click}"
EMAIL="${EMAIL:-admin@ostaddevops.click}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}Please run as root (use sudo)${NC}"
   exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Domain: $DOMAIN"
echo "  Email: $EMAIL"
echo "  Region: $AWS_REGION"
echo ""

# Extract base domain
BASE_DOMAIN="${DOMAIN#*.}"
if [[ "$BASE_DOMAIN" == "$DOMAIN" ]]; then
    BASE_DOMAIN="$DOMAIN"
fi

echo "  Wildcard Domain: *.$BASE_DOMAIN"
echo ""

# Check AWS credentials
echo -e "${GREEN}[1/4] Checking AWS IAM role...${NC}"
aws sts get-caller-identity || {
    echo -e "${RED}Error: No AWS credentials found${NC}"
    echo "Make sure IAM instance profile is attached to this EC2 instance"
    exit 1
}

# Install Certbot if not installed
if ! command -v certbot &> /dev/null; then
    echo -e "${GREEN}Installing Certbot...${NC}"
    apt-get update
    apt-get install -y certbot python3-certbot-dns-route53 python3-certbot-nginx
fi

# Generate certificate
echo -e "${GREEN}[2/4] Requesting Let's Encrypt certificate...${NC}"
certbot certonly \
  --dns-route53 \
  -d $DOMAIN -d "*.$BASE_DOMAIN" \
  --preferred-challenges dns \
  --agree-tos \
  --non-interactive \
  --email $EMAIL \
  --keep-until-expiring \
  --deploy-hook "systemctl reload nginx" || {
    echo -e "${RED}Certificate generation failed${NC}"
    echo "Check:"
    echo "  1. IAM role has Route53 permissions"
    echo "  2. Domain exists in Route53"
    echo "  3. DNS is properly configured"
    exit 1
}

# Verify certificate
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo -e "${RED}Certificate files not found${NC}"
    exit 1
fi

echo "Certificate generated successfully!"
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -text | grep -A2 "Validity"

# Export to ACM
echo -e "${GREEN}[3/4] Exporting certificate to ACM...${NC}"

# Check if certificate already exists in ACM
EXISTING_CERT_ARN=$(aws acm list-certificates \
  --region $AWS_REGION \
  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" \
  --output text 2>/dev/null || echo "")

if [ ! -z "$EXISTING_CERT_ARN" ]; then
    echo "Existing certificate found: $EXISTING_CERT_ARN"
    echo "Reimporting (updating) certificate..."
    
    CERT_ARN=$(aws acm import-certificate \
      --certificate fileb:///etc/letsencrypt/live/$DOMAIN/fullchain.pem \
      --private-key fileb:///etc/letsencrypt/live/$DOMAIN/privkey.pem \
      --certificate-arn $EXISTING_CERT_ARN \
      --region $AWS_REGION \
      --query 'CertificateArn' \
      --output text)
else
    echo "Importing new certificate to ACM..."
    
    CERT_ARN=$(aws acm import-certificate \
      --certificate fileb:///etc/letsencrypt/live/$DOMAIN/fullchain.pem \
      --private-key fileb:///etc/letsencrypt/live/$DOMAIN/privkey.pem \
      --tags Key=Name,Value=$DOMAIN-letsencrypt Key=ManagedBy,Value=Certbot \
      --region $AWS_REGION \
      --query 'CertificateArn' \
      --output text)
fi

echo "Certificate ARN: $CERT_ARN"
echo "$CERT_ARN" > /root/certificate-arn.txt

# Create renewal hook script
echo -e "${GREEN}[4/4] Setting up auto-renewal...${NC}"

cat > /etc/letsencrypt/renewal-hooks/deploy/update-acm.sh <<'HOOK_EOF'
#!/bin/bash
# Auto-update ACM certificate after renewal

DOMAIN="$RENEWED_DOMAINS"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
AWS_REGION="ap-south-1"

# Get existing cert ARN
CERT_ARN=$(cat /root/certificate-arn.txt)

if [ -z "$CERT_ARN" ]; then
    echo "No certificate ARN found, importing as new..."
    CERT_ARN=$(aws acm import-certificate \
      --certificate fileb://$CERT_PATH/fullchain.pem \
      --private-key fileb://$CERT_PATH/privkey.pem \
      --region $AWS_REGION \
      --query 'CertificateArn' \
      --output text)
    echo "$CERT_ARN" > /root/certificate-arn.txt
else
    echo "Updating existing certificate in ACM..."
    aws acm import-certificate \
      --certificate fileb://$CERT_PATH/fullchain.pem \
      --private-key fileb://$CERT_PATH/privkey.pem \
      --certificate-arn $CERT_ARN \
      --region $AWS_REGION
fi

echo "ACM certificate updated: $CERT_ARN"
logger "Let's Encrypt certificate renewed and updated in ACM: $CERT_ARN"
HOOK_EOF

chmod +x /etc/letsencrypt/renewal-hooks/deploy/update-acm.sh

# Setup cron for auto-renewal
cat > /etc/cron.d/certbot-renew <<'CRON_EOF'
# Run certbot renewal twice daily
0 0,12 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx"
CRON_EOF

# Test renewal (dry run)
echo "Testing renewal process (dry run)..."
certbot renew --dry-run --quiet || echo -e "${YELLOW}Dry run failed (normal if cert is new)${NC}"

echo -e "${GREEN}"
echo "=================================="
echo "Certificate Setup Complete!"
echo "=================================="
echo -e "${NC}"
echo "Certificate Details:"
echo "  Domain: $DOMAIN"
echo "  Wildcard: *.$BASE_DOMAIN"
echo "  Local Path: /etc/letsencrypt/live/$DOMAIN/"
echo "  ACM ARN: $CERT_ARN"
echo ""
echo "Certificate Files:"
echo "  Full Chain: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
echo "  Private Key: /etc/letsencrypt/live/$DOMAIN/privkey.pem"
echo ""
echo "Auto-renewal:"
echo "  Cron: Twice daily (0:00 and 12:00)"
echo "  Hook: Automatic ACM update"
echo ""
echo "Manual Renewal:"
echo "  certbot renew --force-renewal"
echo ""
echo -e "${YELLOW}IMPORTANT: Use this ACM ARN in your ALB HTTPS listener!${NC}"
echo ""
