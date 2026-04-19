# Production-Grade 3-Tier BMI Health Tracker on AWS

[![Terraform](https://img.shields.io/badge/Terraform-1.x-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-ap--south--1-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Node.js](https://img.shields.io/badge/Node.js-20.x-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![React](https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=black)](https://reactjs.org/)
[![Nginx](https://img.shields.io/badge/Nginx-1.24-009639?logo=nginx&logoColor=white)](https://nginx.org/)
[![Route53](https://img.shields.io/badge/Route53-DNS-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/route53/)

**Enterprise-grade 3-tier web application infrastructure deployed on AWS using Infrastructure as Code principles.**

---

## Architecture Overview

This project provisions a complete production-ready infrastructure for a BMI Health Tracker application, demonstrating advanced DevOps practices and cloud architecture patterns suitable for enterprise deployments.

### AWS Infrastructure Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Route53 DNS                             │
│                    domain.com → EIP                             │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────────┐
│                          VPC (10.0.0.0/16)                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Public Subnet (10.0.1.0/24)                                │ │
│  │  ┌────────────────────────────────────────────────────────┐ │ │
│  │  │  Frontend Server (t3.small)                            │ │ │
│  │  │  • React 18 + Vite SPA                                 │ │ │
│  │  │  • Nginx Reverse Proxy                                 │ │ │
│  │  │  • Let's Encrypt TLS/SSL                               │ │ │
│  │  │  • Elastic IP (Public)                                 │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  │                      │                                      │ │
│  └──────────────────────┼──────────────────────────────────────┘ │ 
│                         │                                        │
│  ┌──────────────────────▼──────────────────────────────────────┐ │
│  │  Private Subnet (10.0.101.0/24)                             │ │
│  │  ┌────────────────────────┐  ┌─────────────────────────────┐│ │
│  │  │ Backend Server         │  │ Database Server             ││ │
│  │  │ (t3.small)             │  │ (t3.medium)                 ││ │
│  │  │ • Node.js 20 + Express │◄─┤ • PostgreSQL 16             ││ │
│  │  │ • PM2 Process Manager  │  │ • Encrypted gp3 Volume      ││ │
│  │  │ • REST API             │  │ • Private Network Only      ││ │
│  │  └────────────────────────┘  └─────────────────────────────┘│ │
│  │          │                                                  │ │
│  └──────────┼──────────────────────────────────────────────────┘ │
│             ▼                                                    │
│      NAT Gateway → Internet Gateway                              │
└──────────────────────────────────────────────────────────────────┘
```

**Key Architectural Decisions:**

- **Separation of Concerns**: Distinct tiers for presentation, business logic, and data persistence
- **Network Segmentation**: Public subnet for frontend, private subnets for backend/database
- **Zero-Trust Access**: AWS Systems Manager Session Manager eliminates SSH key exposure
- **State Immutability**: Remote state in encrypted S3 backend with locking support
- **Automated TLS**: Let's Encrypt certificate provisioning via Certbot (HTTP-01 challenge)

---

## Project Highlights

**Why This Repository Demonstrates Senior-Level Competency:**

✅ **Multi-Tier Architecture** — Proper separation of web, application, and data layers  
✅ **Network Isolation** — Public/private subnet strategy with controlled traffic flow  
✅ **Zero Bastion Design** — AWS SSM Session Manager for secure, auditable access  
✅ **Production DNS** — Route53 A records with Elastic IP for stable addressing  
✅ **Automated TLS** — Let's Encrypt integration for production-grade HTTPS  
✅ **Infrastructure as Code** — 100% Terraform, no manual AWS Console clicks  
✅ **Modular Design** — Reusable modules (VPC, IAM, EC2, Security Groups, Route53)  
✅ **Remote State Management** — S3 backend with encryption and versioning  
✅ **IAM Least Privilege** — Scoped instance profiles (SSM-only for backend/database)  
✅ **Defense in Depth** — Security groups implement tiered access control  
✅ **Encrypted Storage** — All EBS volumes use encrypted gp3 with KMS  
✅ **Dependency Orchestration** — Explicit wait gates ensure ordered provisioning  
✅ **Idempotent Scripts** — User data scripts safely re-runnable via SSM  
✅ **Health Checks** — Backend waits for database, frontend waits for backend  
✅ **Production Process Management** — PM2 with auto-restart for backend resilience  

---

## Repository Structure

```
terraform_front_end_public/
├── main.tf                      # Root module orchestration
├── provider.tf                  # AWS provider configuration
├── backend.tf                   # S3 remote state backend
├── variables.tf                 # Input variable declarations
├── outputs.tf                   # Infrastructure outputs (IPs, URLs, commands)
├── terraform.tfvars             # Environment-specific values (gitignored)
├── terraform.tfvars.example     # Template for required variables
│
├── modules/
│   ├── vpc/
│   │   ├── main.tf             # VPC, subnets, IGW, NAT GW, route tables
│   │   ├── outputs.tf          # VPC ID, subnet IDs, NAT IP
│   │   └── variables.tf        # VPC configuration inputs
│   │
│   ├── iam/
│   │   ├── main.tf             # IAM roles + instance profiles (SSM + Route53)
│   │   ├── outputs.tf          # Instance profile ARNs
│   │   └── variables.tf        # IAM policy scoping
│   │
│   ├── security_groups/
│   │   ├── main.tf             # SGs for frontend, backend, database
│   │   ├── outputs.tf          # Security group IDs
│   │   └── variables.tf        # Port and CIDR configurations
│   │
│   ├── ec2/
│   │   ├── main.tf             # EC2 instances, EIP, user_data orchestration
│   │   ├── outputs.tf          # Instance IDs, IPs, connection commands
│   │   └── variables.tf        # Instance types, AMI ID, key pair
│   │
│   └── route53/
│       ├── main.tf             # A record pointing to frontend EIP
│       ├── outputs.tf          # FQDN of created DNS record
│       └── variables.tf        # Domain and hosted zone configuration
│
├── scripts/
│   ├── frontend_setup.sh       # React build + Nginx + Certbot install
│   ├── backend_setup.sh        # Node.js + Express + PM2 setup
│   ├── database_setup.sh       # PostgreSQL install + schema migration
│   └── generate_certificate.sh # Let's Encrypt cert generation (SSM-triggered)
│
└── README.md                    # This file
```

---

## Infrastructure Components

### Networking Layer

| Component | Configuration | Purpose |
|-----------|--------------|---------|
| **VPC** | `10.0.0.0/16` | Isolated network boundary for all resources |
| **Public Subnet** | `10.0.1.0/24` | Hosts frontend server with direct internet access |
| **Private Subnet** | `10.0.101.0/24` | Hosts backend + database (no direct internet access) |
| **Internet Gateway** | Attached to VPC | Enables outbound/inbound internet for public subnet |
| **NAT Gateway** | In public subnet with EIP | Provides internet access for private subnet instances |
| **Route Tables** | Public (0.0.0.0/0 → IGW)<br>Private (0.0.0.0/0 → NAT GW) | Traffic routing logic |

### Compute Layer

| Server | Type | Subnet | Storage | Role |
|--------|------|--------|---------|------|
| **Frontend** | `t3.small` (2 vCPU, 2 GB) | Public | 30 GB gp3 encrypted | Nginx reverse proxy + React SPA |
| **Backend** | `t3.small` (2 vCPU, 2 GB) | Private | 30 GB gp3 encrypted | Node.js API + PM2 process manager |
| **Database** | `t3.medium` (2 vCPU, 4 GB) | Private | 30 GB gp3 encrypted | PostgreSQL 16 database |

### Security Layer

| Security Group | Ingress Rules | Egress | Notes |
|----------------|---------------|--------|-------|
| **frontend-sg** | SSH (your IP only)<br>HTTP 80 (0.0.0.0/0)<br>HTTPS 443 (0.0.0.0/0) | All | Restricted SSH; public HTTP/HTTPS |
| **backend-sg** | Port 3000 (frontend-sg only)<br>SSH (frontend-sg only) | All via NAT GW | Backend only accessible from frontend |
| **database-sg** | Port 5432 (backend-sg only)<br>SSH (frontend-sg only) | All via NAT GW | Database only accessible from backend |

**Security Principle**: Each tier can only communicate with its adjacent tier, implementing defense-in-depth.

### IAM & Access Management

| Role | Permissions | Attached To | Purpose |
|------|-------------|-------------|---------|
| **frontend-instance-role** | `AmazonSSMManagedInstanceCore`<br>`Route53 read-only (unused)` | Frontend EC2 | SSM access for maintenance |
| **backend-instance-role** | `AmazonSSMManagedInstanceCore` | Backend EC2 | SSM access only |
| **database-instance-role** | `AmazonSSMManagedInstanceCore` | Database EC2 | SSM access only |

**Why No SSH Keys?** AWS Systems Manager Session Manager provides browser-based terminal access with full audit logging, eliminating key management overhead.

### DNS & TLS

- **Route53 A Record**: Points `domain.com` to frontend Elastic IP
- **Let's Encrypt Certificate**: HTTP-01 challenge via Certbot, auto-renewal configured
- **Certificate Generation**: Triggered via AWS SSM Run Command after DNS propagation

---

## Deployment Workflow

### Prerequisites

1. **AWS Account** with programmatic access configured
2. **Terraform** 1.0+ installed ([download](https://www.terraform.io/downloads))
3. **AWS CLI** configured with a named profile
4. **Route53 Hosted Zone** for your domain
5. **S3 Bucket** for remote state storage
6. **EC2 Key Pair** created in target region (emergency fallback only)

### Step 1: Clone and Configure

```bash
git clone https://github.com/yourusername/terraform-3-tier-different-servers.git
cd terraform-3-tier-different-servers/terraform_front_end_public
```

### Step 2: Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your environment-specific values:

```hcl
aws_region              = "ap-south-1"
aws_profile             = "your-profile-name"
project_name            = "bmi-tracker"
environment             = "production"
domain_name             = "app.yourdomain.com"
hosted_zone_name        = "yourdomain.com"
ssh_allowed_cidrs       = ["203.0.113.5/32"]  # Your IP only
db_password             = "change-me-strong-password"
```

### Step 3: Configure Remote State Backend

Create `backend-config.tfbackend` (gitignored):

```hcl
bucket  = "your-terraform-state-bucket"
profile = "your-aws-profile"
```

### Step 4: Initialize Terraform

```bash
terraform init -backend-config=backend-config.tfbackend
```

This downloads provider plugins and configures S3 backend for remote state.

### Step 5: Plan Infrastructure Changes

```bash
terraform plan -out=tfplan
```

Review the execution plan carefully. Expected resources: ~35-40 resources.

### Step 6: Provision Infrastructure

```bash
terraform apply tfplan
```

**Provisioning Timeline** (approximate):
- VPC + Networking: 2-3 minutes
- NAT Gateway: 1-2 minutes
- EC2 instances: 3-4 minutes
- User data execution: 5-8 minutes
- Total: ~12-15 minutes

**Why the Wait?** The infrastructure includes:
1. Database provisioning → PostgreSQL install + schema setup
2. Backend provisioning → waits for database health check
3. Frontend provisioning → waits for backend health check
4. DNS propagation validation before certificate generation

### Step 7: Generate TLS Certificate

After Terraform completes, the DNS record must propagate (5-60 minutes). Then trigger certificate generation:

```bash
# Option 1: Use AWS Console → Systems Manager → Run Command
# Select: AWS-RunShellScript
# Target: frontend instance
# Command: sudo bash /usr/local/bin/generate-certificate.sh

# Option 2: Use AWS CLI
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Name,Values=bmi-tracker-frontend" \
  --parameters 'commands=["sudo bash /usr/local/bin/generate-certificate.sh"]' \
  --profile your-profile-name \
  --region ap-south-1
```

### Step 8: Verify Deployment

```bash
# Get outputs
terraform output

# Access application
https://app.yourdomain.com
```

### Step 9: Destroy Infrastructure (When Done)

```bash
terraform destroy
```

**Warning**: This permanently deletes all resources. Ensure data is backed up.

---

## Remote State Management

This project uses **S3 backend** with the following configuration:

```hcl
terraform {
  backend "s3" {
    bucket  = "your-state-bucket"
    key     = "fpub-trfm/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}
```

**Benefits:**

- **Team Collaboration**: Shared state accessible by multiple operators
- **State Locking**: Prevents concurrent modifications (requires DynamoDB table)
- **Versioning**: S3 versioning enables state rollback
- **Encryption**: State file encrypted at rest with AES-256

**Best Practice**: Enable S3 versioning and MFA delete on the state bucket.

---

## Security Best Practices

This infrastructure implements multiple layers of security controls:

### Network Security

✅ **No Bastion Host** — AWS SSM Session Manager provides secure, auditable access without exposing SSH  
✅ **Private Subnet Isolation** — Backend and database have no direct internet access  
✅ **NAT Gateway** — Private instances access internet via single controlled egress point  
✅ **Security Group Chaining** — Tiered access: Internet → Frontend → Backend → Database  

### Access Control

✅ **IAM Least Privilege** — Instance roles scoped to minimum required permissions  
✅ **No Hardcoded Credentials** — Sensitive values passed via Terraform variables  
✅ **SSH Key Not Required** — SSM Session Manager eliminates SSH key management  
✅ **Restricted CIDR** — SSH fallback limited to operator IP only  

### Data Protection

✅ **Encrypted EBS Volumes** — All disks encrypted with AWS-managed KMS keys  
✅ **TLS in Transit** — HTTPS enforced via Let's Encrypt certificates  
✅ **Database Access Control** — PostgreSQL listens on private IP only  

### Operational Security

✅ **Audit Logging** — SSM Session Manager logs all terminal sessions to CloudWatch  
✅ **Immutable Infrastructure** — Changes applied via Terraform, not manual edits  
✅ **Automated Provisioning** — User data scripts eliminate configuration drift  

---

## Cost Optimization

### Monthly Cost Estimate (ap-south-1)

| Resource | Specification | Monthly Cost (USD) |
|----------|---------------|-------------------|
| Frontend EC2 (t3.small) | 2 vCPU, 2 GB RAM, 30 GB gp3 | ~$18 |
| Backend EC2 (t3.small) | 2 vCPU, 2 GB RAM, 30 GB gp3 | ~$18 |
| Database EC2 (t3.medium) | 2 vCPU, 4 GB RAM, 30 GB gp3 | ~$36 |
| NAT Gateway | 1 instance + data transfer (~10 GB) | ~$35 |
| Elastic IP | 1 EIP attached | $0 |
| Route53 | 1 hosted zone + queries | ~$0.50 |
| **Total** | | **~$107.50/month** |

### Why These Instance Sizes?

- **Frontend (t3.small)**: Nginx is lightweight; React is served as static files
- **Backend (t3.small)**: Node.js Express API handles moderate traffic efficiently
- **Database (t3.medium)**: PostgreSQL benefits from extra memory for query caching

### Cost Reduction Strategies

1. **Stop Non-Production Hours**: Use `aws ec2 stop-instances` during off-hours (~50% savings)
2. **Reserved Instances**: 1-year commitment saves ~30-40% for production workloads
3. **NAT Gateway Alternatives**: Consider NAT instance on t3.micro for dev/test (~$12 vs $35)
4. **Single AZ**: Remove multi-AZ redundancy for non-critical environments
5. **EBS Optimization**: Reduce volume sizes for development (20 GB vs 30 GB)

**RDS Comparison**: Managed RDS PostgreSQL db.t3.medium costs ~$70/month vs $36 for EC2 self-managed. EC2 chosen for cost efficiency and learning value.

---

## Lessons Learned

**Senior Engineering Insights from Building This Infrastructure:**

### Why AWS Systems Manager Over Bastion Hosts?

Traditional bastion host architecture introduces:
- **Security Risk**: SSH keys must be distributed and rotated
- **Single Point of Failure**: Bastion downtime blocks all access
- **Cost**: Additional EC2 instance + elastic IP (~$20/month)
- **Audit Gaps**: SSH sessions not logged by default

SSM Session Manager provides:
- **Zero SSH Keys**: IAM-based authentication with MFA support
- **Full Audit Trail**: Every command logged to CloudWatch
- **No Additional Cost**: Built into instance IAM role
- **Browser Access**: No VPN or SSH client required

**Verdict**: SSM is the modern best practice for production infrastructure.

### Why EC2 PostgreSQL Instead of RDS?

This project intentionally uses self-managed PostgreSQL to demonstrate:
- **Infrastructure Provisioning**: Complete database setup via user_data
- **Cost Awareness**: ~50% cost savings for learning/portfolio projects
- **Full Control**: Schema migrations, extensions, custom configurations

**Production Recommendation**: Use RDS for automated backups, multi-AZ, and managed patches.

### Why Modular Terraform Matters

Monolithic `main.tf` files become unmaintainable beyond ~500 lines. Modules provide:
- **Reusability**: VPC module works across multiple projects
- **Testability**: Isolate and test individual components
- **Team Collaboration**: Multiple engineers can work in parallel
- **Version Control**: Module versioning enables gradual upgrades

**Pattern**: Each module should represent a logical infrastructure boundary (network, compute, security, etc.).

### Why Remote State Is Critical

Local `terraform.tfstate` files cause:
- **Collaboration Issues**: State conflicts when multiple operators apply changes
- **Data Loss Risk**: Deleted workstation = lost state = orphaned resources
- **Security Exposure**: State contains sensitive data (passwords, IPs)

S3 backend with DynamoDB locking solves all three problems.

**Non-Negotiable**: Always use remote state for team projects and production.

---

## Future Improvements

**Enhancements for Production Scale:**

### High Availability

- [ ] **Application Load Balancer (ALB)** — Distribute traffic across multiple frontend instances
- [ ] **Auto Scaling Groups** — Automatically scale frontend/backend based on CPU/memory
- [ ] **Multi-AZ Deployment** — Spread instances across 3 availability zones
- [ ] **RDS PostgreSQL** — Migrate to managed database with automated backups

### CI/CD Pipeline

- [ ] **GitHub Actions Workflow** — Automated `terraform plan` on PRs
- [ ] **Atlantis Integration** — GitOps-based infrastructure approvals
- [ ] **Blue/Green Deployment** — Zero-downtime application updates
- [ ] **Terraform Cloud** — Remote execution with policy-as-code

### Observability

- [ ] **CloudWatch Dashboards** — Real-time metrics (CPU, memory, disk, network)
- [ ] **Application Performance Monitoring** — Integrate New Relic or Datadog
- [ ] **Centralized Logging** — Ship application logs to CloudWatch Logs or ELK
- [ ] **Uptime Monitoring** — PagerDuty alerts for service degradation

### Security Hardening

- [ ] **AWS WAF** — Protect against OWASP Top 10 vulnerabilities
- [ ] **GuardDuty** — Threat detection for EC2 and VPC traffic
- [ ] **Secrets Manager** — Rotate database credentials automatically
- [ ] **VPC Flow Logs** — Network traffic analysis and anomaly detection

### Container Migration Path

- [ ] **Dockerize Application** — Frontend, backend, database as containers
- [ ] **ECS Fargate** — Serverless container orchestration
- [ ] **EKS (Kubernetes)** — Enterprise-grade container management
- [ ] **Service Mesh (Istio)** — Advanced traffic management and security

---

## Troubleshooting

### Database Server Issues

**Connect to Database Server:**
```bash
aws ssm start-session --target $(terraform output -raw database_instance_id)
```

**Diagnostic Commands:**
```bash
# Check initialization log
sudo tail -100 /var/log/user-data.log

# Verify PostgreSQL service is running
sudo systemctl status postgresql

# Check if tables were created
sudo -u postgres psql -d bmidb -c "\dt"

# Verify PostgreSQL is listening on port 5432
ss -tlnp | grep 5432

# Test database connectivity from localhost
sudo -u postgres psql -d bmidb -c "SELECT version();"
```

**Common Issues:**

| Problem | Solution |
|---------|----------|
| PostgreSQL not running | `sudo systemctl start postgresql` |
| Tables missing | Re-run migrations from backend server |
| Port not listening | Check `postgresql.conf` for `listen_addresses` |
| Connection refused | Verify `pg_hba.conf` allows VPC CIDR |

---

### Backend Server Issues

**Connect to Backend Server:**
```bash
aws ssm start-session --target $(terraform output -raw backend_instance_id)
```

**Diagnostic Commands:**
```bash
# Check initialization log
sudo tail -f /var/log/user-data.log

# Verify PM2 process is running
pm2 list

# Check application logs
pm2 logs bmi-backend --lines 50

# Test health endpoint locally
curl -sf http://localhost:3000/health

# Test database connectivity
nc -zv $(terraform output -raw database_private_ip) 5432

# Check Node.js version
node --version
npm --version
```

**Common Issues:**

| Problem | Solution |
|---------|----------|
| PM2 process not running | `pm2 start ecosystem.config.js` |
| Database connection fails | Verify database server is running and accessible |
| Health endpoint returns error | Check `pm2 logs` for application errors |
| Port 3000 not listening | Ensure backend started successfully |

---

### Frontend Server Issues

**Connect to Frontend Server:**
```bash
aws ssm start-session --target $(terraform output -raw frontend_instance_id)
```

**Diagnostic Commands:**
```bash
# Check initialization log
sudo tail -f /var/log/user-data.log

# Verify Nginx service is running
sudo systemctl status nginx

# Test Nginx serving locally
curl -sf http://localhost/health

# Check if certificate script exists
ls -la /usr/local/bin/generate-certificate.sh

# View certificate generation log (after SSM triggers it)
cat /var/log/certbot-generate.log

# Check if certificate was issued
sudo certbot certificates

# Test backend connectivity from frontend
curl -sf http://$(terraform output -raw backend_private_ip):3000/health

# Verify Nginx configuration syntax
sudo nginx -t
```

**Common Issues:**

| Problem | Solution |
|---------|----------|
| Nginx not running | `sudo systemctl start nginx` |
| 502 Bad Gateway | Backend server not reachable; verify security groups |
| Certificate not issued | Run `/usr/local/bin/generate-certificate.sh` via SSM |
| Static files not loading | Check `/var/www/html` directory permissions |

---

### Certificate Generation Issues

**Symptom**: Let's Encrypt challenge times out

**Diagnostic Steps:**
```bash
# Verify DNS propagation (run from local machine)
dig +short app.yourdomain.com

# Check if A record points to frontend Elastic IP
terraform output frontend_public_ip

# Ensure port 80 is open (required for HTTP-01 challenge)
aws ec2 describe-security-groups --group-ids $(terraform output -raw frontend_sg_id)

# Connect to frontend and manually test certificate generation
aws ssm start-session --target $(terraform output -raw frontend_instance_id)
sudo bash /usr/local/bin/generate-certificate.sh
```

**Common Certificate Issues:**

| Problem | Solution |
|---------|----------|
| DNS not propagated | Wait 5-60 minutes after `terraform apply` |
| Port 80 blocked | Verify security group allows 0.0.0.0/0 on port 80 |
| Domain mismatch | Ensure Route53 record matches certificate domain |
| Rate limit hit | Let's Encrypt limits 5 certs/week; wait or use staging |

---

## Technical Stack Summary

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Infrastructure** | Terraform | 1.x | Declarative infrastructure provisioning |
| **Cloud Provider** | AWS | - | Compute, networking, DNS, IAM |
| **Operating System** | Ubuntu Server | 24.04 LTS | Long-term support, wide compatibility |
| **Frontend Framework** | React | 18 | Modern SPA with component architecture |
| **Build Tool** | Vite | Latest | Fast HMR, optimized production builds |
| **Web Server** | Nginx | 1.24 | Reverse proxy, TLS termination, static files |
| **Backend Runtime** | Node.js | 20.x LTS | Event-driven JavaScript runtime |
| **API Framework** | Express | 4.x | Minimal, flexible REST API framework |
| **Process Manager** | PM2 | Latest | Production process management, auto-restart |
| **Database** | PostgreSQL | 16 | ACID-compliant relational database |
| **TLS Certificates** | Let's Encrypt | - | Free, automated SSL/TLS certificates |
| **Certificate Tool** | Certbot | Latest | ACME client for Let's Encrypt |
| **DNS** | Route53 | - | Authoritative DNS with low latency |
| **Access Management** | SSM Session Manager | - | Secure shell access without SSH keys |

---

## Contributing

This is a portfolio project demonstrating DevOps best practices. Contributions, suggestions, and forks are welcome.

**Areas for Community Input:**

- Multi-region deployment patterns
- Kubernetes migration strategies
- Cost optimization techniques
- Security hardening recommendations

---

## License

This project is provided as-is for educational and portfolio purposes.

---

---

*MD Sarowar Alam*  
Lead DevOps Engineer, WPP Production
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/

---
