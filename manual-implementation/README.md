# BMI Health Tracker - Complete Manual Deployment Guide

**Step-by-step guide to deploy BMI Health Tracker on AWS from scratch to production HTTPS access.**

This guide covers EVERYTHING you need - from creating VPC subnets to browsing your application at `https://bmi.ostaddevops.click`

## 📋 What You'll Build

By following this guide, you'll deploy a complete 3-tier application with:
- ✅ Isolated private subnets for database, backend, and frontend servers
- ✅ Properly configured security groups with specific port access
- ✅ Application deployed on 3 EC2 instances (PostgreSQL, Node.js, React/Nginx)
- ✅ SSL/TLS certificate from Let's Encrypt
- ✅ Application Load Balancer with HTTP→HTTPS redirect
- ✅ DNS configured in Route53
- ✅ Production-ready application accessible via HTTPS

**Total Time**: 2-3 hours (includes detailed explanations)

---

## 🎯 Architecture

```
                          Internet (0.0.0.0/0)
                                  │
                                  │ HTTPS/HTTP
                                  ↓
                    ┌─────────────────────────┐
                    │   Route53 DNS Record    │
                    │ bmi.ostaddevops.click   │
                    └─────────────────────────┘
                                  │
                                  ↓
                    ┌─────────────────────────┐
                    │ Application Load Bal.   │
                    │ (Public Subnets)        │
                    │ Port 80 → 443 (redirect)│
                    │ Port 443 (HTTPS)        │
                    └─────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │      Private Subnets      │
                    │                           │
                    │  ┌─────────────────────┐  │
                    │  │ Frontend Server     │  │
                    │  │ Nginx + React       │  │
                    │  │ 10.0.3.X:80         │  │
                    │  └──────────┬──────────┘  │
                    │             │             │
                    │             ↓             │
                    │  ┌─────────────────────┐  │
                    │  │ Backend Server      │  │
                    │  │ Node.js + PM2       │  │
                    │  │ 10.0.2.X:3000       │  │
                    │  └──────────┬──────────┘  │
                    │             │             │
                    │             ↓             │
                    │  ┌─────────────────────┐  │
                    │  │ Database Server     │  │
                    │  │ PostgreSQL 15       │  │
                    │  │ 10.0.1.X:5432       │  │
                    │  └─────────────────────┘  │
                    │                           │
                    └───────────────────────────┘

Flow:
1. User → Route53 → ALB (HTTPS:443)
2. ALB → Frontend (HTTP:80)
3. Frontend → Backend (HTTP:3000)
4. Backend → Database (PostgreSQL:5432)
```

---

## 📦 Prerequisites

### Required
- ✅ AWS Account with admin access
- ✅ VPC with private subnets (or use default VPC)
- ✅ Domain name managed by Route53 (e.g., ostaddevops.click)
- ✅ SSH key pair downloaded (`.pem` file)
- ✅ Local machine with AWS CLI installed
- ✅ SSH client (terminal on Linux/Mac, PuTTY on Windows)

### What You'll Create
- 3 EC2 instances (Ubuntu 22.04 LTS)
- 4 Security Groups
- 1 IAM Role
- 1 Application Load Balancer
- 1 Target Group
- 1 Route53 A record
- 1 SSL Certificate (Let's Encrypt)

---

## 🚀 Step-by-Step Deployment

---

## STEP 1: Create Private Subnets (10 minutes)

We need 3 private subnets (for database, backend, frontend) and 2 public subnets (for ALB in different AZs).

### 1.1 Navigate to VPC

1. Open **AWS Console** → Search for **VPC**
2. Select **VPC Dashboard**
3. Click **Subnets** in left sidebar
4. Note your VPC ID (you'll use it in all steps)

### 1.2 Create Private Subnet - Database Tier

1. Click **Create subnet**
2. Fill in details:
   ```
   VPC ID: vpc-xxxxxx (select your VPC)
   Subnet name: bmi-database-private
   Availability Zone: ap-south-1a
   IPv4 CIDR block: 10.0.1.0/24
   ```
3. Click **Create subnet**

### 1.3 Create Private Subnet - Backend Tier

1. Click **Create subnet**
2. Fill in details:
   ```
   VPC ID: [same VPC]
   Subnet name: bmi-backend-private
   Availability Zone: ap-south-1a
   IPv4 CIDR block: 10.0.2.0/24
   ```
3. Click **Create subnet**

### 1.4 Create Private Subnet - Frontend Tier

1. Click **Create subnet**
2. Fill in details:
   ```
   VPC ID: [same VPC]
   Subnet name: bmi-frontend-private
   Availability Zone: ap-south-1a
   IPv4 CIDR block: 10.0.3.0/24
   ```
3. Click **Create subnet**

### 1.5 Create Public Subnets for ALB (Required: 2 subnets in different AZs)

**Public Subnet 1:**
1. Click **Create subnet**
2. Fill in:
   ```
   VPC ID: [same VPC]
   Subnet name: bmi-alb-public-1
   Availability Zone: ap-south-1a
   IPv4 CIDR block: 10.0.101.0/24
   ```
3. Click **Create subnet**

**Public Subnet 2:**
1. Click **Create subnet**
2. Fill in:
   ```
   VPC ID: [same VPC]
   Subnet name: bmi-alb-public-2
   Availability Zone: ap-south-1b  ⚠️ Different AZ!
   IPv4 CIDR block: 10.0.102.0/24
   ```
3. Click **Create subnet**

### 1.6 Enable Auto-Assign Public IP for Public Subnets

For EACH public subnet (`bmi-alb-public-1` and `bmi-alb-public-2`):

1. Select the subnet
2. Click **Actions** → **Edit subnet settings**
3. Check ✅ **Enable auto-assign public IPv4 address**
4. Click **Save**

### 1.7 Verify Route Tables

1. Click **Route Tables** in left sidebar
2. Find route table associated with public subnets
3. Click **Routes** tab
4. Verify route exists: `0.0.0.0/0` → `igw-xxxxx` (Internet Gateway)
5. If missing, click **Edit routes** → **Add route**:
   ```
   Destination: 0.0.0.0/0
   Target: Internet Gateway (select your igw)
   ```
6. Click **Save changes**

### 1.8 Save Subnet IDs (You'll need these later!)

```bash
DATABASE_SUBNET_ID="subnet-xxxxxxxx"   # bmi-database-private
BACKEND_SUBNET_ID="subnet-yyyyyyyy"    # bmi-backend-private
FRONTEND_SUBNET_ID="subnet-zzzzzzzz"   # bmi-frontend-private
PUBLIC_SUBNET_1_ID="subnet-aaaaaaaa"   # bmi-alb-public-1
PUBLIC_SUBNET_2_ID="subnet-bbbbbbbb"   # bmi-alb-public-2
```

✅ **Checkpoint**: 5 subnets created and configured

---

## STEP 2: Create Security Groups with Specific Ports (15 minutes)

### 2.1 Create Database Security Group

1. Go to **AWS Console** → **VPC** → **Security Groups**
2. Click **Create security group**

**Basic details:**
```
Security group name: bmi-database-sg
Description: PostgreSQL database for BMI app
VPC: [Select your VPC]
```

**Inbound rules** (Click **Add rule** for each):

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| PostgreSQL | TCP | 5432 | bmi-backend-sg | Backend API access |
| SSH | TCP | 22 | My IP | Admin SSH access |

**Outbound rules:** (Leave default - All traffic)

3. Click **Create security group**
4. **Save Security Group ID**: `sg-database-xxxxx`

### 2.2 Create Backend Security Group

1. Click **Create security group**

**Basic details:**
```
Security group name: bmi-backend-sg
Description: Node.js backend API for BMI app
VPC: [Select your VPC]
```

**Inbound rules:**

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| Custom TCP | TCP | 3000 | bmi-frontend-sg | Frontend API calls |
| SSH | TCP | 22 | My IP | Admin SSH access |

3. Click **Create security group**
4. **Save Security Group ID**: `sg-backend-xxxxx`

### 2.3 Create Frontend Security Group

1. Click **Create security group**

**Basic details:**
```
Security group name: bmi-frontend-sg
Description: Nginx web server for BMI app
VPC: [Select your VPC]
```

**Inbound rules:**

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| HTTP | TCP | 80 | bmi-alb-sg | ALB health checks & traffic |
| SSH | TCP | 22 | My IP | Admin SSH access |

3. Click **Create security group**
4. **Save Security Group ID**: `sg-frontend-xxxxx`

### 2.4 Create ALB Security Group

1. Click **Create security group**

**Basic details:**
```
Security group name: bmi-alb-sg
Description: Application Load Balancer for BMI app
VPC: [Select your VPC]
```

**Inbound rules:**

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| HTTP | TCP | 80 | 0.0.0.0/0 | HTTP from internet |
| HTTPS | TCP | 443 | 0.0.0.0/0 | HTTPS from internet |

3. Click **Create security group**
4. **Save Security Group ID**: `sg-alb-xxxxx`

### 2.5 Important: Update Security Group References

After creating all security groups, **UPDATE the sources** that reference other security groups:

**Database SG:**
1. Select **bmi-database-sg**
2. **Inbound rules** tab → **Edit inbound rules**
3. For PostgreSQL rule, change Source from text to: **bmi-backend-sg** (select from dropdown)
4. **Save rules**

**Backend SG:**
1. Select **bmi-backend-sg**
2. **Inbound rules** tab → **Edit inbound rules**
3. For port 3000 rule, change Source to: **bmi-frontend-sg**
4. **Save rules**

**Frontend SG:**
1. Select **bmi-frontend-sg**
2. **Inbound rules** tab → **Edit inbound rules**
3. For HTTP rule, change Source to: **bmi-alb-sg**
4. **Save rules**

✅ **Checkpoint**: 4 security groups created with proper port access

---

## STEP 3: Create IAM Role for SSL Certificate Management (5 minutes)

The frontend server needs AWS permissions to validate domain ownership (Route53) and import SSL certificates (ACM).

### 3.1 Create IAM Policy

1. Go to **AWS Console** → **IAM** → **Policies**
2. Click **Create policy**
3. Click **JSON** tab
4. Paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Route53Access",
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetChange"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Route53RecordManagement",
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Sid": "ACMCertificateManagement",
      "Effect": "Allow",
      "Action": [
        "acm:ImportCertificate",
        "acm:AddTagsToCertificate",
        "acm:ListCertificates",
        "acm:DescribeCertificate"
      ],
      "Resource": "*"
    }
  ]
}
```

5. Click **Next**
6. Policy name: `bmi-certbot-policy`
7. Description: `Allows EC2 to manage Route53 records and ACM certificates for Let's Encrypt`
8. Click **Create policy**

