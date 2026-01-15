#!/bin/bash
################################################################################
# DNS Setup Script
# 
# This script creates Route53 A record pointing to ALB
# 
# Usage: ALB_DNS=xxx.elb.amazonaws.com ALB_HOSTED_ZONE_ID=Z... ./06-setup-dns.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=================================="
echo "BMI Health Tracker - DNS Setup"
echo "==================================${NC}"

# Configuration
DOMAIN="${DOMAIN:-bmi.ostaddevops.click}"
HOSTED_ZONE_NAME="${HOSTED_ZONE_NAME:-ostaddevops.click}"
ALB_DNS="${ALB_DNS}"
ALB_HOSTED_ZONE_ID="${ALB_HOSTED_ZONE_ID}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_PROFILE="${AWS_PROFILE:-sarowar-ostad}"

# Validate required variables
if [ -z "$ALB_DNS" ] || [ -z "$ALB_HOSTED_ZONE_ID" ]; then
    echo -e "${RED}ERROR: Missing required variables!${NC}"
    echo "Usage: ALB_DNS=xxx.elb.amazonaws.com ALB_HOSTED_ZONE_ID=Z... ./06-setup-dns.sh"
    echo ""
    echo "Get ALB details with:"
    echo "  aws elbv2 describe-load-balancers --names bmi-health-tracker-alb --profile $AWS_PROFILE"
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Domain: $DOMAIN"
echo "  Hosted Zone: $HOSTED_ZONE_NAME"
echo "  ALB DNS: $ALB_DNS"
echo "  ALB Zone ID: $ALB_HOSTED_ZONE_ID"
echo ""

# Find hosted zone ID
echo -e "${GREEN}[1/2] Finding Route53 hosted zone...${NC}"
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name $HOSTED_ZONE_NAME \
  --profile $AWS_PROFILE \
  --query "HostedZones[?Name=='$HOSTED_ZONE_NAME.'].Id" \
  --output text | cut -d'/' -f3)

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo -e "${RED}Error: Hosted zone not found for $HOSTED_ZONE_NAME${NC}"
    exit 1
fi

echo "Hosted Zone ID: $HOSTED_ZONE_ID"

# Create change batch JSON
cat > /tmp/dns-change-batch.json <<EOF
{
  "Comment": "Create A record for BMI Health Tracker",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$DOMAIN",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_HOSTED_ZONE_ID",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

# Create/update DNS record
echo -e "${GREEN}[2/2] Creating Route53 A record...${NC}"
CHANGE_ID=$(aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file:///tmp/dns-change-batch.json \
  --profile $AWS_PROFILE \
  --query 'ChangeInfo.Id' \
  --output text)

echo "Change ID: $CHANGE_ID"

# Wait for DNS propagation
echo "Waiting for DNS change to propagate..."
aws route53 wait resource-record-sets-changed \
  --id $CHANGE_ID \
  --profile $AWS_PROFILE

# Cleanup
rm -f /tmp/dns-change-batch.json

echo -e "${GREEN}"
echo "=================================="
echo "DNS Setup Complete!"
echo "=================================="
echo -e "${NC}"
echo "DNS Details:"
echo "  Domain: $DOMAIN"
echo "  Points to: $ALB_DNS"
echo "  Hosted Zone: $HOSTED_ZONE_ID"
echo "  Change ID: $CHANGE_ID"
echo ""
echo "Test DNS resolution:"
echo "  nslookup $DOMAIN"
echo "  dig $DOMAIN"
echo ""
echo "Note: DNS propagation can take 1-5 minutes"
echo ""
echo "Test application:"
echo "  curl https://$DOMAIN/health"
echo "  Open in browser: https://$DOMAIN"
echo ""
