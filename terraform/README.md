# BMI Health Tracker - Terraform Infrastructure

This directory contains Terraform configuration for deploying the BMI Health Tracker application as a 3-tier architecture on AWS.

## Architecture Overview

The infrastructure consists of:

1. **Frontend Tier** - Nginx server serving React application
2. **Backend Tier** - Node.js/Express API with PM2 process manager
3. **Database Tier** - PostgreSQL database server
4. **Load Balancer** - Application Load Balancer with HTTPS
5. **DNS** - Route53 A record with ACM SSL certificate

All compute resources run on EC2 Ubuntu 22.04 LTS instances in private subnets.

## Prerequisites

### Required AWS Resources (You Provide)

- AWS CLI configured with named profile
- VPC with public and private subnets
- Security Groups:
  - ALB SG: Allow 80, 443 from 0.0.0.0/0
  - Frontend SG: Allow 80 from ALB SG
  - Backend SG: Allow 3000 from Frontend SG
  - Database SG: Allow 5432 from Backend SG
- Route53 Hosted Zone
- EC2 Key Pair for SSH access
- S3 bucket for Terraform state
- (Optional) DynamoDB table for state locking

### Required Tools

- Terraform >= 1.0
- AWS CLI v2
- Git

## Security Group Rules Reference

```hcl
# ALB Security Group
Inbound:
  - Port 80 (HTTP) from 0.0.0.0/0
  - Port 443 (HTTPS) from 0.0.0.0/0
Outbound:
  - All traffic

# Frontend Security Group
Inbound:
  - Port 80 from ALB Security Group
  - Port 22 from Bastion/VPN (optional)
Outbound:
  - All traffic

# Backend Security Group
Inbound:
  - Port 3000 from Frontend Security Group
  - Port 22 from Bastion/VPN (optional)
Outbound:
  - All traffic

# Database Security Group
Inbound:
  - Port 5432 from Backend Security Group
  - Port 22 from Bastion/VPN (optional)
Outbound:
  - All traffic
```

## Setup Instructions

### 1. Clone Repository

```bash
cd terraform-3-tier-different-servers/terraform
```

### 2. Configure Backend

Create `backend-config.tfbackend` file:

```hcl
bucket         = "your-terraform-state-bucket"
key            = "bmi-health-tracker/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
profile        = "your-aws-profile"
dynamodb_table = "terraform-state-lock"  # Optional
```

**Note:** Add this file to `.gitignore` - never commit credentials!

### 3. Configure Variables

Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# AWS Configuration
aws_region  = "us-east-1"
aws_profile = "your-profile"

# Networking
vpc_id             = "vpc-xxxxx"
public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy"]
private_subnet_ids = ["subnet-zzzzz", "subnet-aaaaa"]

# Security Groups
alb_security_group_id      = "sg-xxxxx"
frontend_security_group_id = "sg-yyyyy"
backend_security_group_id  = "sg-zzzzz"
database_security_group_id = "sg-aaaaa"

# Route53
hosted_zone_id = "Z123456789ABC"
domain_name    = "bmi.example.com"

# EC2
key_name = "your-key-pair"

# Application
git_repo_url = "https://github.com/your-username/bmi-health-tracker.git"
git_branch   = "main"

# Database
db_password = "your-secure-password"  # Use strong password!
```

**Important:** Add `terraform.tfvars` to `.gitignore` - it contains sensitive data!

### 4. Initialize Terraform

```bash
terraform init -backend-config=backend-config.tfbackend
```

This will:
- Download required providers
- Configure S3 backend for state storage

### 5. Validate Configuration

```bash
terraform validate
terraform fmt -recursive
```

### 6. Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan carefully. You should see:
- 3 EC2 instances (database, backend, frontend)
- 1 Application Load Balancer
- 1 Target Group
- 1 ACM Certificate
- Route53 records (A record + certificate validation)
- Various listeners and attachments

### 7. Deploy Infrastructure

```bash
terraform apply tfplan
```

This will take approximately 5-10 minutes for:
- Infrastructure provisioning: 2-3 minutes
- User data scripts execution: 5-8 minutes
  - Database setup: 2-3 minutes
  - Backend deployment: 2-3 minutes
  - Frontend build and deployment: 2-3 minutes

### 8. Get Outputs

```bash
terraform output
```

Key outputs:
- `application_url` - Your application URL (https://bmi.example.com)
- `alb_dns_name` - ALB DNS for testing before DNS propagation
- `*_private_ip` - Private IPs of all instances
- `deployment_info` - Next steps and verification instructions

## Post-Deployment Verification

### 1. Wait for Initialization

User data scripts take 5-10 minutes to complete. Monitor progress:

```bash
# Via AWS Console
EC2 > Instances > Select Instance > Actions > Monitor and troubleshoot > Get system log

# Via AWS CLI
aws ec2 get-console-output --instance-id <instance-id> --profile your-profile
```

### 2. Check ALB Health

```bash
# Via AWS Console
EC2 > Target Groups > Select frontend-tg > Check "Targets" tab

# Via AWS CLI
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --profile your-profile
```

Status should show "healthy" after 2-3 minutes.

### 3. Test Application

```bash
# Test via ALB DNS (works immediately)
curl -I http://<alb-dns-name>