### 3.2 Create IAM Role

1. Go to **IAM** → **Roles**
2. Click **Create role**
3. **Trusted entity type**: AWS service
4. **Use case**: EC2
5. Click **Next**
6. Search and select: **bmi-certbot-policy**
7. Click **Next**
8. Role name: `bmi-certbot-role`
9. Description: `EC2 role for Let's Encrypt certificate management`
10. Click **Create role**

✅ **Checkpoint**: IAM role `bmi-certbot-role` created

Go to: **AWS Console → VPC → Security Groups → Create Security Group**

**1.1 Database Security Group**
```
Name: bmi-database-sg
Description: Security group for BMI database
VPC: Select your VPC

Inbound Rules:
- Type: PostgreSQL | Port: 5432 | Source: bmi-backend-sg
- Type: SSH | Port: 22 | Source: Your IP
```

**1.2 Backend Security Group**
```
Name: bmi-backend-sg
Description: Security group for BMI backend API
VPC: Select your VPC

Inbound Rules:
- Type: Custom TCP | Port: 3000 | Source: bmi-frontend-sg
- Type: SSH | Port: 22 | Source: Your IP
```

**1.3 Frontend Security Group**
```
Name: bmi-frontend-sg
Description: Security group for BMI frontend web server
VPC: Select your VPC

Inbound Rules:
- Type: HTTP | Port: 80 | Source: bmi-alb-sg
- Type: SSH | Port: 22 | Source: Your IP
```

**1.4 ALB Security Group**
```
Name: bmi-alb-sg
Description: Security group for Application Load Balancer
VPC: Select your VPC

Inbound Rules:
- Type: HTTP | Port: 80 | Source: 0.0.0.0/0
- Type: HTTPS | Port: 443 | Source: 0.0.0.0/0
```

✅ **Checkpoint**: 4 security groups created

---

#### Step 2: Create IAM Role for Frontend (5 minutes)

**2.1 Create Policy**

Go to: **AWS Console → IAM → Policies → Create Policy → JSON**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetChange",
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "acm:ImportCertificate",
        "acm:AddTagsToCertificate",
        "acm:ListCertificates",
        "acm:DescribeCertificate"
      ],
      "Resource": "*"
    }
  ]
}
```

- Policy name: `bmi-certbot-policy`
- Click **Create policy**

**2.2 Create Role**

Go to: **AWS Console → IAM → Roles → Create Role**

```
Trusted entity type: AWS service
Use case: EC2
Role name: bmi-certbot-role
Attach policy: bmi-certbot-policy
```

Click **Create role**

✅ **Checkpoint**: IAM role `bmi-certbot-role` created

---

## STEP 4: Launch EC2 Instances in Private Subnets (20 minutes)

We'll launch 3 Ubuntu 22.04 LTS instances, one for each application tier.

### 4.1 Launch Database Server

1. Go to **AWS Console** → **EC2** → **Instances**
2. Click **Launch instances**

**Step 1: Name and tags**
```
Name: bmi-database
```

**Step 2: Application and OS Images (AMI)**
```
Quick Start: Ubuntu
AMI: Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
Architecture: 64-bit (x86)
```

**Step 3: Instance type**
```
Instance type: t3.micro (1 vCPU, 1 GB RAM)
```
*For production, consider t3.small or larger*

**Step 4: Key pair**
```
Key pair name: [Select your existing key pair]
```
*Example: `sarowar-ostad-mumbai`*

**Step 5: Network settings** (Click **Edit**)
```
VPC: [Select your VPC]
Subnet: bmi-database-private (10.0.1.0/24)
Auto-assign public IP: Disable ⚠️ Important!
Firewall (security groups): Select existing security group
  └─ Select: bmi-database-sg
