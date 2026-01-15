# BMI Health Tracker - Deployment Checklist

Use this checklist to ensure all prerequisites are met before deploying.

## Phase 1: AWS Prerequisites

### VPC and Networking
- [ ] VPC created with appropriate CIDR block (e.g., 10.0.0.0/16)
- [ ] Internet Gateway attached to VPC
- [ ] Public subnets created (minimum 2 for ALB high availability)
  - [ ] Public subnet 1: _____________ (e.g., 10.0.1.0/24 in us-east-1a)
  - [ ] Public subnet 2: _____________ (e.g., 10.0.2.0/24 in us-east-1b)
- [ ] Private subnets created (minimum 1, recommended 2+)
  - [ ] Private subnet 1: _____________ (e.g., 10.0.11.0/24)
  - [ ] Private subnet 2: _____________ (optional)
- [ ] Public route table with route to Internet Gateway (0.0.0.0/0 → igw)
- [ ] Private route table (for NAT Gateway if needed)
- [ ] Route table associations configured

### Security Groups

#### ALB Security Group
- [ ] Security group ID: _____________
- [ ] Inbound Rules:
  - [ ] HTTP (80) from 0.0.0.0/0
  - [ ] HTTPS (443) from 0.0.0.0/0
- [ ] Outbound Rules:
  - [ ] All traffic to 0.0.0.0/0

#### Frontend Security Group
- [ ] Security group ID: _____________
- [ ] Inbound Rules:
  - [ ] HTTP (80) from ALB Security Group
  - [ ] SSH (22) from Bastion/VPN (optional)
- [ ] Outbound Rules:
  - [ ] All traffic to 0.0.0.0/0

#### Backend Security Group
- [ ] Security group ID: _____________
- [ ] Inbound Rules:
  - [ ] TCP (3000) from Frontend Security Group
  - [ ] SSH (22) from Bastion/VPN (optional)
- [ ] Outbound Rules:
  - [ ] All traffic to 0.0.0.0/0

#### Database Security Group
- [ ] Security group ID: _____________
- [ ] Inbound Rules:
  - [ ] PostgreSQL (5432) from Backend Security Group
  - [ ] SSH (22) from Bastion/VPN (optional)
- [ ] Outbound Rules:
  - [ ] All traffic to 0.0.0.0/0

### Route53
- [ ] Hosted zone created for domain
- [ ] Hosted zone ID: _____________
- [ ] Domain name: _____________
- [ ] Domain nameservers configured at registrar
- [ ] NS records verified: `dig NS yourdomain.com`

### IAM and Access
- [ ] AWS CLI installed locally
- [ ] AWS profile configured: _____________
- [ ] Profile has required permissions:
  - [ ] EC2 (create, modify, delete instances)
  - [ ] VPC (describe resources)
  - [ ] ELB (create, modify, delete load balancers)
  - [ ] Route53 (create, modify records)
  - [ ] ACM (request, describe certificates)
  - [ ] S3 (read/write state bucket)
  - [ ] DynamoDB (state locking, if used)

### EC2 Key Pair
- [ ] Key pair created in AWS Console
- [ ] Key pair name: _____________
- [ ] Private key downloaded: ~/.ssh/_____________.pem
- [ ] Key permissions set: `chmod 400 ~/.ssh/your-key.pem`

### S3 State Backend
- [ ] S3 bucket created for Terraform state
- [ ] Bucket name: _____________
- [ ] Bucket region: _____________
- [ ] Versioning enabled (recommended)
- [ ] Encryption enabled (recommended)
- [ ] (Optional) DynamoDB table for state locking
  - [ ] Table name: _____________
  - [ ] Primary key: LockID (String)

## Phase 2: Application Prerequisites

### Git Repository
- [ ] Repository exists and is accessible
- [ ] Repository URL: _____________
- [ ] Branch to deploy: _____________ (default: main)
- [ ] Repository is public OR
- [ ] SSH keys/tokens configured for private repo access

### Application Configuration
- [ ] Database password chosen (strong password)
- [ ] Domain name decided: _____________
- [ ] Domain points to correct Route53 hosted zone

## Phase 3: Local Setup

### Tools Installation
- [ ] Terraform installed (>= 1.0)
  - Version: `terraform version` → _____________