# Test via domain (after DNS propagation, ~5-10 minutes)
curl -I https://bmi.example.com
```

### 4. SSH to Instances (Optional)

Requires bastion host or VPN connection to private subnets:

```bash
# Database
ssh -i ~/.ssh/your-key.pem ubuntu@<database-private-ip>
tail -f /var/log/user-data.log

# Backend
ssh -i ~/.ssh/your-key.pem ubuntu@<backend-private-ip>
pm2 logs bmi-backend

# Frontend
ssh -i ~/.ssh/your-key.pem ubuntu@<frontend-private-ip>
tail -f /var/log/nginx/bmi-access.log
```

## Troubleshooting

### Certificate Validation Pending

If ACM certificate stays in "Pending validation" status:

1. Check Route53 validation records were created:
   ```bash
   aws route53 list-resource-record-sets \
     --hosted-zone-id <zone-id> \
     --profile your-profile
   ```

2. Verify CNAME records match ACM validation requirements

3. Wait up to 30 minutes for DNS propagation

### Target Health Check Failing

If frontend target shows "unhealthy":

1. Check security groups allow ALB → Frontend on port 80
2. Verify Nginx is running: `systemctl status nginx`
3. Check frontend logs: `/var/log/nginx/bmi-error.log`
4. Test health endpoint locally: `curl http://localhost/`

### Backend Connection Issues

If backend can't connect to database:

1. Verify security groups allow Backend → Database on port 5432
2. Check PostgreSQL is listening: `sudo -u postgres psql -c "SELECT version();"`
3. Test connection from backend: `psql -h <db-ip> -U bmi_user -d bmidb`
4. Review backend logs: `pm2 logs bmi-backend`

### DNS Not Resolving

If domain doesn't resolve:

1. Check Route53 A record exists and points to ALB
2. Verify nameservers are correct: `dig NS example.com`
3. Wait for DNS propagation (up to 48 hours, typically 5-10 minutes)
4. Test with ALB DNS name instead

## Updating Infrastructure

### Update Application Code

To deploy new code without rebuilding infrastructure:

1. SSH to each instance
2. Pull latest code: `git pull origin main`
3. Restart services:
   - Backend: `pm2 restart bmi-backend`
   - Frontend: `npm run build && cp -r dist/* /var/www/bmi-health-tracker/`

### Update Infrastructure

```bash
# Modify variables or configurations
vim terraform.tfvars

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan
```

**Warning:** Changes to instances may cause downtime!

## Destroying Infrastructure

To remove all resources:

```bash
terraform destroy
```

**Warning:** This will:
- Delete all EC2 instances (data loss!)
- Remove Load Balancer
- Delete ACM certificate
- Remove Route53 records

Always backup database data before destroying!

## Module Structure

```
terraform/
├── main.tf                 # Root module
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── backend.tf              # S3 backend config
├── terraform.tfvars        # Variable values (gitignored)
├── terraform.tfvars.example # Example configuration
├── backend-config.tfbackend # Backend config (gitignored)
└── modules/
    ├── alb/               # Application Load Balancer
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── dns/               # Route53 DNS
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── ec2/               # Compute instances
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── templates/     # User data scripts
            ├── database-init.sh
            ├── backend-init.sh
            └── frontend-init.sh
```

## Cost Estimation

Approximate monthly costs (us-east-1):

- **EC2 Instances**
  - Frontend (t3.small): ~$15/month
  - Backend (t3.small): ~$15/month
  - Database (t3.medium): ~$30/month
- **ALB**: ~$16/month + data transfer
- **EBS Storage** (70 GB): ~$7/month
- **Data Transfer**: Variable
- **Route53**: $0.50 per hosted zone + queries

**Total**: ~$85-100/month (excluding data transfer)

## Security Best Practices

1. **Secrets Management**
   - Store `db_password` in AWS Secrets Manager
   - Use IAM roles instead of access keys
   - Rotate credentials regularly

2. **Network Security**
   - All compute in private subnets ✓
   - Least-privilege security groups ✓
   - Enable VPC Flow Logs

3. **Data Protection**
   - Enable EBS encryption ✓
   - Enable RDS encryption (if migrating)
   - Regular automated backups

4. **Access Control**
   - Use bastion host or SSM Session Manager
   - Enable MFA for AWS accounts
   - Audit access logs regularly

5. **Monitoring**
   - Enable CloudWatch monitoring
   - Set up alerts for health check failures
   - Monitor costs with AWS Budgets

## Next Steps

1. **Set up CI/CD**: Automate deployments with GitHub Actions or GitLab CI
2. **Implement Monitoring**: Add CloudWatch dashboards and alarms
3. **Enable Backups**: Automate database backups with AWS Backup
4. **Add Auto Scaling**: Implement ASG for high availability
5. **Migrate to RDS**: Consider managed PostgreSQL for production

## Support

For issues or questions:
- Check AWS CloudWatch logs
- Review user data logs: `/var/log/user-data.log`
- Consult Terraform documentation: https://www.terraform.io/docs

## License

This infrastructure code is part of the BMI Health Tracker project.