```

**Step 6: Configure storage**
```
1x 20 GiB gp3
Root volume: /dev/sda1
```

**Step 7: Advanced details** (Scroll down)
```
IAM instance profile: None (database doesn't need AWS access)
```

3. Click **Launch instance**
4. Wait for instance state: **Running**
5. **Save Private IP Address**: Example: `10.0.1.45`

### 4.2 Launch Backend Server

1. Click **Launch instances**

**Name:** `bmi-backend`

**AMI:** Ubuntu Server 22.04 LTS

**Instance type:** `t3.micro`

**Key pair:** [Your key pair]

**Network settings:**
```
VPC: [Your VPC]
Subnet: bmi-backend-private (10.0.2.0/24)
Auto-assign public IP: Disable
Security group: bmi-backend-sg
```

**Storage:** `10 GiB gp3`

**IAM instance profile:** None

2. Click **Launch instance**
3. Wait for state: **Running**
4. **Save Private IP Address**: Example: `10.0.2.78`

### 4.3 Launch Frontend Server

1. Click **Launch instances**

**Name:** `bmi-frontend`

**AMI:** Ubuntu Server 22.04 LTS

**Instance type:** `t3.micro`

**Key pair:** [Your key pair]

**Network settings:**
```
VPC: [Your VPC]
Subnet: bmi-frontend-private (10.0.3.0/24)
Auto-assign public IP: Disable
Security group: bmi-frontend-sg
```

**Storage:** `10 GiB gp3`

**Advanced details → IAM instance profile:**
```
IAM instance profile: bmi-certbot-role  ⚠️ Important for SSL!
```

2. Click **Launch instance**
3. Wait for state: **Running**
4. **Save Private IP Address**: Example: `10.0.3.92`

### 4.4 Verify Instance Status

1. Go to **EC2** → **Instances**
2. You should see 3 instances running:
   ```
   ✅ bmi-database   | t3.micro | 10.0.1.x  | Running
   ✅ bmi-backend    | t3.micro | 10.0.2.x  | Running
   ✅ bmi-frontend   | t3.micro | 10.0.3.x  | Running
   ```

### 4.5 Save Instance Information

```bash
# Copy these values - you'll need them!
DATABASE_IP="10.0.1.45"      # Your database private IP
BACKEND_IP="10.0.2.78"       # Your backend private IP
FRONTEND_IP="10.0.3.92"      # Your frontend private IP

DATABASE_INSTANCE_ID="i-0eccbd076d15b68cf"
BACKEND_INSTANCE_ID="i-008c839f01e89a908"
FRONTEND_INSTANCE_ID="i-0eb6076c9707d23c4"
```

✅ **Checkpoint**: 3 EC2 instances running in private subnets

---

## STEP 5: Deploy Database Server (15 minutes)

### 5.1 Connect to Database Instance

Since the instance is in a private subnet, you need either:
- **Option A**: Bastion host in public subnet
- **Option B**: VPN connection to VPC
- **Option C**: AWS Systems Manager Session Manager

**Using Bastion Host:**
```bash
# SSH to bastion (if you have one)
ssh -i your-key.pem ubuntu@<bastion-public-ip>

# From bastion, SSH to database
ssh ubuntu@10.0.1.45  # Your database private IP
```

**Using AWS Session Manager (No SSH key needed!):**
1. Go to **EC2** → **Instances**
2. Select `bmi-database`
3. Click **Connect** → **Session Manager** → **Connect**

### 5.2 Clone Repository

```bash
# In database instance terminal
git clone https://github.com/sarowar-alam/terraform-3-tier-different-servers.git
cd terraform-3-tier-different-servers/manual-implementation
```

### 5.3 Configure Database Script

```bash
nano deploy-database.sh
```

**Edit these variables at the top:**
```bash
DB_NAME="bmi_db"
DB_USER="bmi_user"
DB_PASSWORD="MySecurePassword123!"    # ⚠️ CHANGE THIS!
DB_PORT="5432"
GIT_REPO="https://github.com/sarowar-alam/terraform-3-tier-different-servers.git"
GIT_BRANCH="main"
```

Press `Ctrl+X`, then `Y`, then `Enter` to save.

### 5.4 Run Database Deployment Script

```bash
chmod +x deploy-database.sh
sudo ./deploy-database.sh
```

**What the script does:**
1. ✅ Updates Ubuntu packages
2. ✅ Installs PostgreSQL (version 16 on Ubuntu 24.04, or default version)
3. ✅ Creates database `bmi_db`
4. ✅ Creates user `bmi_user` with password
5. ✅ Configures PostgreSQL to accept network connections
6. ✅ Runs database migrations (creates `measurements` table)
7. ✅ Starts PostgreSQL service

**Script output (expected):**
```
==================================
Database Setup Complete!
==================================
Database Details:
  Host: 10.0.1.45
  Port: 5432
  Database: bmi_db
  User: bmi_user
  Password: MySecurePassword123!

Connection String:
  postgresql://bmi_user:MySecurePassword123!@10.0.1.45:5432/bmi_db

⚠️ IMPORTANT: Save the connection details for backend configuration!
```

### 5.5 Verify Database

```bash
# Test PostgreSQL is running
sudo systemctl status postgresql

# Check database tables
sudo -u postgres psql -d bmi_db -c "\dt"

# Expected output:
#            List of relations
#  Schema |     Name      | Type  |  Owner
# --------+---------------+-------+----------
#  public | measurements  | table | bmi_user
```

✅ **Checkpoint**: PostgreSQL 15 running with database configured

---

## STEP 6: Deploy Backend Server (15 minutes)

### 6.1 Connect to Backend Instance

```bash
# Via bastion:
ssh ubuntu@10.0.2.78

# OR via Session Manager (EC2 Console → Connect)
```

### 6.2 Clone Repository

```bash
git clone https://github.com/sarowar-alam/terraform-3-tier-different-servers.git
cd terraform-3-tier-different-servers/manual-implementation
```

### 6.3 Configure Backend Script

```bash
nano deploy-backend.sh
```

**Edit these variables:**
```bash
DB_HOST="10.0.1.45"                    # ⚠️ Your database private IP
DB_PORT="5432"
DB_NAME="bmi_db"
DB_USER="bmi_user"
DB_PASSWORD="MySecurePassword123!"     # ⚠️ Same as database password
BACKEND_PORT="3000"
FRONTEND_URL="https://bmi.ostaddevops.click"
GIT_REPO="https://github.com/sarowar-alam/terraform-3-tier-different-servers.git"
GIT_BRANCH="main"
```

Save and exit (`Ctrl+X`, `Y`, `Enter`).

### 6.4 Run Backend Deployment Script

```bash
chmod +x deploy-backend.sh
sudo ./deploy-backend.sh
```

**What the script does:**
1. ✅ Updates Ubuntu packages
2. ✅ Installs Node.js 20 LTS
3. ✅ Installs PM2 process manager
4. ✅ Clones application code to `/home/ubuntu/app`
5. ✅ Creates `.env` file with database connection
6. ✅ Installs npm dependencies
7. ✅ Tests database connection
8. ✅ Starts backend with PM2
9. ✅ Configures PM2 to start on boot

**Script output (expected):**
```
==================================
Backend Setup Complete!
==================================
Backend Details:
  Host: 10.0.2.78
  Port: 3000
  Health: http://10.0.2.78:3000/api/health
  API: http://10.0.2.78:3000/api

PM2 Commands:
  Status: pm2 status
  Logs: pm2 logs bmi-backend
  Restart: pm2 restart bmi-backend

⚠️ IMPORTANT: Save this IP for frontend configuration!
```

### 6.5 Verify Backend API

```bash
# Check PM2 process status
pm2 status

# Expected output:
# ┌─────┬──────────────┬─────────┬─────────┐
# │ id  │ name         │ status  │ restart │
# ├─────┼──────────────┼─────────┼─────────┤
# │ 0   │ bmi-backend  │ online  │ 0       │
# └─────┴──────────────┴─────────┴─────────┘

# Test API health endpoint
curl http://localhost:3000/api/health

# Expected output:
# {"status":"ok","database":"connected"}

# View logs
pm2 logs bmi-backend --lines 20
```

✅ **Checkpoint**: Backend API running on port 3000 with PM2

---

## STEP 7: Deploy Frontend Server (15 minutes)

### 7.1 Connect to Frontend Instance

```bash
# Via bastion:
ssh ubuntu@10.0.3.92

# OR via Session Manager
```

### 7.2 Clone Repository

```bash
git clone https://github.com/sarowar-alam/terraform-3-tier-different-servers.git
cd terraform-3-tier-different-servers/manual-implementation
```

### 7.3 Configure Frontend Script

```bash
nano deploy-frontend.sh
```

**Edit these variables:**
```bash
BACKEND_HOST="10.0.2.78"               # ⚠️ Your backend private IP
BACKEND_PORT="3000"
DOMAIN="bmi.ostaddevops.click"         # ⚠️ Your domain name
GIT_REPO="https://github.com/sarowar-alam/terraform-3-tier-different-servers.git"
GIT_BRANCH="main"
```

Save and exit.

### 7.4 Run Frontend Deployment Script

```bash
chmod +x deploy-frontend.sh
sudo ./deploy-frontend.sh
```

**What the script does:**
1. ✅ Updates Ubuntu packages
2. ✅ Installs Nginx web server
3. ✅ Installs Node.js 20 (for building React app)
4. ✅ Clones application code
5. ✅ Builds React production bundle (`npm run build`)
6. ✅ Copies build files to `/var/www/bmi.ostaddevops.click`
7. ✅ Configures Nginx:
   - Serves React app on port 80
   - Proxies `/api/*` requests to backend
   - Handles React Router (SPA routing)
8. ✅ Starts Nginx service

**Script output (expected):**
```
==================================
Frontend Setup Complete!
==================================
Frontend Details:
  Private IP: 10.0.3.92
  HTTP: http://10.0.3.92
  Domain: bmi.ostaddevops.click
  Web Root: /var/www/bmi.ostaddevops.click

Next Steps:
  1. Create SSL certificate with Let's Encrypt (see below)
  2. Create Application Load Balancer
  3. Add 10.0.3.92 to ALB target group
  4. Create Route53 A record: bmi.ostaddevops.click → ALB
  5. Test: https://bmi.ostaddevops.click

⚠️ Certificate setup is MANUAL - follow the guide below
```

### 7.5 Verify Frontend

```bash
# Check Nginx status
sudo systemctl status nginx

# Test locally
curl http://localhost

# Should return HTML (React app)
# Look for: <div id="root"></div>

# Check Nginx logs
sudo tail -f /var/log/nginx/bmi-access.log
```

✅ **Checkpoint**: Frontend web server running on port 80

---

## STEP 8: Create SSL Certificate with Let's Encrypt (20 minutes)

Now we'll create a free SSL certificate and import it to AWS Certificate Manager.

### 8.1 Install Certbot (Still on frontend instance)

```bash
# Update package list
sudo apt update

# Install Certbot with Route53 plugin
sudo apt install -y certbot python3-certbot-dns-route53

# Verify installation
certbot --version
```

### 8.2 Set Environment Variables

```bash
# Set your domain and email
export DOMAIN="bmi.ostaddevops.click"
export EMAIL="admin@ostaddevops.click"      # ⚠️ Change to your email
export AWS_REGION="ap-south-1"              # ⚠️ Your AWS region

# Verify IAM role is attached (should show account info)
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AROAXXXXXXXXX:i-0eb6076c9707d23c4",
    "Account": "388779989543",
    "Arn": "arn:aws:sts::388779989543:assumed-role/bmi-certbot-role/i-0eb6076c9707d23c4"
}
```

### 8.3 Request SSL Certificate from Let's Encrypt

```bash
sudo certbot certonly \
  --dns-route53 \
  --non-interactive \
  --agree-tos \
  --email $EMAIL \
  -d $DOMAIN \
  --preferred-challenges dns-01

```

**What happens:**
1. Certbot creates a TXT record in Route53 (`_acme-challenge.bmi.ostaddevops.click`)
2. Let's Encrypt verifies domain ownership
3. Certificate is issued and saved

**Expected output:**
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/bmi.ostaddevops.click/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/bmi.ostaddevops.click/privkey.pem
This certificate expires on 2026-04-15.
```

### 8.4 Verify Certificate Files

```bash
# List certificate files
sudo ls -la /etc/letsencrypt/live/$DOMAIN/

# You should see:
# cert.pem       → Your certificate
# chain.pem      → Intermediate certificates
# fullchain.pem  → cert.pem + chain.pem
# privkey.pem    → Private key
```

### 8.5 Install AWS CLI (If Not Already Installed)

The frontend instance needs AWS CLI to import certificates to ACM. The IAM role (`bmi-certbot-role`) attached to the instance provides the necessary permissions.

```bash
# Check if AWS CLI is already installed
aws --version

# If not installed or version is old, install/update AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install -y unzip
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
# Expected: aws-cli/2.x.x Python/3.x.x Linux/x.x.x

# Verify IAM role permissions (should show account info)
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AROAXXXXXXXXX:i-0eb6076c9707d23c4",
#     "Account": "388779989543",
#     "Arn": "arn:aws:sts::388779989543:assumed-role/bmi-certbot-role/i-0eb6076c9707d23c4"
# }
```

**If AWS CLI was already installed and shows your IAM role, you're ready to proceed!**

### 8.6 Import Certificate to AWS Certificate Manager (ACM)

```bash
# Import certificate to ACM
CERT_ARN=$(sudo aws acm import-certificate \
  --certificate fileb:///etc/letsencrypt/live/$DOMAIN/cert.pem \
  --private-key fileb:///etc/letsencrypt/live/$DOMAIN/privkey.pem \
  --certificate-chain fileb:///etc/letsencrypt/live/$DOMAIN/chain.pem \
  --region $AWS_REGION \
  --tags Key=Name,Value=$DOMAIN Key=ManagedBy,Value=Certbot Key=Project,Value=bmi-health-tracker \
  --query CertificateArn \
  --output text)

# Display the ARN
echo "Certificate ARN: $CERT_ARN"
```

**Expected output:**
```
Certificate ARN: arn:aws:acm:ap-south-1:388779989543:certificate/12345678-1234-1234-1234-123456789abc
```

### 8.7 Save Certificate ARN

```bash
# Save ARN to file for reference
echo $CERT_ARN | sudo tee /tmp/certificate-arn.txt

# Copy this ARN - you'll need it when creating ALB!
```

### 8.8 Verify Certificate in AWS Console

1. Go to **AWS Console** → **Certificate Manager** (ACM)
2. Region: **ap-south-1** (top right - verify correct region!)
3. You should see your certificate:
   ```
   Domain name: bmi.ostaddevops.click
   Status: Issued
   In use: No (will change after ALB setup)
   ```

### 8.9 Setup Auto-Renewal (Certificate expires in 90 days)

```bash
# Create renewal script
sudo tee /usr/local/bin/renew-cert.sh > /dev/null <<EOF
#!/bin/bash
DOMAIN="$DOMAIN"
CERT_ARN="$CERT_ARN"
AWS_REGION="$AWS_REGION"

# Renew certificate if needed (Certbot checks expiry)
certbot renew --quiet

# Re-import updated certificate to ACM
aws acm import-certificate \
  --certificate-arn \$CERT_ARN \
  --certificate fileb:///etc/letsencrypt/live/\$DOMAIN/cert.pem \
  --private-key fileb:///etc/letsencrypt/live/\$DOMAIN/privkey.pem \
  --certificate-chain fileb:///etc/letsencrypt/live/\$DOMAIN/chain.pem \
  --region \$AWS_REGION

echo "\$(date): Certificate renewed and imported to ACM" >> /var/log/cert-renewal.log
EOF

# Make script executable
sudo chmod +x /usr/local/bin/renew-cert.sh

# Test the script
sudo /usr/local/bin/renew-cert.sh

# Add cron job (runs daily at 3 AM)
(sudo crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/renew-cert.sh") | sudo crontab -

# Verify cron job
sudo crontab -l
```

✅ **Checkpoint**: SSL certificate created, imported to ACM, and auto-renewal configured

---

## STEP 9: Create Application Load Balancer (25 minutes)

We'll create a Target Group first, then the ALB, then configure listeners.

### 9.1 Create Target Group

1. Go to **AWS Console** → **EC2** → **Target Groups** (left sidebar)
2. Click **Create target group**

**Step 1: Specify group details**
```
Choose a target type: Instances
Target group name: bmi-frontend-tg
Protocol: HTTP
Port: 80
VPC: [Select your VPC]
Protocol version: HTTP1
```

**Health checks:**
```
Health check protocol: HTTP
Health check path: /
Health check port: Traffic port
```

**Advanced health check settings** (Click to expand):
```
Healthy threshold: 2 consecutive checks
Unhealthy threshold: 3 consecutive checks
Timeout: 5 seconds
Interval: 30 seconds
Success codes: 200
```

3. Click **Next**

**Step 2: Register targets**
1. Select checkbox next to `bmi-frontend` instance (10.0.3.x)
2. Verify "Ports for the selected instances" shows: `80`
3. Click **Include as pending below**
4. Verify it appears in "Targets" section below
5. Click **Create target group**

### 9.2 Verify Target Health

1. Select **bmi-frontend-tg**
2. Click **Targets** tab
3. Wait 30-60 seconds
4. Status should change from `initial` → `healthy`

If status is `unhealthy`:
- SSH to frontend instance
- Check: `sudo systemctl status nginx`
- Check: `curl http://localhost`

✅ **Checkpoint**: Target group created with healthy target

---

### 9.3 Create Application Load Balancer

1. Go to **EC2** → **Load Balancers** (left sidebar)
2. Click **Create load balancer**
3. Select **Application Load Balancer** → Click **Create**

**Basic configuration:**
```
Load balancer name: bmi-alb
Scheme: Internet-facing ⚠️ Important!
IP address type: IPv4
```

**Network mapping:**
```
VPC: [Select your VPC]
Mappings: 
  ✅ Check: ap-south-1a → Select: bmi-alb-public-1 (10.0.101.0/24)
  ✅ Check: ap-south-1b → Select: bmi-alb-public-2 (10.0.102.0/24)
```
⚠️ Must select at least 2 subnets in different AZs!

**Security groups:**
```
Remove: default
Select: bmi-alb-sg (allows HTTP 80 and HTTPS 443 from internet)
```

**Listeners and routing:**
- DO NOT configure listeners yet (we'll add them separately)
- Default: HTTP:80 → [Skip for now]

4. Scroll down and click **Create load balancer**
5. Click **View load balancer**

### 9.4 Wait for ALB to Become Active

1. Refresh page every 30 seconds
2. **State** should change from `provisioning` → `active` (takes 2-3 minutes)
3. Once **State: Active**, note the **DNS name**:
   ```
   Example: bmi-alb-1234567890.ap-south-1.elb.amazonaws.com
   ```

### 9.5 Save ALB DNS Name

```bash
ALB_DNS="bmi-alb-1234567890.ap-south-1.elb.amazonaws.com"
```

✅ **Checkpoint**: ALB created and active

---

### 9.6 Configure HTTP Listener (Redirect to HTTPS)

1. Select your ALB: **bmi-alb**
2. Click **Listeners** tab
3. Click **Add listener**

**Listener configuration:**
```
Protocol: HTTP
Port: 80
```

**Default action:**
```
Action type: Redirect
Protocol: HTTPS
Port: 443
Status code: HTTP 301 (Permanently moved)
```

4. Click **Add**

### 9.7 Configure HTTPS Listener (Forward to Target Group)

1. Still on **Listeners** tab
2. Click **Add listener**

**Listener configuration:**
```
Protocol: HTTPS
Port: 443
```

**Default action:**
```
Action type: Forward to target group
Target group: bmi-frontend-tg
```

**Secure listener settings:**
```
Security policy: ELBSecurityPolicy-TLS13-1-2-2021-06
```
*This enforces TLS 1.3 and 1.2 (modern, secure)*

**Default SSL/TLS certificate:**
```
From ACM: ✅ (radio button)
Select certificate: bmi.ostaddevops.click
  └─ Shows: arn:aws:acm:ap-south-1:xxxxx:certificate/xxxxx
```

3. Click **Add**

### 9.8 Verify Listeners

You should now have 2 listeners:

| Protocol | Port | Rules | Default action |
|----------|------|-------|----------------|
| HTTP | 80 | 1 | Redirect to HTTPS:443 |
| HTTPS | 443 | 1 | Forward to bmi-frontend-tg |

### 9.9 Test ALB (Before DNS)

```bash
# From your local machine:

# Test HTTP (should redirect to HTTPS)
curl -I http://bmi-alb-1234567890.ap-south-1.elb.amazonaws.com

# Expected:
# HTTP/1.1 301 Moved Permanently
# Location: https://bmi-alb-1234567890.ap-south-1.elb.amazonaws.com:443/

# Test HTTPS (will show certificate error - that's OK for now)
curl -Ik https://bmi-alb-1234567890.ap-south-1.elb.amazonaws.com

# Should return: HTTP/2 200
```

✅ **Checkpoint**: ALB configured with HTTP→HTTPS redirect and HTTPS listener

---

## STEP 10: Configure DNS in Route53 (10 minutes)

Now we'll point your domain to the ALB.

### 10.1 Get ALB Information

1. Go to **EC2** → **Load Balancers** → Select **bmi-alb**
2. Copy the **DNS name**:
   ```
   Example: bmi-alb-1234567890.ap-south-1.elb.amazonaws.com
   ```
3. Note the **Hosted zone ID** (for ALB, not your Route53 zone):
   ```
   Example: Z35SXDOTRQ7X7K (this is ALB's zone ID in ap-south-1)
   ```

### 10.2 Create Route53 A Record (Alias)

1. Go to **Route53** → **Hosted zones**
2. Click on your domain: **ostaddevops.click**
3. Click **Create record**

**Record details:**
```
Record name: bmi
  └─ Full name will be: bmi.ostaddevops.click
Record type: A - Routes traffic to an IPv4 address
```

**Enable Alias:** Toggle **ON** (blue)

**Route traffic to:**
```
Choose endpoint: Alias to Application and Classic Load Balancer
Region: ap-south-1 (Mumbai) ⚠️ Match your ALB region
Load balancer: dualstack.bmi-alb-1234567890.ap-south-1.elb.amazonaws.com
```

**Routing policy:**
```
Simple routing
```

**Evaluate target health:** No (leave unchecked)

4. Click **Create records**

### 10.3 Verify DNS Record Created

1. Stay on **Route53** → **Hosted zones** → **ostaddevops.click**
2. You should see new record:
   ```
   Record name: bmi.ostaddevops.click
   Type: A
   Value: Alias to bmi-alb-xxx...
   ```

### 10.4 Test DNS Resolution (Wait 2-5 minutes)

```bash
# From your local machine:

# Test DNS resolution
nslookup bmi.ostaddevops.click

# Expected output:
# Non-authoritative answer:
# Name:    bmi.ostaddevops.click
# Address: 13.232.xxx.xxx  (ALB IP)
# Address: 15.207.xxx.xxx  (ALB IP - multiple IPs is normal)

# Alternative test:
dig bmi.ostaddevops.click

# Or using curl:
curl -I http://bmi.ostaddevops.click
```

✅ **Checkpoint**: DNS record created and resolving to ALB

---

## STEP 11: Final Verification & Testing (10 minutes)

### 11.1 Test HTTP → HTTPS Redirect

```bash
# Should redirect to HTTPS
curl -I http://bmi.ostaddevops.click

# Expected output:
# HTTP/1.1 301 Moved Permanently
# Location: https://bmi.ostaddevops.click/
```

### 11.2 Test HTTPS Access

```bash
# Should return 200 OK
curl -I https://bmi.ostaddevops.click

# Expected output:
# HTTP/2 200
# server: nginx
# content-type: text/html
```

### 11.3 Open in Web Browser

1. Open browser
2. Go to: **https://bmi.ostaddevops.click**
3. You should see: **BMI Health Tracker** application

**Verify SSL Certificate:**
- Click padlock icon in browser address bar
- Certificate should show:
  ```
  Issued to: bmi.ostaddevops.click
  Issued by: Let's Encrypt
  Valid from: [today]
  Valid until: [today + 90 days]
  ```

### 11.4 Test Application Functionality

1. **Calculate BMI:**
   - Enter Height: `170` cm
   - Enter Weight: `70` kg
   - Click **Calculate BMI**
   - Result should show: **BMI = 24.2** (Normal weight)

2. **Verify Database Connection:**
   - BMI result should be saved
   - Chart should update
   - Refresh page - history should persist

3. **Check Backend API:**
   ```bash
   # From browser developer console (F12):
   fetch('https://bmi.ostaddevops.click/api/health')
     .then(r => r.json())
     .then(console.log)
   
   # Should log:
   # {status: "ok", database: "connected"}
   ```

### 11.5 Verify Traffic Flow

```bash
# SSH to frontend instance
ssh ubuntu@10.0.3.92  # Via bastion or Session Manager

# Watch Nginx access logs
sudo tail -f /var/log/nginx/bmi-access.log

# In browser, refresh: https://bmi.ostaddevops.click
# You should see logs showing ALB requests
```

### 11.6 Check All Services

**On Frontend:**
```bash
sudo systemctl status nginx
# Should show: active (running)
```

**On Backend:**
```bash
pm2 status
# Should show: bmi-backend | online

pm2 logs bmi-backend --lines 20
# Should show API requests
```

**On Database:**
```bash
sudo -u postgres psql -d bmi_db -c "SELECT COUNT(*) FROM measurements;"
# Should show number of BMI calculations stored
```

---

## 🎉 DEPLOYMENT COMPLETE!

Your application is now live at: **https://bmi.ostaddevops.click**

### What You've Built

```
✅ Infrastructure:
   ├─ 3 Private Subnets (database, backend, frontend)
   ├─ 2 Public Subnets (for ALB in multi-AZ)
   ├─ 4 Security Groups (with specific port access)
   └─ 1 IAM Role (for certificate management)

✅ Application Servers:
   ├─ Database: PostgreSQL (v16) on port 5432
   ├─ Backend: Node.js/PM2 API on port 3000
   └─ Frontend: Nginx web server on port 80

✅ Load Balancer & SSL:
   ├─ Application Load Balancer (internet-facing)
   ├─ HTTP :80 → Redirects to HTTPS :443
   ├─ HTTPS :443 → SSL certificate from Let's Encrypt
   └─ Auto-renewal configured (90-day certificate)

✅ DNS:
   └─ Route53 A record: bmi.ostaddevops.click → ALB
```

### Port Flow Summary

```
Internet → ALB:443 (HTTPS) → Frontend:80 (HTTP) → Backend:3000 (HTTP) → Database:5432 (PostgreSQL)
         ↓ (if HTTP:80)
         301 Redirect to HTTPS:443
```

### Security Summary

| Server | Port | Source | Purpose |
|--------|------|--------|---------|
| Database | 5432 | Backend SG | PostgreSQL |
| Database | 22 | Your IP | SSH admin |
| Backend | 3000 | Frontend SG | API calls |
| Backend | 22 | Your IP | SSH admin |
| Frontend | 80 | ALB SG | Web traffic |
| Frontend | 22 | Your IP | SSH admin |
| ALB | 80 | 0.0.0.0/0 | HTTP (redirects) |
| ALB | 443 | 0.0.0.0/0 | HTTPS |

---

## 🔧 Post-Deployment Tasks

### Monitor Application

```bash
# Backend logs
ssh ubuntu@10.0.2.78
pm2 logs bmi-backend

# Frontend logs
ssh ubuntu@10.0.3.92
sudo tail -f /var/log/nginx/access.log

# Database queries
ssh ubuntu@10.0.1.45
sudo -u postgres psql -d bmi_db
```

### Update Application

```bash
# Backend update
cd ~/app/backend
git pull origin main
npm install
pm2 restart bmi-backend

# Frontend update
cd ~/app/frontend
git pull origin main
npm install
npm run build
sudo cp -r dist/* /var/www/bmi.ostaddevops.click/
sudo systemctl reload nginx
```

### Backup Database

```bash
# Create backup
sudo -u postgres pg_dump bmi_db > backup_$(date +%Y%m%d).sql

# Restore from backup
sudo -u postgres psql bmi_db < backup_20260115.sql
```

---

## 🗑️ Cleanup / Destroy Resources

To remove everything and stop AWS charges:

1. Delete Route53 A record (`bmi`)
2. Delete ALB (`bmi-alb`)
3. Delete Target Group (`bmi-frontend-tg`)
4. Terminate EC2 instances (database, backend, frontend)
5. Delete Security Groups (reverse order: alb, frontend, backend, database)
6. Delete IAM role (`bmi-certbot-role`) and policy
7. Delete certificate from ACM
8. Delete subnets (if created specifically for this project)

**Estimated Cost**: ~$30-50/month (3× t3.micro + ALB + data transfer)

---

## 🗑️ Complete Resource Cleanup Guide

When you're done with the deployment and want to delete all resources, follow this step-by-step guide to ensure complete cleanup without errors.

### Why Order Matters

Resources have dependencies. Deleting them in the wrong order will cause errors. Always delete dependent resources first.

**Dependency Chain:**
```
DNS → ALB → Target Group → EC2 Instances → Security Groups → IAM → Subnets
```

---

### Step 1: Delete Route53 DNS Record (2 minutes)

**Why First:** Remove public access to your application

1. Go to **AWS Console** → **Route53** → **Hosted Zones**
2. Click on your hosted zone: **ostaddevops.click**
3. Find the A record: **bmi.ostaddevops.click**
4. Select the record (checkbox)
5. Click **Delete records**
6. Confirm deletion

**Verify:**
```bash
# DNS should no longer resolve
nslookup bmi.ostaddevops.click
# Expected: NXDOMAIN or no result
```

✅ **Checkpoint**: DNS record deleted

---

### Step 2: Delete Application Load Balancer (5 minutes)

**Why Now:** ALB depends on Target Group, but not on EC2 instances

1. Go to **AWS Console** → **EC2** → **Load Balancers**
2. Select **bmi-alb**
3. Click **Actions** → **Delete load balancer**
4. Type `confirm` in the text box
5. Click **Delete**

**Important:** Wait for ALB to fully delete (State: deleted) before proceeding. This takes 2-3 minutes.

**Verify:**
```bash
# Check ALB is deleted
aws elbv2 describe-load-balancers --region ap-south-1 --query 'LoadBalancers[?LoadBalancerName==`bmi-alb`]'
# Expected: [] (empty array)
```

✅ **Checkpoint**: ALB deleted

---

### Step 3: Delete Target Group (1 minute)

**Why Now:** No longer needed after ALB deletion

1. Go to **AWS Console** → **EC2** → **Target Groups**
2. Select **bmi-frontend-tg**
3. Click **Actions** → **Delete target group**
4. Confirm deletion

**Verify:**
- Target group should disappear from list

✅ **Checkpoint**: Target group deleted

---

### Step 4: Terminate EC2 Instances (5 minutes)

**Why Now:** Remove running instances to stop compute charges

**Order:** Terminate in any order (no dependencies between instances)

#### 4.1 Terminate Frontend Instance

1. Go to **AWS Console** → **EC2** → **Instances**
2. Select **bmi-frontend** instance
3. Click **Instance state** → **Terminate instance**
4. Confirm: **Terminate**

#### 4.2 Terminate Backend Instance

1. Select **bmi-backend** instance
2. Click **Instance state** → **Terminate instance**
3. Confirm: **Terminate**

#### 4.3 Terminate Database Instance

1. Select **bmi-database** instance
2. Click **Instance state** → **Terminate instance**
3. Confirm: **Terminate**

**Important:** Wait for all instances to reach **Terminated** state (takes 2-3 minutes)

**Verify:**
```bash
# Check instance states
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bmi-*" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
  --output table

# All should show: terminated
```

✅ **Checkpoint**: All 3 EC2 instances terminated

---

### Step 5: Delete Security Groups (3 minutes)

**Why Now:** EC2 instances no longer using them

**Critical:** Delete in reverse order of creation (due to references between security groups)

#### 5.1 Delete ALB Security Group

1. Go to **AWS Console** → **VPC** → **Security Groups**
2. Find **bmi-alb-sg**
3. Select it (checkbox)
4. Click **Actions** → **Delete security groups**
5. Confirm: **Delete**

#### 5.2 Delete Frontend Security Group

1. Find **bmi-frontend-sg**
2. Select it
3. Click **Actions** → **Delete security groups**
4. Confirm: **Delete**

#### 5.3 Delete Backend Security Group

1. Find **bmi-backend-sg**
2. Select it
3. Click **Actions** → **Delete security groups**
4. Confirm: **Delete**

#### 5.4 Delete Database Security Group

1. Find **bmi-database-sg**
2. Select it
3. Click **Actions** → **Delete security groups**
4. Confirm: **Delete**

**Common Error:**
```
Error: Cannot delete security group because it is referenced by another security group
```
**Solution:** Wait 5 minutes for AWS to propagate instance termination, then retry

**Verify:**
```bash
# Check security groups deleted
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=bmi-*" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' \
  --output table

# Should return empty or not found
```

✅ **Checkpoint**: All 4 security groups deleted

---

### Step 6: Delete SSL Certificate from ACM (2 minutes)

**Why Now:** No longer attached to ALB

1. Go to **AWS Console** → **Certificate Manager (ACM)**
2. **Region:** ap-south-1 (verify correct region!)
3. Find certificate: **bmi.ostaddevops.click**
4. Select it
5. Click **Actions** → **Delete**
6. Confirm deletion

**Note:** If certificate shows "In use", wait 5 minutes for ALB deletion to fully propagate

**Verify:**
```bash
# Check certificate deleted
aws acm list-certificates --region ap-south-1 \
  --query 'CertificateSummaryList[?DomainName==`bmi.ostaddevops.click`]'
# Expected: [] (empty)
```

✅ **Checkpoint**: SSL certificate deleted

---

### Step 7: Delete IAM Role and Policy (3 minutes)

**Why Now:** No EC2 instances using the role

#### 7.1 Delete IAM Role

1. Go to **AWS Console** → **IAM** → **Roles**
2. Find **bmi-certbot-role**
3. Select it
4. Click **Delete**
5. Type the role name to confirm
6. Click **Delete**

#### 7.2 Delete IAM Policy

1. Go to **IAM** → **Policies**
2. Filter by: Customer managed
3. Find **bmi-certbot-policy**
4. Select it
5. Click **Actions** → **Delete**
6. Type the policy name to confirm
7. Click **Delete**

**Verify:**
```bash
# Check role deleted
aws iam get-role --role-name bmi-certbot-role
# Expected: NoSuchEntity error

# Check policy deleted
aws iam list-policies --scope Local \
  --query 'Policies[?PolicyName==`bmi-certbot-policy`]'
# Expected: [] (empty)
```

✅ **Checkpoint**: IAM role and policy deleted

---

### Step 8: Delete Subnets (OPTIONAL - 5 minutes)

**Only if you created these subnets specifically for this project**

**Warning:** If these subnets are used by other resources, deletion will fail. That's normal - skip this step.

#### 8.1 Delete Private Subnets

1. Go to **AWS Console** → **VPC** → **Subnets**
2. Select **bmi-database-private** (10.0.1.0/24)
3. Click **Actions** → **Delete subnet**
4. Confirm: **Delete**
5. Repeat for:
   - **bmi-backend-private** (10.0.2.0/24)
   - **bmi-frontend-private** (10.0.3.0/24)

#### 8.2 Delete Public Subnets

1. Select **bmi-alb-public-1** (10.0.101.0/24)
2. Click **Actions** → **Delete subnet**
3. Confirm: **Delete**
4. Repeat for:
   - **bmi-alb-public-2** (10.0.102.0/24)

**Common Error:**
```
Error: The subnet has dependencies and cannot be deleted
```
**Solution:** Check if other resources (EC2, ALB, etc.) still exist in the subnet. Wait 10 minutes and retry.

**Verify:**
```bash
# Check subnets deleted
aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=bmi-*" \
  --query 'Subnets[*].[SubnetId,Tags[?Key==`Name`].Value|[0],CidrBlock]' \
  --output table

# Should return empty
```

✅ **Checkpoint**: Subnets deleted (if applicable)

---

### Step 9: Verify Complete Cleanup (5 minutes)

Run these commands to ensure nothing was missed:

```bash
# 1. Check EC2 Instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bmi-*" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --output table
# Expected: Empty table

# 2. Check Load Balancers
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `bmi`)].[LoadBalancerName,State.Code]' \
  --output table
# Expected: Empty table

# 3. Check Target Groups
aws elbv2 describe-target-groups \
  --query 'TargetGroups[?contains(TargetGroupName, `bmi`)].[TargetGroupName]' \
  --output table
# Expected: Empty table

# 4. Check Security Groups
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=bmi-*" \
  --query 'SecurityGroups[*].[GroupName,GroupId]' \
  --output table
# Expected: Empty table

# 5. Check ACM Certificates
aws acm list-certificates --region ap-south-1 \
  --query 'CertificateSummaryList[?DomainName==`bmi.ostaddevops.click`].[DomainName,CertificateArn]' \
  --output table
# Expected: Empty table

# 6. Check IAM Role
aws iam get-role --role-name bmi-certbot-role 2>&1
# Expected: NoSuchEntity error

# 7. Check Route53 Record
aws route53 list-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --query 'ResourceRecordSets[?Name==`bmi.ostaddevops.click.`]' \
  --output table
# Expected: Empty table
```

**All checks passed?** ✅ Cleanup complete!

---

### Step 10: Review Billing (IMPORTANT)

**Wait 24 hours**, then verify no charges are accumulating:

1. Go to **AWS Console** → **Billing** → **Bills**
2. Check current month charges
3. Look for:
   - ❌ EC2 instance charges (should be $0 or stopping)
   - ❌ ALB charges (should be $0 or stopping)
   - ❌ Data transfer charges (should be minimal/stopping)
   - ✅ Small charges for previous usage (normal)

**Set up billing alert:**
1. Go to **Billing** → **Budgets** → **Create budget**
2. Set threshold: $5
3. Enter your email
4. Get alerts if unexpected charges occur

---

## 📊 Cleanup Summary

### Resources Created During Deployment

| Resource Type | Count | Names | Deleted? |
|---------------|-------|-------|----------|
| **Route53 A Record** | 1 | bmi.ostaddevops.click | ✅ Step 1 |
| **Application Load Balancer** | 1 | bmi-alb | ✅ Step 2 |
| **Target Group** | 1 | bmi-frontend-tg | ✅ Step 3 |
| **EC2 Instances** | 3 | bmi-database, bmi-backend, bmi-frontend | ✅ Step 4 |
| **Security Groups** | 4 | bmi-alb-sg, bmi-frontend-sg, bmi-backend-sg, bmi-database-sg | ✅ Step 5 |
| **ACM Certificate** | 1 | bmi.ostaddevops.click | ✅ Step 6 |
| **IAM Role** | 1 | bmi-certbot-role | ✅ Step 7 |
| **IAM Policy** | 1 | bmi-certbot-policy | ✅ Step 7 |
| **Subnets** | 5 | 3 private + 2 public | ✅ Step 8 (optional) |

### Cost Breakdown (Before Deletion)

| Resource | Monthly Cost | Notes |
|----------|--------------|-------|
| EC2 (3× t3.micro) | ~$15-20 | $5-7 per instance |
| Application Load Balancer | ~$16 | Fixed cost + data transfer |
| Data Transfer | ~$1-5 | Varies by usage |
| Route53 Query | ~$0.50 | Minimal |
| **Total** | **~$30-50** | Stops after deletion |

### After Cleanup: Expected Cost

- **$0** - All compute resources deleted
- **Tiny charges** - Previous hours of usage (one-time)
- **Hosted Zone** - $0.50/month (if you keep the domain)

---

## 🚨 Troubleshooting Cleanup Issues

### Issue: Cannot delete security group

**Error:** `DependencyViolation: resource has a dependent object`

**Solutions:**
1. Wait 5-10 minutes for EC2 terminations to propagate
2. Check if any network interfaces still attached:
   ```bash
   aws ec2 describe-network-interfaces \
     --filters "Name=group-id,Values=sg-xxxxx"
   ```
3. Manually detach network interfaces if needed
4. Delete security groups in correct order (ALB → Frontend → Backend → Database)

---

### Issue: Cannot delete ALB

**Error:** `LoadBalancer is in use by listeners`

**Solutions:**
1. Delete all listeners first:
   - Go to ALB → Listeners tab
   - Delete HTTP:80 listener
   - Delete HTTPS:443 listener
2. Then delete the ALB

---

### Issue: Cannot delete certificate from ACM

**Error:** `Certificate is in use`

**Solutions:**
1. Verify ALB is fully deleted (can take 5 minutes)
2. Check ALB listeners are removed
3. Wait and retry

---

### Issue: IAM role deletion fails

**Error:** `DeleteConflict: Cannot delete entity, must detach policy first`

**Solutions:**
1. Go to IAM → Roles → bmi-certbot-role
2. Click **Permissions** tab
3. Detach all policies
4. Then delete the role

---

## 💡 Best Practices for Future Deployments

### 1. Tag Everything
Always tag resources with:
```
Project: bmi-health-tracker
Environment: production
ManagedBy: manual
CreatedBy: your-name
```

Makes cleanup easier: filter by tag and delete all at once

### 2. Use Terraform for Production
This manual deployment is educational. For production:
- Use Terraform (code in `/terraform` folder)
- Destroy everything with: `terraform destroy`
- No manual cleanup needed

### 3. Set Up Billing Alerts
Before deploying:
1. Set budget alerts ($10, $50, $100 thresholds)
2. Get email notifications
3. Catch unexpected charges early

### 4. Document Your Resources
Keep a checklist of what you created:
- Instance IDs
- Security Group IDs
- Subnet IDs
- ALB ARN
- Certificate ARN

Makes cleanup faster and prevents orphaned resources

---

## ✅ Cleanup Complete!

If you followed all steps, you should now have:

- ✅ $0 ongoing charges (except hosted zone)
- ✅ All BMI application resources deleted
- ✅ Clean AWS account
- ✅ Knowledge of complete AWS deployment lifecycle

**Time to complete cleanup:** 20-30 minutes (including wait times)

**Congratulations! You've learned the complete AWS deployment and cleanup lifecycle! 🎉**

---

## 📞 Support & Troubleshooting

### Common Issues

**Issue: Can't SSH to instances**
- Solution: Use AWS Systems Manager Session Manager (no SSH needed)

**Issue: Target shows unhealthy**
- Check: `sudo systemctl status nginx` on frontend
- Check security group allows ALB SG on port 80

**Issue: 502 Bad Gateway**
- Backend might be down: Check `pm2 status`
- Database connection failed: Check credentials in backend .env

**Issue: Certificate error**
- Verify certificate is in correct region (ACM)
- Check ALB listener is using correct certificate

### Useful Commands

```bash
# Check all service status
sudo systemctl status nginx       # Frontend
pm2 status                        # Backend
sudo systemctl status postgresql  # Database

# View recent logs
sudo journalctl -u nginx -n 50
pm2 logs bmi-backend --lines 50
sudo tail -50 /var/log/postgresql/postgresql-15-main.log

# Test connectivity
curl http://localhost              # Frontend local
curl http://10.0.2.78:3000/api/health  # Backend from frontend
telnet 10.0.1.45 5432             # Database from backend
```

---

**Repository:** https://github.com/sarowar-alam/terraform-3-tier-different-servers

**Congratulations! You've successfully deployed a production-ready 3-tier application on AWS! 🚀**

---

**11.3 Wait for DNS Propagation** (2-5 minutes)

```bash
# From your local machine
nslookup bmi.ostaddevops.click

# Should return ALB IP addresses
```

✅ **Checkpoint**: DNS pointing to ALB

---

### PHASE 6: Final Verification

#### Step 12: Test Everything (5 minutes)

**12.1 Test HTTPS**
```bash
# From your local machine
curl -I https://bmi.ostaddevops.click

# Should return: HTTP/2 200
```

**12.2 Test HTTP Redirect**
```bash
curl -I http://bmi.ostaddevops.click

# Should return: HTTP/1.1 301 Moved Permanently
#                Location: https://bmi.ostaddevops.click/
```

**12.3 Open in Browser**
```
Visit: https://bmi.ostaddevops.click

You should see the BMI Health Tracker application!
```

**12.4 Test Application**
1. Enter height: 170 cm
2. Enter weight: 70 kg
3. Click "Calculate BMI"
4. Result should show: BMI = 24.2 (Normal)
5. Chart should update

---

## 🎉 Deployment Complete!

Your application is now live at: **https://bmi.ostaddevops.click**

### What You've Built

```
✅ Database Server (PostgreSQL 15)
   └─ Running on port 5432 in private subnet

✅ Backend Server (Node.js + PM2)
   └─ API running on port 3000 in private subnet

✅ Frontend Server (Nginx + React)
   └─ Web server on port 80 in private subnet

✅ Application Load Balancer
   ├─ HTTP :80 → Redirects to HTTPS
   └─ HTTPS :443 → Forwards to frontend

✅ SSL Certificate (Let's Encrypt)
   └─ Auto-renews every 60 days

✅ DNS (Route53)
   └─ bmi.ostaddevops.click → ALB
```

---

## 🔧 Troubleshooting

### Issue: Can't SSH to instances

**Solution**: Ensure instances have public IP or use bastion host/VPN

### Issue: Target group shows unhealthy

**Solution**:
```bash
# SSH to frontend instance
sudo systemctl status nginx
curl http://localhost
# Check /var/log/nginx/error.log
```

### Issue: Backend can't connect to database

**Solution**:
```bash
# SSH to backend instance
telnet $DATABASE_IP 5432
# Should connect

# Check PM2 logs
pm2 logs bmi-backend
```

### Issue: Certificate not working

**Solution**:
```bash
# SSH to frontend instance
sudo certbot certificates

# Check ACM
aws acm list-certificates --region ap-south-1

# Verify ALB listener has correct certificate
```

---

## 📚 Useful Commands

### Check Application Status

```bash
# Backend
ssh ubuntu@$BACKEND_IP
pm2 status
pm2 logs bmi-backend

# Frontend
ssh ubuntu@$FRONTEND_IP
sudo systemctl status nginx
sudo tail -f /var/log/nginx/access.log

# Database
ssh ubuntu@$DATABASE_IP
sudo -u postgres psql -d bmi_db -c "SELECT COUNT(*) FROM measurements;"
```

### Update Application

```bash
# Backend
cd ~/terraform-3-tier-different-servers/backend
git pull
npm install
pm2 restart bmi-backend

# Frontend
cd ~/terraform-3-tier-different-servers/frontend
git pull
npm install
npm run build
sudo cp -r dist/* /var/www/bmi-health-tracker/
```

### View Logs

```bash
# Backend logs
pm2 logs bmi-backend --lines 100

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log

# PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log
```

---

## 🗑️ Cleanup (Delete Everything)

To remove all resources and avoid charges:

1. Delete Route53 A record (`bmi.ostaddevops.click`)
2. Delete Application Load Balancer (`bmi-alb`)
3. Delete Target Group (`bmi-frontend-tg`)
4. Terminate EC2 instances (database, backend, frontend)
5. Delete Security Groups (in reverse order: alb, frontend, backend, database)
6. Delete IAM role (`bmi-certbot-role`) and policy
7. Delete certificate from ACM

**Estimated monthly cost**: $30-50 (3× t3.micro + ALB + data transfer)

---

## 📞 Support

- Repository: https://github.com/sarowar-alam/terraform-3-tier-different-servers
- Issues: https://github.com/sarowar-alam/terraform-3-tier-different-servers/issues

---

**Congratulations! You've successfully deployed a production-ready 3-tier application on AWS! 🚀**

---

## Author

**MD Sarowar Alam**
Lead DevOps Engineer, WPP Production
📧 Email: [sarowar@hotmail.com](mailto:sarowar@hotmail.com)
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/

---
