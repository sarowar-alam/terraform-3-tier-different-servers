#!/bin/bash
################################################################################
# Complete Deployment Script
# 
# This script orchestrates the entire manual deployment process
# 
# Usage: ./deploy-all.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         BMI Health Tracker - Manual Deployment           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Configuration file
CONFIG_FILE="deployment-config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Configuration file not found. Creating template...${NC}"
    cat > $CONFIG_FILE <<'CONF_EOF'
# AWS Configuration
export AWS_REGION="ap-south-1"
export AWS_PROFILE="sarowar-ostad"
export VPC_ID="vpc-xxxxxxxxx"
export SUBNET_IDS="subnet-xxx,subnet-yyy"
export SECURITY_GROUP_ID="sg-xxxxxxxxx"

# Domain Configuration
export DOMAIN="bmi.ostaddevops.click"
export HOSTED_ZONE_NAME="ostaddevops.click"
export EMAIL="admin@ostaddevops.click"

# Database Configuration
export DB_NAME="bmidb"
export DB_USER="bmi_user"
export DB_PASSWORD="ChangeMe123!"
export DB_PORT="5432"

# Backend Configuration
export BACKEND_PORT="3000"

# Git Configuration
export GIT_REPO="https://github.com/your-username/bmi-health-tracker.git"
export GIT_BRANCH="main"

# Server IPs (fill after EC2 launch)
export DATABASE_IP=""
export BACKEND_IP=""
export FRONTEND_IP=""

# EC2 Instance IDs (fill after EC2 launch)
export DATABASE_INSTANCE_ID=""
export BACKEND_INSTANCE_ID=""
export FRONTEND_INSTANCE_ID=""
CONF_EOF
    
    echo -e "${RED}Please edit $CONFIG_FILE with your values and run again.${NC}"
    exit 1
fi

# Load configuration
source $CONFIG_FILE

# Validate configuration
echo -e "${GREEN}Validating configuration...${NC}"

MISSING_VARS=0
[ -z "$VPC_ID" ] && echo -e "${RED}  ✗ VPC_ID not set${NC}" && MISSING_VARS=1
[ -z "$SUBNET_IDS" ] && echo -e "${RED}  ✗ SUBNET_IDS not set${NC}" && MISSING_VARS=1
[ -z "$SECURITY_GROUP_ID" ] && echo -e "${RED}  ✗ SECURITY_GROUP_ID not set${NC}" && MISSING_VARS=1
[ -z "$DOMAIN" ] && echo -e "${RED}  ✗ DOMAIN not set${NC}" && MISSING_VARS=1

if [ $MISSING_VARS -eq 1 ]; then
    echo -e "${RED}Please configure all required variables in $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}Configuration valid!${NC}"
echo ""

# Main menu
echo -e "${BLUE}Select deployment phase:${NC}"
echo "  1) Setup IAM Role"
echo "  2) Launch and configure Database Server"
echo "  3) Launch and configure Backend Server"
echo "  4) Launch and configure Frontend Server"
echo "  5) Setup Application Load Balancer"
echo "  6) Setup DNS (Route53)"
echo "  7) Setup SSL Certificate"
echo "  8) Full Deployment (All steps)"
echo "  9) Verify Deployment"
echo "  0) Exit"
echo ""
read -p "Enter choice [0-9]: " choice

