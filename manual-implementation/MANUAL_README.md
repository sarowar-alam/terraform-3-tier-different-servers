# BMI Health Tracker - Manual Implementation Guide

This folder contains scripts and configuration files for deploying the BMI Health Tracker application manually on AWS without using Terraform.

## 📋 Overview

The manual implementation provides:
- **Step-by-step deployment scripts** for each tier
- **Configuration templates** for easy customization
- **IAM setup** for Let's Encrypt and ACM integration
- **Complete networking** with ALB, Route53, and SSL

## 🗂️ File Structure

```
manual-implementation/
├── README.md                          # This file
├── deployment-config.env.example      # Configuration template
├── deploy-all.sh                      # Orchestration script
│
├── 01-database-setup.sh              # Database server setup
├── 02-backend-setup.sh               # Backend server setup
├── 03-frontend-setup.sh              # Frontend server setup
│
├── 04-setup-iam-role.sh              # IAM role for certificate management
├── 05-setup-alb.sh                   # Application Load Balancer setup
├── 06-setup-dns.sh                   # Route53 DNS configuration
├── 07-setup-certificate.sh           # Let's Encrypt certificate
│
├── iam-role-policy.json              # IAM permissions for Route53 & ACM
├── iam-assume-role-policy.json       # EC2 assume role trust policy
│
├── backend-env.template              # Backend environment variables
├── pm2-ecosystem.config.js           # PM2 configuration
└── nginx-config.conf                 # Nginx configuration template
```

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with CLI configured
2. **VPC** with private subnets (database, backend, frontend)
3. **Public subnets** (at least 2 for ALB)
4. **Security Groups** configured:
   - Database SG: Allow 5432 from backend SG
   - Backend SG: Allow 3000 from frontend SG
   - Frontend SG: Allow 80/443 from ALB SG
   - ALB SG: Allow 80/443 from 0.0.0.0/0
5. **Route53 Hosted Zone** for your domain
6. **SSH Key Pair** for EC2 access
7. **Git Repository** with your application code

### Step 1: Configure Environment

```bash
# Copy configuration template
cp deployment-config.env.example deployment-config.env

# Edit with your values
nano deployment-config.env

# Required values:
# - VPC_ID
# - SUBNET_IDS (public subnets for ALB)
# - SECURITY_GROUP_ID (for ALB)
# - DOMAIN and HOSTED_ZONE_NAME
# - GIT_REPO and GIT_BRANCH
# - DB_PASSWORD
```

### Step 2: Launch EC2 Instances

Launch 3 EC2 instances (Ubuntu 22.04 LTS) in private subnets:

```bash
# Database Server
aws ec2 run-instances \
  --image-id ami-0f58b397bc5c1f2e8 \
  --instance-type t3.micro \
  --key-name your-key-pair \
  --subnet-id subnet-database \
  --security-group-ids sg-database \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bmi-database}]' \
  --profile sarowar-ostad

# Backend Server
aws ec2 run-instances \
  --image-id ami-0f58b397bc5c1f2e8 \
  --instance-type t3.micro \
  --key-name your-key-pair \
  --subnet-id subnet-backend \
  --security-group-ids sg-backend \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bmi-backend}]' \
  --profile sarowar-ostad

# Frontend Server (will attach IAM role later)
aws ec2 run-instances \
  --image-id ami-0f58b397bc5c1f2e8 \
  --instance-type t3.micro \
  --key-name your-key-pair \
  --subnet-id subnet-frontend \
  --security-group-ids sg-frontend \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bmi-frontend}]' \
  --profile sarowar-ostad
```

Wait for instances to launch and note their **Private IPs** and **Instance IDs**.

Update `deployment-config.env`:
```bash
export DATABASE_IP="10.0.1.10"
export BACKEND_IP="10.0.2.10"
export FRONTEND_IP="10.0.3.10"

export DATABASE_INSTANCE_ID="i-xxxxxxxxx"
export BACKEND_INSTANCE_ID="i-xxxxxxxxx"
export FRONTEND_INSTANCE_ID="i-xxxxxxxxx"
```

### Step 3: Setup IAM Role