- [ ] AWS CLI installed (v2 recommended)
  - Version: `aws --version` → _____________
- [ ] Git installed
  - Version: `git --version` → _____________

### Project Files
- [ ] Repository cloned locally
- [ ] Navigate to terraform directory: `cd terraform/`
- [ ] terraform.tfvars created from example
- [ ] backend-config.tfbackend created from example
- [ ] All values in terraform.tfvars updated
- [ ] All values in backend-config.tfbackend updated

## Phase 4: Configuration Validation

### terraform.tfvars Checklist
```hcl
- [ ] aws_region = "us-east-1"
- [ ] aws_profile = "your-profile"
- [ ] vpc_id = "vpc-xxxxx"
- [ ] public_subnet_ids = ["subnet-xxx", "subnet-yyy"]
- [ ] private_subnet_ids = ["subnet-zzz"]
- [ ] alb_security_group_id = "sg-xxx"
- [ ] frontend_security_group_id = "sg-yyy"
- [ ] backend_security_group_id = "sg-zzz"
- [ ] database_security_group_id = "sg-aaa"
- [ ] hosted_zone_id = "Z123456789ABC"
- [ ] domain_name = "bmi.example.com"
- [ ] key_name = "your-key-pair"
- [ ] git_repo_url = "https://github.com/user/repo.git"
- [ ] db_password = "StrongPassword123!" (CHANGE THIS!)
```

### backend-config.tfbackend Checklist
```hcl
- [ ] bucket = "your-terraform-state-bucket"
- [ ] region = "us-east-1"
- [ ] profile = "your-profile"
```

## Phase 5: Pre-Deployment Validation

### Test AWS Access
```bash
- [ ] aws sts get-caller-identity --profile your-profile
  → Returns your AWS account ID
  
- [ ] aws ec2 describe-vpcs --vpc-ids vpc-xxxxx --profile your-profile
  → Returns VPC details
  
- [ ] aws s3 ls s3://your-terraform-state-bucket --profile your-profile
  → Lists bucket contents (or empty)
  
- [ ] aws route53 get-hosted-zone --id Z123456789ABC --profile your-profile
  → Returns hosted zone details
```

### Verify Network Connectivity
```bash
- [ ] Public subnets have internet access (via IGW)
- [ ] Private subnets can reach internet (via NAT Gateway) OR
- [ ] User data scripts include package installation (they do!)
```

### Security Group Validation
Create a simple test:
```bash
# From AWS Console or CLI, verify:
- [ ] ALB SG allows 80, 443 from internet
- [ ] Frontend SG allows 80 from ALB SG
- [ ] Backend SG allows 3000 from Frontend SG
- [ ] Database SG allows 5432 from Backend SG
```

## Phase 6: Deployment

### Initialize Terraform
```bash
- [ ] cd terraform/
- [ ] terraform init -backend-config=backend-config.tfbackend
  → "Terraform has been successfully initialized!"
```

### Validate Configuration
```bash
- [ ] terraform validate
  → "Success! The configuration is valid."
  
- [ ] terraform fmt -check
  → Files are properly formatted
```

### Plan Deployment
```bash
- [ ] terraform plan -out=tfplan
  → Review all resources to be created:
    - [ ] 3 EC2 instances
    - [ ] 1 ALB
    - [ ] 1 Target Group
    - [ ] 1 ACM Certificate
    - [ ] 2+ Route53 records
    - [ ] Various listeners and attachments
```

### Apply Configuration
```bash
- [ ] terraform apply tfplan
  → Type "yes" to confirm
  → Wait 10-15 minutes
```

## Phase 7: Post-Deployment Verification

### Immediate Checks (0-5 minutes)
```bash
- [ ] terraform output
  → All outputs displayed without errors
  
- [ ] Infrastructure created:
  - [ ] Database instance running
  - [ ] Backend instance running
  - [ ] Frontend instance running
  - [ ] ALB active
  - [ ] Target group created
```

### Health Checks (5-10 minutes)
```bash
- [ ] Check target health:
  aws elbv2 describe-target-health \
    --target-group-arn $(terraform output -raw target_group_arn)
  → Status: "healthy"
  
- [ ] Test ALB directly:
  curl -I http://$(terraform output -raw alb_dns_name)
  → HTTP 200 OK or 301 redirect
```