case $choice in
    1)
        echo -e "${GREEN}Setting up IAM Role...${NC}"
        ./04-setup-iam-role.sh
        ;;
    2)
        if [ -z "$DATABASE_IP" ]; then
            echo -e "${YELLOW}Launch EC2 instance for database first!${NC}"
            echo "Then update DATABASE_IP in $CONFIG_FILE"
            exit 1
        fi
        echo -e "${GREEN}Configuring Database Server...${NC}"
        echo "Run on database server:"
        echo "  scp 01-database-setup.sh ubuntu@$DATABASE_IP:~/"
        echo "  ssh ubuntu@$DATABASE_IP 'sudo bash ~/01-database-setup.sh'"
        ;;
    3)
        if [ -z "$BACKEND_IP" ] || [ -z "$DATABASE_IP" ]; then
            echo -e "${YELLOW}Launch backend EC2 instance and configure database first!${NC}"
            exit 1
        fi
        echo -e "${GREEN}Configuring Backend Server...${NC}"
        echo "Run on backend server:"
        echo "  scp 02-backend-setup.sh ubuntu@$BACKEND_IP:~/"
        echo "  ssh ubuntu@$BACKEND_IP \"sudo DB_HOST=$DATABASE_IP DB_PASSWORD=$DB_PASSWORD bash ~/02-backend-setup.sh\""
        ;;
    4)
        if [ -z "$FRONTEND_IP" ] || [ -z "$BACKEND_IP" ]; then
            echo -e "${YELLOW}Launch frontend EC2 instance and configure backend first!${NC}"
            exit 1
        fi
        echo -e "${GREEN}Configuring Frontend Server...${NC}"
        
        # First attach IAM role
        if [ ! -z "$FRONTEND_INSTANCE_ID" ]; then
            echo "Attaching IAM instance profile..."
            aws ec2 associate-iam-instance-profile \
              --instance-id $FRONTEND_INSTANCE_ID \
              --iam-instance-profile Name=bmi-frontend-profile \
              --profile $AWS_PROFILE || echo "Already attached"
        fi
        
        echo "Run on frontend server:"
        echo "  scp 03-frontend-setup.sh ubuntu@$FRONTEND_IP:~/"
        echo "  ssh ubuntu@$FRONTEND_IP \"sudo BACKEND_HOST=$BACKEND_IP DOMAIN=$DOMAIN bash ~/03-frontend-setup.sh\""
        ;;
    5)
        if [ -z "$FRONTEND_IP" ]; then
            echo -e "${YELLOW}Configure frontend server first!${NC}"
            exit 1
        fi
        echo -e "${GREEN}Setting up Application Load Balancer...${NC}"
        VPC_ID=$VPC_ID FRONTEND_IP=$FRONTEND_IP SUBNET_IDS=$SUBNET_IDS SECURITY_GROUP_ID=$SECURITY_GROUP_ID \
          ./05-setup-alb.sh
        ;;
    6)
        echo -e "${GREEN}Setting up DNS...${NC}"
        echo "First, get ALB details:"
        echo "  aws elbv2 describe-load-balancers --names bmi-health-tracker-alb --profile $AWS_PROFILE"
        echo ""
        echo "Then run:"
        echo "  ALB_DNS=xxx.elb.amazonaws.com ALB_HOSTED_ZONE_ID=Z... ./06-setup-dns.sh"
        ;;
    7)
        if [ -z "$FRONTEND_IP" ]; then
            echo -e "${YELLOW}Configure frontend server first!${NC}"
            exit 1
        fi
        echo -e "${GREEN}Setting up SSL Certificate...${NC}"
        echo "Run on frontend server:"
        echo "  scp 07-setup-certificate.sh ubuntu@$FRONTEND_IP:~/"
        echo "  ssh ubuntu@$FRONTEND_IP \"sudo DOMAIN=$DOMAIN bash ~/07-setup-certificate.sh\""
        ;;
    8)
        echo -e "${BLUE}Full deployment requires manual steps.${NC}"
        echo "Follow the deployment guide in README.md"
        ;;
    9)
        echo -e "${GREEN}Verifying deployment...${NC}"
        echo ""
        echo "Testing endpoints:"
        echo "  1. ALB Health: curl http://<alb-dns>/health"
        echo "  2. Direct Frontend: curl http://$FRONTEND_IP/health"
        echo "  3. HTTPS: curl https://$DOMAIN/health"
        echo "  4. API: curl https://$DOMAIN/api/measurements"
        echo ""
        
        if [ ! -z "$DOMAIN" ]; then
            echo "Opening browser..."
            echo "URL: https://$DOMAIN"
        fi
        ;;
    0)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Done!${NC}"
