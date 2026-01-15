# BMI Health Tracker - Quick Start Guide

## Prerequisites Checklist

### ✅ AWS Resources
- [ ] AWS Account with appropriate permissions
- [ ] AWS CLI installed and configured
- [ ] Named AWS profile configured (`~/.aws/credentials`)
- [ ] VPC created with:
  - [ ] At least 2 public subnets (for ALB)
  - [ ] At least 1 private subnet (for EC2 instances)
- [ ] Security Groups created:
  - [ ] ALB SG (allow 80, 443 from internet)
  - [ ] Frontend SG (allow 80 from ALB SG)
  - [ ] Backend SG (allow 3000 from Frontend SG)
  - [ ] Database SG (allow 5432 from Backend SG)
- [ ] Route53 Hosted Zone for your domain
- [ ] EC2 Key Pair created and downloaded
- [ ] S3 bucket for Terraform state
- [ ] (Optional) DynamoDB table for state locking

### ✅ Local Setup
- [ ] Terraform >= 1.0 installed
- [ ] Git installed
- [ ] Repository cloned locally

## 5-Minute Deployment

### Step 1: Configure Backend (2 minutes)

```bash
cd terraform

# Copy backend config template
cp backend-config.tfbackend.example backend-config.tfbackend

# Edit with your values
vim backend-config.tfbackend
```

Update these values:
```hcl
bucket  = "your-s3-bucket-name"
region  = "us-east-1"
profile = "your-aws-profile"
```

### Step 2: Configure Variables (3 minutes)

```bash
# Copy variables template
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Required values to change:**
```hcl
aws_profile = "your-aws-profile-name"
vpc_id = "vpc-xxxxx"
public_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
private_subnet_ids = ["subnet-zzzzz"]
alb_security_group_id = "sg-xxxxx"
frontend_security_group_id = "sg-yyyyy"
backend_security_group_id = "sg-zzzzz"
database_security_group_id = "sg-aaaaa"
hosted_zone_id = "Z123456789ABC"
domain_name = "bmi.example.com"
key_name = "your-key-pair"
git_repo_url = "https://github.com/username/repo.git"
db_password = "StrongPassword123!"
```

### Step 3: Initialize Terraform (30 seconds)

```bash
terraform init -backend-config=backend-config.tfbackend
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 4: Deploy (10-15 minutes)

```bash
# Review what will be created
terraform plan

# Deploy infrastructure
terraform apply -auto-approve
```

**Wait 10-15 minutes for:**
- Infrastructure creation (3-5 min)
- User data scripts execution (7-10 min)

### Step 5: Verify Deployment (2 minutes)

```bash
# Get application URL
terraform output application_url

# Test application
curl -I https://bmi.example.com
```

**Expected:** HTTP 200 OK

## Quick Verification Commands

```bash
# Check all outputs
terraform output

# Check ALB health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --profile your-profile

# Get instance IDs
terraform output frontend_instance_id
terraform output backend_instance_id
terraform output database_instance_id

# View instance logs (requires instance ID)
aws ec2 get-console-output \
  --instance-id <instance-id> \
  --profile your-profile
```

## Common Issues & Quick Fixes

### Issue 1: Certificate Validation Pending

**Solution:** Wait 10-30 minutes for DNS propagation
```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn) \
  --profile your-profile
```

### Issue 2: Unhealthy Target

**Solution:** Wait for user data scripts to complete
```bash
# Check instance system log
aws ec2 get-console-output \
  --instance-id $(terraform output -raw frontend_instance_id) \
  --profile your-profile | grep "Initialization Complete"
```

### Issue 3: Cannot Connect to Application

**Solution:** Check DNS propagation
```bash
# Test with ALB DNS directly
curl -I http://$(terraform output -raw alb_dns_name)

# Check DNS resolution
dig bmi.example.com
nslookup bmi.example.com
```

### Issue 4: Backend Errors

**Solution:** Check database connectivity
```bash
# View backend logs (requires SSH access)
ssh -i ~/.ssh/your-key.pem ubuntu@$(terraform output -raw backend_private_ip)
pm2 logs bmi-backend
```

## Clean Up

To destroy all resources:

```bash
terraform destroy -auto-approve
```

**Warning:** This deletes everything including the database!

## Next Steps

1. ✅ Application deployed successfully
2. [ ] Set up monitoring and alerts
3. [ ] Configure automated backups
4. [ ] Implement CI/CD pipeline
5. [ ] Enable auto-scaling (optional)
6. [ ] Set up development environment

## Getting Help

- **Terraform Errors:** Check `terraform.log`
- **Application Errors:** Check `/var/log/user-data.log` on instances
- **AWS Issues:** Check CloudWatch logs
- **Documentation:** See [README.md](README.md) for detailed guide

## Useful AWS CLI Commands

```bash
# List all EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=bmi-health-tracker" \
  --profile your-profile

# Get ALB status
aws elbv2 describe-load-balancers \
  --profile your-profile

# Check Route53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id your-zone-id \
  --profile your-profile

# View CloudWatch logs (if configured)
aws logs tail /aws/ec2/bmi-health-tracker \
  --follow \
  --profile your-profile
```

## Estimated Deployment Time

| Phase | Duration | Status Check |
|-------|----------|--------------|
| Terraform Init | 30s | `terraform validate` |
| Infrastructure Creation | 3-5 min | `terraform output` |
| Database Setup | 2-3 min | Check system log |
| Backend Deployment | 2-3 min | `curl backend:3000/health` |
| Frontend Build | 2-3 min | `curl frontend:80` |
| DNS Propagation | 5-10 min | `dig domain` |
| Certificate Validation | 5-30 min | Check ACM console |
| **Total** | **15-45 min** | Application accessible |

## Cost Estimate

**Monthly cost (us-east-1):**
- 3x EC2 instances: ~$60/month
- ALB: ~$16/month
- EBS storage: ~$7/month
- Route53: ~$1/month
- Data transfer: Variable

**Total: ~$85-100/month**

---

**Ready to deploy?** Start with Step 1! 🚀

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide

📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://linkedin.com/in/sarowar)
