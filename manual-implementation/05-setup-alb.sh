#!/bin/bash
################################################################################
# Application Load Balancer Setup Script
# 
# This script creates ALB, target groups, and listeners
# 
# Usage: VPC_ID=vpc-xxx FRONTEND_IP=10.0.x.x ./05-setup-alb.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=================================="
echo "BMI Health Tracker - ALB Setup"
echo "==================================${NC}"

# Configuration
VPC_ID="${VPC_ID}"
FRONTEND_IP="${FRONTEND_IP}"
SUBNET_IDS="${SUBNET_IDS}"
SECURITY_GROUP_ID="${SECURITY_GROUP_ID}"
DOMAIN="${DOMAIN:-bmi.ostaddevops.click}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_PROFILE="${AWS_PROFILE:-sarowar-ostad}"
PROJECT_NAME="${PROJECT_NAME:-bmi-health-tracker}"

# Validate required variables
if [ -z "$VPC_ID" ] || [ -z "$FRONTEND_IP" ]; then
    echo -e "${RED}ERROR: Missing required variables!${NC}"
    echo "Usage: VPC_ID=vpc-xxx FRONTEND_IP=10.0.x.x SUBNET_IDS=subnet-xxx,subnet-yyy ./05-setup-alb.sh"
    echo ""
    echo "Required:"
    echo "  VPC_ID: Your VPC ID"
    echo "  FRONTEND_IP: Private IP of frontend server"
    echo "  SUBNET_IDS: Comma-separated public subnet IDs (at least 2)"
    echo "  SECURITY_GROUP_ID: Security group allowing 80/443"
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  VPC: $VPC_ID"
echo "  Frontend IP: $FRONTEND_IP"
echo "  Subnets: $SUBNET_IDS"
echo "  Security Group: $SECURITY_GROUP_ID"
echo "  Domain: $DOMAIN"
echo ""

# Create target group
echo -e "${GREEN}[1/5] Creating target group...${NC}"
TG_ARN=$(aws elbv2 create-target-group \
  --name $PROJECT_NAME-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --matcher HttpCode=200 \
  --target-type ip \
  --ip-address-type ipv4 \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null) || {
    echo "Target group might already exist, fetching..."
    TG_ARN=$(aws elbv2 describe-target-groups \
      --names $PROJECT_NAME-tg \
      --region $AWS_REGION \
      --profile $AWS_PROFILE \
      --query 'TargetGroups[0].TargetGroupArn' \
      --output text)
}

echo "Target Group ARN: $TG_ARN"

# Register frontend IP as target
echo -e "${GREEN}[2/5] Registering frontend as target...${NC}"
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$FRONTEND_IP \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

# Create ALB
echo -e "${GREEN}[3/5] Creating Application Load Balancer...${NC}"
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name $PROJECT_NAME-alb \
  --subnets $(echo $SUBNET_IDS | tr ',' ' ') \
  --security-groups $SECURITY_GROUP_ID \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --tags Key=Name,Value=$PROJECT_NAME-alb Key=Project,Value=$PROJECT_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text 2>/dev/null) || {
    echo "ALB might already exist, fetching..."
    ALB_ARN=$(aws elbv2 describe-load-balancers \
      --names $PROJECT_NAME-alb \
      --region $AWS_REGION \
      --profile $AWS_PROFILE \
      --query 'LoadBalancers[0].LoadBalancerArn' \
      --output text)
}

echo "ALB ARN: $ALB_ARN"

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "ALB DNS: $ALB_DNS"

# Create HTTP listener (redirect to HTTPS)
echo -e "${GREEN}[4/5] Creating HTTP listener (redirect)...${NC}"
HTTP_LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=redirect,RedirectConfig='{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}' \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'Listeners[0].ListenerArn' \
  --output text 2>/dev/null) || echo "HTTP listener already exists"

# Create HTTPS listener (requires certificate)
echo -e "${GREEN}[5/5] Creating HTTPS listener...${NC}"
echo -e "${YELLOW}NOTE: This requires an ACM certificate. Run 06-setup-certificate.sh first if needed.${NC}"
echo ""

# Try to find certificate
CERT_ARN=$(aws acm list-certificates \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" \
  --output text 2>/dev/null || echo "")

if [ ! -z "$CERT_ARN" ]; then
    echo "Found certificate: $CERT_ARN"
    
    HTTPS_LISTENER_ARN=$(aws elbv2 create-listener \
      --load-balancer-arn $ALB_ARN \
      --protocol HTTPS \
      --port 443 \
      --certificates CertificateArn=$CERT_ARN \
      --ssl-policy ELBSecurityPolicy-TLS-1-2-2017-01 \
      --default-actions Type=forward,TargetGroupArn=$TG_ARN \
      --region $AWS_REGION \
      --profile $AWS_PROFILE \
      --query 'Listeners[0].ListenerArn' \
      --output text 2>/dev/null) || echo "HTTPS listener already exists"
    
    echo "HTTPS Listener ARN: $HTTPS_LISTENER_ARN"
else
    echo -e "${YELLOW}No certificate found. HTTPS listener not created.${NC}"
    echo "Run 06-setup-certificate.sh to generate and import certificate."
fi

# Wait for ALB to be active
echo "Waiting for ALB to be active..."
aws elbv2 wait load-balancer-available \
  --load-balancer-arns $ALB_ARN \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

# Check target health
echo "Checking target health..."
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo -e "${GREEN}"
echo "=================================="
echo "ALB Setup Complete!"
echo "=================================="
echo -e "${NC}"
echo "ALB Details:"
echo "  ALB ARN: $ALB_ARN"
echo "  ALB DNS: $ALB_DNS"
echo "  Target Group: $TG_ARN"
echo "  HTTP Listener: $HTTP_LISTENER_ARN"
if [ ! -z "$HTTPS_LISTENER_ARN" ]; then
    echo "  HTTPS Listener: $HTTPS_LISTENER_ARN"
fi
echo ""
echo "Test ALB:"
echo "  curl http://$ALB_DNS/health"
echo ""
echo "Next Steps:"
echo "  1. If not done yet, run: ./06-setup-certificate.sh"
echo "  2. Create Route53 A record: $DOMAIN → $ALB_DNS (alias)"
echo "  3. Test: https://$DOMAIN"
echo ""
