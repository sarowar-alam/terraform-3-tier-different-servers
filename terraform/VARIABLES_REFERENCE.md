# Terraform Variables Reference Guide

Complete reference for all variables used in this Terraform configuration.

## Quick Reference Table

| Variable | Required | Default | Example | Description |
|----------|----------|---------|---------|-------------|
| `aws_region` | No | us-east-1 | us-east-1 | AWS region for resources |
| `aws_profile` | **Yes** | - | my-profile | AWS CLI named profile |
| `vpc_id` | **Yes** | - | vpc-12345678 | VPC ID |
| `public_subnet_ids` | **Yes** | - | ["subnet-xxx", "subnet-yyy"] | Public subnet IDs for ALB |
| `private_subnet_ids` | **Yes** | - | ["subnet-zzz"] | Private subnet IDs for EC2 |
| `alb_security_group_id` | **Yes** | - | sg-12345678 | ALB security group ID |
| `frontend_security_group_id` | **Yes** | - | sg-23456789 | Frontend SG ID |
| `backend_security_group_id` | **Yes** | - | sg-34567890 | Backend SG ID |
| `database_security_group_id` | **Yes** | - | sg-45678901 | Database SG ID |
| `hosted_zone_id` | **Yes** | - | Z1234567890ABC | Route53 zone ID |
| `domain_name` | **Yes** | - | bmi.example.com | Application domain |
| `instance_type_frontend` | No | t3.small | t3.medium | Frontend instance type |
| `instance_type_backend` | No | t3.small | t3.medium | Backend instance type |
| `instance_type_database` | No | t3.medium | t3.large | Database instance type |
| `key_name` | **Yes** | - | my-key-pair | EC2 key pair name |
| `ami_id` | No | (auto) | ami-xxx | Ubuntu AMI (auto-detected) |
| `git_repo_url` | **Yes** | - | https://github.com/user/repo.git | Git repository URL |
| `git_branch` | No | main | develop | Git branch to deploy |
| `db_name` | No | bmidb | mydb | PostgreSQL database name |
| `db_user` | No | bmi_user | dbuser | Database username |
| `db_password` | **Yes** | - | SecurePass123! | Database password |
| `db_port` | No | 5432 | 5432 | PostgreSQL port |
| `backend_port` | No | 3000 | 8080 | Backend API port |
| `project_name` | No | bmi-health-tracker | my-project | Project name for tagging |
| `environment` | No | production | staging | Environment name |
| `common_tags` | No | {} | {Owner: "Team"} | Additional tags |

## Detailed Variable Descriptions

### AWS Configuration

#### aws_region
```hcl
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
```
- **Purpose**: AWS region where all resources will be created
- **Recommendation**: Use region closest to your users
- **Common values**: us-east-1, us-west-2, eu-west-1, ap-southeast-1

#### aws_profile
```hcl
variable "aws_profile" {
  type     = string
  required = true
}
```
- **Purpose**: AWS CLI named profile for authentication
- **Setup**: Configure with `aws configure --profile your-profile`
- **Example**: "default", "production", "my-aws-account"
- **Security**: Stored in ~/.aws/credentials

### Networking Variables

#### vpc_id
```hcl
variable "vpc_id" {
  type     = string
  required = true
}
```
- **Purpose**: VPC where all resources will be deployed
- **Format**: vpc-xxxxxxxxxxxxxxxxx (17 characters after vpc-)
- **How to find**: AWS Console → VPC → Your VPCs
- **CLI**: `aws ec2 describe-vpcs --profile your-profile`

#### public_subnet_ids
```hcl
variable "public_subnet_ids" {
  type     = list(string)
  required = true
}
```
- **Purpose**: Public subnets for Application Load Balancer
- **Format**: ["subnet-xxxxxxxxx", "subnet-yyyyyyyyy"]
- **Requirements**: 
  - Must be in different Availability Zones
  - Must have route to Internet Gateway
  - Minimum 2 subnets for high availability
- **How to find**: AWS Console → VPC → Subnets (filter by VPC)
- **CLI**: `aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxx"`

#### private_subnet_ids
```hcl
variable "private_subnet_ids" {
  type     = list(string)
  required = true
}
```
- **Purpose**: Private subnets for EC2 instances (database, backend, frontend)
- **Format**: ["subnet-zzzzzzzzz", "subnet-aaaaaaaaa"]
- **Requirements**: 
  - Must not have direct route to Internet Gateway
  - Can have route to NAT Gateway (optional but recommended)
  - Minimum 1 subnet required
- **Note**: All 3 instances will be in the first subnet by default

### Security Group Variables

All security group variables follow the same pattern:

```hcl
variable "<tier>_security_group_id" {
  type     = string
  required = true
}
```