Create IAM role for frontend server (certificate management):

```bash
./04-setup-iam-role.sh
```

Attach to frontend instance:
```bash
aws ec2 associate-iam-instance-profile \
  --instance-id $FRONTEND_INSTANCE_ID \
  --iam-instance-profile Name=bmi-frontend-profile \
  --profile sarowar-ostad
```

### Step 4: Configure Database Server

```bash
# Copy script to database server
scp -i your-key.pem 01-database-setup.sh ubuntu@$DATABASE_IP:~/

# SSH and run
ssh -i your-key.pem ubuntu@$DATABASE_IP

sudo bash ~/01-database-setup.sh

# Save the connection details shown at the end
```

### Step 5: Configure Backend Server

```bash
# Load configuration
source deployment-config.env

# Copy script to backend server
scp -i your-key.pem 02-backend-setup.sh ubuntu@$BACKEND_IP:~/

# SSH and run with database details
ssh -i your-key.pem ubuntu@$BACKEND_IP

sudo DB_HOST=$DATABASE_IP \
     DB_PASSWORD=$DB_PASSWORD \
     bash ~/02-backend-setup.sh

# Verify backend is running
pm2 status
curl http://localhost:3000/health
```

### Step 6: Configure Frontend Server

```bash
# Copy script to frontend server
scp -i your-key.pem 03-frontend-setup.sh ubuntu@$FRONTEND_IP:~/

# SSH and run
ssh -i your-key.pem ubuntu@$FRONTEND_IP

sudo BACKEND_HOST=$BACKEND_IP \
     DOMAIN=$DOMAIN \
     bash ~/03-frontend-setup.sh

# Verify Nginx is running
curl http://localhost/health
```

### Step 7: Setup Application Load Balancer

```bash
# Load configuration
source deployment-config.env

# Create ALB, target group, and listeners
VPC_ID=$VPC_ID \
FRONTEND_IP=$FRONTEND_IP \
SUBNET_IDS=$SUBNET_IDS \
SECURITY_GROUP_ID=$SECURITY_GROUP_ID \
./05-setup-alb.sh

# Note the ALB DNS name and Hosted Zone ID
```

### Step 8: Setup SSL Certificate

```bash
# Copy script to frontend server
scp -i your-key.pem 07-setup-certificate.sh ubuntu@$FRONTEND_IP:~/

# SSH and run
ssh -i your-key.pem ubuntu@$FRONTEND_IP

sudo DOMAIN=$DOMAIN bash ~/07-setup-certificate.sh

# Note the Certificate ARN
```

### Step 9: Update ALB with SSL Certificate

```bash
# Get Certificate ARN from previous step
CERT_ARN="arn:aws:acm:ap-south-1:xxxx:certificate/xxxx"

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names bmi-health-tracker-alb \
  --profile sarowar-ostad \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# Get Target Group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names bmi-health-tracker-tg \
  --profile sarowar-ostad \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Create/Update HTTPS listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=$CERT_ARN \
  --ssl-policy ELBSecurityPolicy-TLS-1-2-2017-01 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --profile sarowar-ostad
```

### Step 10: Setup DNS

```bash
# Get ALB details
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names bmi-health-tracker-alb \
  --profile sarowar-ostad \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --names bmi-health-tracker-alb \
  --profile sarowar-ostad \
  --query 'LoadBalancers[0].CanonicalHostedZoneId' \
  --output text)

# Create Route53 record
ALB_DNS=$ALB_DNS \
ALB_HOSTED_ZONE_ID=$ALB_ZONE_ID \
./06-setup-dns.sh
```

## ✅ Verification

Test your deployment:

```bash
# 1. Health check
curl https://bmi.ostaddevops.click/health

# 2. API endpoint
curl https://bmi.ostaddevops.click/api/measurements

# 3. Open in browser
open https://bmi.ostaddevops.click
```

Check logs:
```bash
# Backend logs
ssh ubuntu@$BACKEND_IP
pm2 logs bmi-backend

# Frontend logs
ssh ubuntu@$FRONTEND_IP
tail -f /var/log/nginx/bmi-error.log

# Database logs
ssh ubuntu@$DATABASE_IP
sudo tail -f /var/log/postgresql/postgresql-14-main.log
```

