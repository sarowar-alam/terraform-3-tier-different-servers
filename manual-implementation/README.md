# BMI Health Tracker - Manual Implementation Guide

Complete guide to manually deploy the BMI Health Tracker on AWS EC2 instances without Terraform.

## Overview

This guide helps you deploy a 3-tier architecture manually on AWS:
- **Database Server**: PostgreSQL on EC2
- **Backend Server**: Node.js/Express on EC2
- **Frontend Server**: Nginx/React on EC2
- **Load Balancer**: Application Load Balancer (manual setup via AWS Console)
- **DNS**: Route53 record (manual setup via AWS Console)

## Prerequisites

### AWS Resources Required

- [ ] AWS Account with appropriate permissions
- [ ] VPC with public and private subnets
- [ ] 4 Security Groups (ALB, Frontend, Backend, Database)
- [ ] 3 EC2 instances (Ubuntu 22.04 LTS)
- [ ] Route53 Hosted Zone (ostaddevops.click)
- [ ] SSH key pair downloaded

### Local Requirements

- [ ] AWS CLI installed and configured
- [ ] SSH client (PuTTY on Windows, ssh on Linux/Mac)
- [ ] Git (for cloning repository)

## Architecture

```
Internet
   │
   ↓
Route53: bmi.ostaddevops.click
   │
   ↓
Application Load Balancer (Public Subnets)
   │
   ↓
┌──────────────────────────────────────────┐
│         Private Subnet                   │
│                                          │
│  Frontend EC2 ──→ Backend EC2 ──→ DB EC2 │
│  (Nginx)         (Node.js)      (PostgreSQL) │
└──────────────────────────────────────────┘
```

## Deployment Steps

### Phase 1: Launch EC2 Instances (30 minutes)

1. **Launch Database Instance**
   - AMI: Ubuntu 22.04 LTS
   - Instance Type: t3.medium
   - Subnet: Private subnet
   - Security Group: Database SG
   - Key Pair: Your key pair
   - Tag: Name=bmi-database

2. **Launch Backend Instance**
   - AMI: Ubuntu 22.04 LTS
   - Instance Type: t3.small
   - Subnet: Private subnet
   - Security Group: Backend SG
   - Key Pair: Your key pair
   - Tag: Name=bmi-backend

3. **Launch Frontend Instance**
   - AMI: Ubuntu 22.04 LTS
   - Instance Type: t3.small
   - Subnet: Private subnet
   - Security Group: Frontend SG
   - Key Pair: Your key pair
   - IAM Role: Create role with Route53 and ACM permissions (see iam-role-policy.json)
   - Tag: Name=bmi-frontend

### Phase 2: Setup Database Server (15 minutes)

SSH to database instance:
```bash
ssh -i your-key.pem ubuntu@<database-private-ip>
```

Run the setup script:
```bash
# Download setup script
curl -o setup-database.sh https://raw.githubusercontent.com/your-repo/manual-implementation/setup-database.sh

# Make executable
chmod +x setup-database.sh

# Run with your values
sudo ./setup-database.sh
```

Or manually follow: [01-database-setup.sh](01-database-setup.sh)

### Phase 3: Setup Backend Server (15 minutes)

SSH to backend instance:
```bash
ssh -i your-key.pem ubuntu@<backend-private-ip>
```

Run the setup script:
```bash
# Download setup script
curl -o setup-backend.sh https://raw.githubusercontent.com/your-repo/manual-implementation/setup-backend.sh

# Make executable
chmod +x setup-backend.sh

# Run with your values
sudo DB_HOST=<database-private-ip> \
     DB_PASSWORD=your-password \
     ./setup-backend.sh
```

Or manually follow: [02-backend-setup.sh](02-backend-setup.sh)

### Phase 4: Setup Frontend Server (20 minutes)

SSH to frontend instance:
```bash
ssh -i your-key.pem ubuntu@<frontend-private-ip>
```