#### alb_security_group_id
- **Inbound**: 80 (HTTP) from 0.0.0.0/0, 443 (HTTPS) from 0.0.0.0/0
- **Outbound**: All traffic
- **Purpose**: Allow internet traffic to load balancer

#### frontend_security_group_id
- **Inbound**: 80 (HTTP) from ALB SG, [22 (SSH) from Bastion (optional)]
- **Outbound**: All traffic
- **Purpose**: Allow ALB to reach frontend, allow outbound for package installation

#### backend_security_group_id
- **Inbound**: 3000 (TCP) from Frontend SG, [22 (SSH) from Bastion (optional)]
- **Outbound**: All traffic
- **Purpose**: Allow frontend to reach backend API

#### database_security_group_id
- **Inbound**: 5432 (PostgreSQL) from Backend SG, [22 (SSH) from Bastion (optional)]
- **Outbound**: All traffic
- **Purpose**: Allow backend to access database

### DNS Variables

#### hosted_zone_id
```hcl
variable "hosted_zone_id" {
  type     = string
  required = true
}
```
- **Purpose**: Route53 hosted zone for DNS records
- **Format**: Z + 13 characters (e.g., Z1234567890ABC)
- **How to find**: AWS Console → Route53 → Hosted zones
- **CLI**: `aws route53 list-hosted-zones --profile your-profile`
- **Important**: Must be for the domain you're using

#### domain_name
```hcl
variable "domain_name" {
  type     = string
  required = true
}
```
- **Purpose**: Fully qualified domain name for the application
- **Format**: subdomain.domain.com (e.g., bmi.example.com)
- **Requirements**: 
  - Must match or be subdomain of hosted zone
  - Will be used for ACM certificate
  - Will be created as A record (alias to ALB)
- **Example values**: app.example.com, bmi.mycompany.com, www.mysite.com

### EC2 Variables

#### instance_type_frontend / backend / database
```hcl
variable "instance_type_<tier>" {
  type    = string
  default = "t3.small" # or t3.medium for database
}
```

**Instance Type Recommendations:**

| Workload | Instance Type | vCPU | RAM | Cost/Month |
|----------|--------------|------|-----|------------|
| **Development** | t3.micro | 2 | 1 GB | ~$8 |
| **Testing** | t3.small | 2 | 2 GB | ~$15 |
| **Production (Light)** | t3.medium | 2 | 4 GB | ~$30 |
| **Production (Medium)** | t3.large | 2 | 8 GB | ~$60 |
| **Production (Heavy)** | t3.xlarge | 4 | 16 GB | ~$121 |

**Sizing Guide:**
- **Frontend**: t3.small (Nginx is lightweight)
- **Backend**: t3.small (Node.js, adjust based on traffic)
- **Database**: t3.medium (PostgreSQL needs more memory)

#### key_name
```hcl
variable "key_name" {
  type     = string
  required = true
}
```
- **Purpose**: EC2 key pair for SSH access
- **Format**: Name only (not file path or .pem extension)
- **How to create**: AWS Console → EC2 → Key Pairs → Create
- **Example**: "my-key", "production-key", "bmi-app-key"
- **Important**: Download .pem file and keep secure

#### ami_id
```hcl
variable "ami_id" {
  type    = string
  default = "" # Auto-detects latest Ubuntu 22.04 LTS
}
```
- **Purpose**: Amazon Machine Image for EC2 instances
- **Default behavior**: Automatically finds latest Ubuntu 22.04 LTS
- **Override**: Specify AMI ID if you need specific version
- **Format**: ami-xxxxxxxxxxxxxxxxx
- **How to find**: AWS Console → EC2 → AMIs
- **Recommendation**: Leave empty for automatic detection

### Application Variables

#### git_repo_url
```hcl
variable "git_repo_url" {
  type     = string
  required = true
}
```
- **Purpose**: Git repository containing application code
- **Format**: https://github.com/username/repo.git
- **Supported**: HTTPS URLs (public repos)
- **Private repos**: Requires additional authentication setup
- **Example**: https://github.com/yourusername/bmi-health-tracker.git

#### git_branch
```hcl
variable "git_branch" {
  type    = string
  default = "main"
}
```
- **Purpose**: Git branch to deploy
- **Common values**: main, master, develop, production
- **Use case**: Deploy different branches to different environments

### Database Variables

#### db_name
```hcl
variable "db_name" {
  type    = string
  default = "bmidb"
}
```
- **Purpose**: PostgreSQL database name
- **Constraints**: 
  - Alphanumeric and underscores only
  - Max 63 characters
  - Cannot start with pg_
- **Example**: bmidb, health_tracker, production_db