## 🔧 Troubleshooting

### Database Connection Issues
```bash
# On database server, check PostgreSQL is listening
sudo netstat -plnt | grep 5432

# Test from backend server
telnet $DATABASE_IP 5432
psql -h $DATABASE_IP -U bmi_user -d bmidb
```

### Backend Not Starting
```bash
# Check environment variables
cat /home/ubuntu/bmi-health-tracker/backend/.env

# Check PM2 status
pm2 status
pm2 logs bmi-backend --lines 50

# Test database connection
node -e "const {Pool}=require('pg');const p=new Pool({connectionString:'postgresql://bmi_user:pass@host:5432/bmidb'});p.query('SELECT 1',(e,r)=>{console.log(e||r.rows);p.end();})"
```

### Frontend Certificate Issues
```bash
# Check IAM role is attached
aws ec2 describe-instances --instance-ids $FRONTEND_INSTANCE_ID \
  --profile sarowar-ostad \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# Check certbot logs
sudo cat /var/log/letsencrypt/letsencrypt.log

# Test Route53 access
aws route53 list-hosted-zones

# Manual certificate generation
sudo certbot certonly --dns-route53 -d bmi.ostaddevops.click -d "*.ostaddevops.click"
```

### ALB Not Routing
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --profile sarowar-ostad

# Test frontend directly
curl -H "Host: bmi.ostaddevops.click" http://$FRONTEND_IP/health
```

### DNS Not Resolving
```bash
# Check Route53 record
aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --profile sarowar-ostad

# Test DNS resolution
nslookup bmi.ostaddevops.click
dig bmi.ostaddevops.click
```

## 🔄 Updates and Maintenance

### Update Application Code

**Backend:**
```bash
ssh ubuntu@$BACKEND_IP
cd /home/ubuntu/bmi-health-tracker/backend
git pull
npm install
pm2 restart bmi-backend
```

**Frontend:**
```bash
ssh ubuntu@$FRONTEND_IP
cd /home/ubuntu/bmi-health-tracker/frontend
git pull
npm install
npm run build
sudo rm -rf /var/www/bmi-health-tracker/*
sudo cp -r dist/* /var/www/bmi-health-tracker/
sudo systemctl reload nginx
```

### Renew SSL Certificate

Automatic renewal runs twice daily. Manual renewal:
```bash
ssh ubuntu@$FRONTEND_IP
sudo certbot renew --force-renewal
```

### Database Migrations

```bash
ssh ubuntu@$BACKEND_IP
cd /home/ubuntu/bmi-health-tracker/backend/migrations

# Run new migration
sudo -u postgres psql -d bmidb -f new_migration.sql
```

## 📊 Cost Estimate

| Resource | Type | Monthly Cost (est.) |
|----------|------|---------------------|
| EC2 Database | t3.micro | $8 |
| EC2 Backend | t3.micro | $8 |
| EC2 Frontend | t3.micro | $8 |
| ALB | Standard | $18 |
| Route53 | Hosted Zone | $0.50 |
| Data Transfer | 10GB | $1 |
| **Total** | | **~$43.50/month** |

## 🆚 Comparison with Terraform

| Aspect | Manual | Terraform |
|--------|--------|-----------|
| **Setup Time** | 2-3 hours | 15-20 minutes |
| **Reproducibility** | Manual steps | Fully automated |
| **Version Control** | Limited | Complete |
| **Disaster Recovery** | Slow | Fast |
| **Learning Curve** | Lower | Higher |
| **Best For** | Learning, one-off | Production, scaling |

## 📚 Additional Resources

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Let's Encrypt DNS Challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)
- [Nginx Configuration Guide](https://nginx.org/en/docs/)
- [PM2 Documentation](https://pm2.keymetrics.io/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## 🤝 Support

For issues or questions:
1. Check troubleshooting section above
2. Review logs on respective servers
3. Verify security groups and network connectivity
4. Ensure IAM permissions are correctly configured

## 📝 License

This deployment guide is part of the BMI Health Tracker project.