### Application Checks (10-15 minutes)
```bash
- [ ] Certificate validated (ACM Console)
  → Status: "Issued"
  
- [ ] DNS resolves:
  dig bmi.example.com
  → Returns ALB DNS name (A record alias)
  
- [ ] Application accessible:
  curl -I https://bmi.example.com
  → HTTP 200 OK
  
- [ ] Test in browser:
  → https://bmi.example.com opens
  → Can add measurements
  → Can view measurements list
```

### Detailed Verification (Optional)
```bash
- [ ] Check instance logs:
  aws ec2 get-console-output --instance-id <id>
  → Look for "Initialization Complete"
  
- [ ] SSH to instances (requires bastion/VPN):
  - [ ] Database: PostgreSQL running
  - [ ] Backend: PM2 shows bmi-backend running
  - [ ] Frontend: Nginx serving files
```

## Phase 8: Documentation

### Record Deployment Details
- [ ] Application URL: _____________
- [ ] ALB DNS Name: _____________
- [ ] Database Private IP: _____________
- [ ] Backend Private IP: _____________
- [ ] Frontend Private IP: _____________
- [ ] Deployment Date: _____________
- [ ] Terraform State Location: s3://____________/____________

### Share Information
- [ ] Document credentials securely (use password manager)
- [ ] Share application URL with stakeholders
- [ ] Update team wiki/documentation
- [ ] Set up monitoring alerts (recommended)

## Troubleshooting Quick Reference

### Issue: Certificate stuck in "Pending Validation"
- [ ] Check Route53 validation records exist
- [ ] Wait 30 minutes for DNS propagation
- [ ] Verify hosted zone is correct

### Issue: Target shows "Unhealthy"
- [ ] Check security groups
- [ ] Verify frontend user data completed
- [ ] Check instance system logs
- [ ] Test health endpoint: `curl http://<private-ip>/`

### Issue: Cannot connect to database
- [ ] Check backend security group → database SG rules
- [ ] Verify PostgreSQL is listening: check port 5432
- [ ] Test from backend: `telnet <db-ip> 5432`

### Issue: Frontend shows errors
- [ ] Check browser console for API errors
- [ ] Verify backend is accessible from frontend
- [ ] Check Nginx error logs: `/var/log/nginx/bmi-error.log`

## Cost Monitoring

### Set Up Billing Alerts
- [ ] Create AWS Budget for monthly spending
- [ ] Set alert threshold (e.g., $100/month)
- [ ] Configure email notifications

### Regular Review
- [ ] Weekly: Check AWS Cost Explorer
- [ ] Monthly: Review resource utilization
- [ ] Quarterly: Optimize instance types if needed

## Maintenance Schedule

### Daily
- [ ] Monitor CloudWatch alarms (if configured)
- [ ] Check application availability

### Weekly
- [ ] Review application logs
- [ ] Check for AWS service updates

### Monthly
- [ ] Review security group rules
- [ ] Update application dependencies
- [ ] Test backup and restore procedures

### Quarterly
- [ ] Review and rotate credentials
- [ ] Update AMIs to latest versions
- [ ] Perform security audit

## Rollback Plan

If deployment fails or issues occur:

```bash
# Option 1: Destroy everything
- [ ] terraform destroy
  → Removes all resources

# Option 2: Rollback specific changes
- [ ] Identify issue via logs
- [ ] Fix configuration
- [ ] terraform apply again

# Option 3: Use previous state
- [ ] Restore from S3 version (if enabled)
- [ ] terraform apply previous version
```

## Success Criteria

Deployment is successful when:
- [ ] ✅ All Terraform resources created without errors
- [ ] ✅ ALB health checks passing
- [ ] ✅ Certificate validated and HTTPS working
- [ ] ✅ Application accessible via domain name
- [ ] ✅ Can create and view measurements
- [ ] ✅ All services running (PostgreSQL, PM2, Nginx)
- [ ] ✅ No errors in application logs

---

## Sign-Off

**Deployment completed by:** _____________

**Date:** _____________

**Verified by:** _____________

**Notes:** _____________________________________________

---

**Congratulations! Your BMI Health Tracker is now live! 🎉**