#### db_user
```hcl
variable "db_user" {
  type    = string
  default = "bmi_user"
}
```
- **Purpose**: PostgreSQL username
- **Constraints**: 
  - Alphanumeric and underscores only
  - Max 63 characters
  - Cannot be: postgres, root, admin
- **Example**: bmi_user, app_user, dbadmin

#### db_password
```hcl
variable "db_password" {
  type      = string
  sensitive = true
  required  = true
}
```
- **Purpose**: PostgreSQL password
- **Security**: 
  - Marked as sensitive (not shown in output)
  - Should be strong and unique
  - Never commit to version control
- **Requirements**:
  - Minimum 12 characters
  - Mix of uppercase, lowercase, numbers, special chars
  - Avoid dictionary words
- **Example**: Use password manager to generate

#### db_port
```hcl
variable "db_port" {
  type    = number
  default = 5432
}
```
- **Purpose**: PostgreSQL port
- **Default**: 5432 (standard PostgreSQL port)
- **Change only if**: You have specific security requirements

#### backend_port
```hcl
variable "backend_port" {
  type    = number
  default = 3000
}
```
- **Purpose**: Backend API server port
- **Default**: 3000 (standard Node.js port)
- **Change only if**: You have port conflicts

### Tagging Variables

#### project_name
```hcl
variable "project_name" {
  type    = string
  default = "bmi-health-tracker"
}
```
- **Purpose**: Used for resource naming and tagging
- **Applied to**: All AWS resources
- **Format**: lowercase, hyphens allowed
- **Example**: "bmi-app", "health-tracker", "my-project"

#### environment
```hcl
variable "environment" {
  type    = string
  default = "production"
}
```
- **Purpose**: Environment identifier for resources
- **Common values**: production, staging, development, test
- **Use case**: Distinguish resources across environments

#### common_tags
```hcl
variable "common_tags" {
  type    = map(string)
  default = {}
}
```
- **Purpose**: Additional custom tags for all resources
- **Format**: Key-value map
- **Example**:
  ```hcl
  common_tags = {
    Owner      = "DevOps Team"
    CostCenter = "Engineering"
    Compliance = "HIPAA"
  }
  ```

## Environment-Specific Examples

### Development Environment
```hcl
aws_region  = "us-east-1"
aws_profile = "dev-profile"

instance_type_frontend = "t3.micro"
instance_type_backend  = "t3.micro"
instance_type_database = "t3.small"

environment  = "development"
domain_name  = "dev-bmi.example.com"
git_branch   = "develop"
```

### Production Environment
```hcl
aws_region  = "us-east-1"
aws_profile = "prod-profile"

instance_type_frontend = "t3.small"
instance_type_backend  = "t3.medium"
instance_type_database = "t3.large"

environment  = "production"
domain_name  = "bmi.example.com"
git_branch   = "main"
```

## Validation Rules

Terraform validates these rules automatically:

- ✅ `vpc_id` must start with "vpc-"
- ✅ Subnet IDs must start with "subnet-"
- ✅ Security group IDs must start with "sg-"
- ✅ `db_password` is marked sensitive
- ✅ All required variables must be provided

## Best Practices

### Security
- ✅ Never commit `terraform.tfvars` to version control
- ✅ Use strong passwords (generated by password manager)
- ✅ Rotate credentials regularly
- ✅ Use AWS Secrets Manager for sensitive values (advanced)

### Organization
- ✅ Use consistent naming conventions
- ✅ Add meaningful tags to all resources
- ✅ Document non-obvious values
- ✅ Keep environment-specific configs separate

### Maintenance
- ✅ Review and update AMI regularly
- ✅ Test changes in development first
- ✅ Document any customizations
- ✅ Keep variable descriptions current

## Common Mistakes

❌ **Using wrong subnet type**
- ALB needs public subnets (with IGW route)
- EC2 instances need private subnets

❌ **Incorrect security group rules**
- Check source/destination in rules
- Verify port numbers match application

❌ **Weak database password**
- Use password manager
- Minimum 12 characters
- Mix character types

❌ **Wrong hosted zone**
- Must match domain name
- Verify nameservers at registrar

❌ **Forgetting to change defaults**
- db_password is required!
- Review all "your-xxx" placeholders

## Getting Values

### Find VPC ID
```bash
aws ec2 describe-vpcs --profile your-profile
```

### Find Subnet IDs
```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxx" --profile your-profile
```

### Find Security Group IDs
```bash
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-xxx" --profile your-profile
```

### Find Hosted Zone ID
```bash
aws route53 list-hosted-zones --profile your-profile
```

### Find Key Pairs
```bash
aws ec2 describe-key-pairs --profile your-profile
```

## Questions?

See [README.md](README.md) for detailed documentation or [QUICK_START.md](QUICK_START.md) for quick deployment guide.

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide

📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://linkedin.com/in/sarowar)