Run the setup script:
```bash
# Download setup script
curl -o setup-frontend.sh https://raw.githubusercontent.com/your-repo/manual-implementation/setup-frontend.sh

# Make executable
chmod +x setup-frontend.sh

# Run with your values
sudo BACKEND_HOST=<backend-private-ip> \
     DOMAIN=bmi.ostaddevops.click \
     ./setup-frontend.sh
```

Or manually follow: [03-frontend-setup.sh](03-frontend-setup.sh)

### Phase 5: Setup Application Load Balancer (15 minutes)

#### Via AWS Console

1. **Create Target Group**
   - Go to: EC2 > Target Groups > Create target group
   - Target type: Instances
   - Target group name: bmi-frontend-tg
   - Protocol: HTTP, Port: 80
   - VPC: Your VPC
   - Health check path: /
   - Register targets: Select frontend instance
   - Create

2. **Create Application Load Balancer**
   - Go to: EC2 > Load Balancers > Create Load Balancer
   - Type: Application Load Balancer
   - Name: bmi-health-tracker-alb
   - Scheme: Internet-facing
   - IP address type: IPv4
   - Listeners: HTTP (80), HTTPS (443)
   - Availability Zones: Select your public subnets
   - Security group: ALB SG
   - Listeners:
     - HTTP:80 → Redirect to HTTPS:443
     - HTTPS:443 → Forward to bmi-frontend-tg
     - SSL Certificate: Upload/import from ACM
   - Create

#### Via AWS CLI

```bash
# Run the ALB setup script
./04-setup-alb.sh
```

### Phase 6: Setup Route53 DNS (5 minutes)

#### Via AWS Console

1. Go to: Route53 > Hosted zones > ostaddevops.click
2. Click "Create record"
3. Record name: bmi
4. Record type: A
5. Alias: Yes
6. Route traffic to: Alias to Application Load Balancer
7. Choose region and your ALB
8. Create records

#### Via AWS CLI

```bash
# Get hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='ostaddevops.click.'].Id" \
  --output text)

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names bmi-health-tracker-alb \
  --query "LoadBalancers[0].DNSName" \
  --output text)

# Create A record
./05-setup-dns.sh
```

### Phase 7: Setup Let's Encrypt Certificate (10 minutes)

On frontend instance:
```bash
# Install Certbot
sudo apt update
sudo apt install -y certbot python3-certbot-dns-route53

# Generate certificate
sudo certbot certonly \
  --dns-route53 \
  -d bmi.ostaddevops.click \
  -d "*.ostaddevops.click" \
  --preferred-challenges dns \
  --agree-tos \
  --email admin@ostaddevops.click

# Export to ACM
sudo aws acm import-certificate \
  --certificate fileb:///etc/letsencrypt/live/bmi.ostaddevops.click/fullchain.pem \
  --private-key fileb:///etc/letsencrypt/live/bmi.ostaddevops.click/privkey.pem \
  --region ap-south-1
```

Or use: [06-setup-certificate.sh](06-setup-certificate.sh)

## Verification

### Test Each Component

1. **Database**
   ```bash
   ssh ubuntu@<db-ip>
   sudo -u postgres psql -d bmidb -c "SELECT version();"
   ```

2. **Backend**
   ```bash
   ssh ubuntu@<backend-ip>
   curl http://localhost:3000/health
   pm2 status
   ```

3. **Frontend**
   ```bash
   ssh ubuntu@<frontend-ip>
   curl http://localhost/
   sudo systemctl status nginx
   ```

4. **ALB**
   ```bash
   curl -I http://<alb-dns-name>
   ```

5. **Full Application**
   ```bash
   curl -I https://bmi.ostaddevops.click
   ```

## Configuration Files

All configuration files are in this directory:

- [01-database-setup.sh](01-database-setup.sh) - Database installation script
- [02-backend-setup.sh](02-backend-setup.sh) - Backend installation script
- [03-frontend-setup.sh](03-frontend-setup.sh) - Frontend installation script
- [04-setup-alb.sh](04-setup-alb.sh) - ALB setup via CLI
- [05-setup-dns.sh](05-setup-dns.sh) - DNS record creation
- [06-setup-certificate.sh](06-setup-certificate.sh) - Let's Encrypt certificate
- [iam-role-policy.json](iam-role-policy.json) - IAM policy for frontend EC2
- [nginx-config.conf](nginx-config.conf) - Nginx configuration template
- [backend-env.template](backend-env.template) - Backend .env template
- [pm2-ecosystem.config.js](pm2-ecosystem.config.js) - PM2 configuration

## Troubleshooting

### Database Connection Issues

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check port is listening
sudo netstat -plnt | grep 5432

# Test connection
psql -h <db-private-ip> -U bmi_user -d bmidb
```

### Backend API Issues

```bash
# Check PM2 status
pm2 status
pm2 logs bmi-backend

# Restart backend
pm2 restart bmi-backend

# Check environment variables
pm2 env bmi-backend
```

### Frontend Issues

```bash
# Check Nginx
sudo nginx -t
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log

# Reload Nginx
sudo systemctl reload nginx
```

### ALB Health Check Failing

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Check security group rules
# Ensure ALB SG can reach Frontend SG on port 80
```

## Security Checklist

- [ ] Database only accessible from Backend SG
- [ ] Backend only accessible from Frontend SG
- [ ] Frontend only accessible from ALB SG
- [ ] ALB accessible from internet on 80, 443
- [ ] SSH key secured (600 permissions)
- [ ] Database password changed from default
- [ ] SSL certificate installed and working
- [ ] HTTP redirects to HTTPS
- [ ] Security groups follow least-privilege principle

## Maintenance

### Update Application Code

```bash
# Backend
ssh ubuntu@<backend-ip>
cd ~/bmi-health-tracker/backend
git pull origin main
npm install --production
pm2 restart bmi-backend

# Frontend
ssh ubuntu@<frontend-ip>
cd ~/bmi-health-tracker/frontend
git pull origin main
npm install
npm run build
sudo cp -r dist/* /var/www/bmi-health-tracker/
```

### Renew SSL Certificate

Certificate auto-renews via cron job. To force renewal:
```bash
sudo certbot renew --force-renewal
sudo systemctl reload nginx
sudo /usr/local/bin/update-acm-cert.sh
```

### Backup Database

```bash
ssh ubuntu@<db-ip>
sudo -u postgres pg_dump bmidb > bmidb_backup_$(date +%Y%m%d).sql
```

## Cost Estimation

| Resource | Specification | Monthly Cost (ap-south-1) |
|----------|--------------|---------------------------|
| Frontend EC2 | t3.small | ~$12 |
| Backend EC2 | t3.small | ~$12 |
| Database EC2 | t3.medium | ~$24 |
| ALB | Standard | ~$18 |
| EBS Storage | 70 GB gp3 | ~$6 |
| Route53 | Hosted zone | ~$0.50 |
| Data Transfer | Variable | ~$10-20 |
| **Total** | | **~$85-95/month** |

## Comparison: Manual vs Terraform

| Aspect | Manual | Terraform |
|--------|--------|-----------|
| Setup Time | 2-3 hours | 20 minutes |
| Repeatability | Manual steps each time | One command |
| Error Prone | High | Low |
| Documentation | Must maintain separately | Self-documenting |
| Version Control | Scripts only | Full infrastructure |
| Rollback | Manual | `terraform destroy` |
| Multi-Environment | Repeat all steps | Change variables |
| **Recommended For** | Learning, One-off | Production, Teams |

## Need Help?

- Check [troubleshooting section](#troubleshooting)
- Review logs on each instance
- Verify security group rules
- Test connectivity between tiers
- Check AWS CloudWatch logs

## Next Steps

After successful deployment:

1. Test all application features
2. Set up monitoring (CloudWatch)
3. Configure automated backups
4. Implement CI/CD pipeline
5. Add auto-scaling (optional)
6. Set up development environment

---

**Deployment Time**: ~2-3 hours for first-time setup

**Difficulty**: Intermediate (requires AWS and Linux knowledge)

**Recommended**: Use Terraform for production deployments
