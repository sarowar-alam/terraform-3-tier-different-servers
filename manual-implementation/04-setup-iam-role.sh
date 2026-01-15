#!/bin/bash
################################################################################
# IAM Role Setup Script
# 
# This script creates an IAM role with Route53 and ACM permissions
# 
# Usage: ./04-setup-iam-role.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=================================="
echo "BMI Health Tracker - IAM Role Setup"
echo "==================================${NC}"

# Configuration
ROLE_NAME="${ROLE_NAME:-bmi-frontend-role}"
POLICY_NAME="${POLICY_NAME:-bmi-frontend-policy}"
INSTANCE_PROFILE_NAME="${INSTANCE_PROFILE_NAME:-bmi-frontend-profile}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_PROFILE="${AWS_PROFILE:-sarowar-ostad}"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Role Name: $ROLE_NAME"
echo "  Policy Name: $POLICY_NAME"
echo "  Instance Profile: $INSTANCE_PROFILE_NAME"
echo "  Region: $AWS_REGION"
echo "  Profile: $AWS_PROFILE"
echo ""

# Check if AWS CLI is configured
echo -e "${GREEN}[1/5] Checking AWS credentials...${NC}"
aws sts get-caller-identity --profile $AWS_PROFILE || {
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
}

# Create IAM role
echo -e "${GREEN}[2/5] Creating IAM role...${NC}"
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://iam-assume-role-policy.json \
  --description "Role for BMI Health Tracker frontend server with Let's Encrypt and ACM" \
  --profile $AWS_PROFILE \
  2>/dev/null || echo "Role already exists"

# Attach policy
echo -e "${GREEN}[3/5] Creating and attaching IAM policy...${NC}"

# Create policy (delete if exists)
aws iam delete-policy \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text):policy/$POLICY_NAME \
  --profile $AWS_PROFILE \
  2>/dev/null || true

POLICY_ARN=$(aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://iam-role-policy.json \
  --description "Policy for Let's Encrypt DNS challenge and ACM certificate import" \
  --profile $AWS_PROFILE \
  --query 'Policy.Arn' \
  --output text)

echo "Policy ARN: $POLICY_ARN"

# Attach policy to role
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $POLICY_ARN \
  --profile $AWS_PROFILE

# Create instance profile
echo -e "${GREEN}[4/5] Creating instance profile...${NC}"
aws iam create-instance-profile \
  --instance-profile-name $INSTANCE_PROFILE_NAME \
  --profile $AWS_PROFILE \
  2>/dev/null || echo "Instance profile already exists"

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name $INSTANCE_PROFILE_NAME \
  --role-name $ROLE_NAME \
  --profile $AWS_PROFILE \
  2>/dev/null || echo "Role already added to instance profile"

# Get instance profile ARN
INSTANCE_PROFILE_ARN=$(aws iam get-instance-profile \
  --instance-profile-name $INSTANCE_PROFILE_NAME \
  --profile $AWS_PROFILE \
  --query 'InstanceProfile.Arn' \
  --output text)

echo -e "${GREEN}[5/5] Waiting for IAM propagation (30 seconds)...${NC}"
sleep 30

echo -e "${GREEN}"
echo "=================================="
echo "IAM Role Setup Complete!"
echo "=================================="
echo -e "${NC}"
echo "IAM Details:"
echo "  Role Name: $ROLE_NAME"
echo "  Policy ARN: $POLICY_ARN"
echo "  Instance Profile: $INSTANCE_PROFILE_NAME"
echo "  Instance Profile ARN: $INSTANCE_PROFILE_ARN"
echo ""
echo "Next Steps:"
echo "  1. Attach this instance profile to your frontend EC2 instance:"
echo "     aws ec2 associate-iam-instance-profile \\"
echo "       --instance-id <FRONTEND_INSTANCE_ID> \\"
echo "       --iam-instance-profile Name=$INSTANCE_PROFILE_NAME \\"
echo "       --profile $AWS_PROFILE"
echo ""
echo "  2. Or specify during instance launch:"
echo "     --iam-instance-profile Name=$INSTANCE_PROFILE_NAME"
echo ""
