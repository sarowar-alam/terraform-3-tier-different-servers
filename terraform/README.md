# BMI Health Tracker — 3-Tier AWS Infrastructure

> **Production-ready** 3-tier application deployed on AWS with Terraform IaC, automated SSL provisioning, and CI/CD via GitHub Actions with a self-hosted runner.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Tech Stack](#3-tech-stack)
4. [Folder Structure](#4-folder-structure)
5. [Application Workflow](#5-application-workflow)
6. [CI/CD Pipeline Overview](#6-cicd-pipeline-overview)
7. [GitHub Actions Workflow Explanation](#7-github-actions-workflow-explanation)
8. [Self-Hosted Runner Setup](#8-self-hosted-runner-setup)
9. [Deployment Process](#9-deployment-process)
10. [Environment Variables](#10-environment-variables)
11. [Prerequisites](#11-prerequisites)
12. [Local Development Setup](#12-local-development-setup)
13. [Build and Run Instructions](#13-build-and-run-instructions)
14. [Testing Instructions](#14-testing-instructions)
15. [Production Deployment Steps](#15-production-deployment-steps)
16. [Monitoring and Logging](#16-monitoring-and-logging)
17. [Security Best Practices Applied](#17-security-best-practices-applied)
18. [Troubleshooting](#18-troubleshooting)
19. [Cost Estimation](#19-cost-estimation)
20. [Future Improvements](#20-future-improvements)
21. [Contributor Guidelines](#21-contributor-guidelines)
22. [License](#22-license)

---

## 1. Project Overview

**BMI Health Tracker** is a full-stack health and fitness tracking application that allows users to record body measurements, calculate BMI (Body Mass Index), BMR (Basal Metabolic Rate), and daily calorie needs, and visualise 30-day BMI trends via interactive charts.

The infrastructure is fully automated with Terraform and deployed across three distinct EC2 tiers inside a private VPC. HTTPS is handled by an Application Load Balancer using a Let's Encrypt certificate automatically issued by Certbot (DNS-01 challenge via Route53) and imported into AWS Certificate Manager. The complete lifecycle — from infrastructure provisioning to application initialisation — is orchestrated through GitHub Actions with a self-hosted runner.

| Item | Value |
|------|-------|
| Application URL | `https://bmiostad.ostaddevops.click` |
| AWS Region | `ap-south-1` (Mumbai) |
| Environment | `production` |
| Terraform State | S3 bucket `batch-10-tf-states` |

---

## 2. Architecture Overview

```
                        ┌──────────────────────────┐
                        │   Internet / Users       │
                        └────────────┬─────────────┘
                                     │  HTTPS :443
                        ┌────────────▼─────────────┐
                        │   Route53 DNS (A Alias)  │
                        │   bmiostad.ostaddevops   │
                        │        .click            │
                        └────────────┬─────────────┘
                                     │
                   ┌─────────────────▼────────────────┐
                   │    Application Load Balancer     │
                   │  HTTP :80  ──► redirect HTTPS    │
                   │  HTTPS :443  TLS 1.3 (ACM cert)  │
                   │  (Public Subnets — 2 AZs)        │
                   └─────────────────┬────────────────┘
                                     │ HTTP :80
              ┌──────────────────────┼──────────────────────────┐
              │            AWS VPC — Private Subnets            │
              │                                                 │
              │  ┌──────────────────┐                           │
              │  │  TIER 1: Frontend│                           │
              │  │  EC2 t3.medium   │                           │
              │  │  Ubuntu 22.04    │                           │
              │  │  Nginx :80       │                           │
              │  │  React SPA       │                           │
              │  └────────┬─────────┘                           │
              │           │ proxy /api/* → :3000                │
              │  ┌────────▼─────────┐                           │
              │  │  TIER 2: Backend │                           │
              │  │  EC2 t3.medium   │                           │
              │  │  Ubuntu 22.04    │                           │
              │  │  Node.js 20 LTS  │                           │
              │  │  Express :3000   │                           │
              │  │  PM2 process mgr │                           │
              │  └────────┬─────────┘                           │
              │           │ pg pool → :5432                     │
              │  ┌────────▼─────────┐                           │
              │  │  TIER 3: Database│                           │
              │  │  EC2 t3.medium   │                           │
              │  │  Ubuntu 22.04    │                           │
              │  │  PostgreSQL      │                           │
              │  │  Port 5432       │                           │
              │  └──────────────────┘                           │
              │                                                 │
              └─────────────────────────────────────────────────┘

   IAM Role (Frontend EC2)
   ├── Route53: ChangeResourceRecordSets (DNS-01 challenge)
   ├── ACM: ImportCertificate (import Let's Encrypt cert)
   └── SSM: AmazonSSMManagedInstanceCore (Session Manager)
```

### Traffic Flow

1. User requests `https://bmiostad.ostaddevops.click`
2. Route53 resolves the A-Alias record to the ALB
3. ALB terminates TLS using the ACM certificate (Let's Encrypt, auto-renewed)
4. ALB forwards HTTP traffic to the Frontend EC2 (port 80) via a Target Group
5. Nginx serves the React SPA for non-API paths (`/`)
6. Nginx reverse-proxies `/api/*` requests to the Backend EC2 (port 3000)
7. The Express API queries the PostgreSQL database (port 5432) using a connection pool

---

## 3. Tech Stack

### Application

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| Frontend | React | 18.2.0 | Single Page Application |
| Frontend | Vite | 5.0.0 | Build tool, HMR dev server |
| Frontend | Axios | 1.4.0 | HTTP client for API calls |
| Frontend | Chart.js + react-chartjs-2 | 4.4.0 / 5.2.0 | BMI trend charts |
| Backend | Node.js | 20.x LTS | JavaScript runtime |
| Backend | Express | 4.18.2 | HTTP framework |
| Backend | pg (node-postgres) | 8.10.0 | PostgreSQL client |
| Backend | PM2 | latest | Process manager, auto-restart |
| Backend | dotenv | 16.0.0 | Environment variable loading |
| Database | PostgreSQL | 14 (Ubuntu 22.04) | Relational database |
| Web Server | Nginx | latest stable | Reverse proxy, static files |

### Infrastructure

| Component | Technology | Details |
|-----------|-----------|---------|
| Cloud Provider | AWS | Region: ap-south-1 |
| IaC | Terraform | >= 1.0, AWS Provider ~> 5.0 |
| Compute | EC2 | 3× t3.medium, Ubuntu 22.04 LTS |
| Load Balancer | AWS ALB | HTTP/2, TLS 1.3, cross-zone |
| DNS | Route53 | A-Alias record to ALB |
| SSL/TLS | Let's Encrypt + ACM | Certbot DNS-01, auto-renewed |
| State Backend | S3 | `batch-10-tf-states`, encrypted |
| CI/CD | GitHub Actions | Self-hosted runner |
| IAM | AWS IAM | Least-privilege roles |

---

## 4. Folder Structure

```
terraform-3-tier-different-servers/
│
├── .github/
│   └── workflows/
│       ├── deploy.yml          # Production deployment workflow
│       └── destroy.yml         # Infrastructure teardown workflow
│
├── frontend/                   # React 18 SPA
│   ├── src/
│   │   ├── App.jsx             # Root component
│   │   ├── api.js              # Axios instance + interceptors
│   │   ├── main.jsx            # React entry point
│   │   ├── index.css           # Global styles
│   │   └── components/
│   │       ├── MeasurementForm.jsx   # Add health measurement form
│   │       └── TrendChart.jsx        # 30-day BMI trend chart
│   ├── index.html
│   ├── package.json
│   └── vite.config.js          # Dev proxy: /api → localhost:3000
│
├── backend/                    # Node.js / Express API
│   ├── src/
│   │   ├── server.js           # Express app + CORS + middleware
│   │   ├── routes.js           # API route handlers
│   │   ├── db.js               # PostgreSQL connection pool
│   │   └── calculations.js     # BMI / BMR / calorie formulas
│   ├── migrations/
│   │   ├── 001_create_measurements.sql
│   │   └── 002_add_measurement_date.sql
│   ├── ecosystem.config.js     # PM2 configuration
│   ├── .env.example            # Environment variable template
│   └── package.json
│
├── database/
│   └── setup-database.sh       # Standalone PostgreSQL init script
│
├── IMPLEMENTATION_AUTO.sh      # Legacy all-in-one deployment script
│
└── terraform/                  # Infrastructure as Code (Terraform)
    ├── main.tf                 # Root module — provider, data sources,
    │                           #   module calls, TG attachment
    ├── variables.tf            # All input variables with descriptions
    ├── outputs.tf              # URLs, instance IDs, cert ARN, IAM info
    ├── backend.tf              # S3 remote state configuration
    ├── terraform.tfvars        # Active variable values (gitignored)
    ├── terraform.tfvars.example
    ├── backend-config.tfbackend        # Active backend config (gitignored)
    ├── backend-config.tfbackend.example
    │
    └── modules/
        ├── iam/
        │   ├── main.tf         # Frontend IAM role, Route53/ACM/SSM policies
        │   ├── variables.tf
        │   └── outputs.tf
        ├── ec2/
        │   ├── main.tf         # Database → Backend → Frontend EC2 instances
        │   ├── certificate-wait.tf  # null_resource polls ACM for cert ARN
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── templates/
        │       ├── database-init.sh   # PostgreSQL install + migrations
        │       ├── backend-init.sh    # Node.js 20 + PM2 + .env creation
        │       └── frontend-init.sh   # Nginx + React build + Certbot + ACM
        ├── alb/
        │   ├── main.tf         # ALB, target group, HTTP→HTTPS listener,
        │   │                   #   HTTPS listener (TLS 1.3)
        │   ├── variables.tf
        │   └── outputs.tf
        └── dns/
            ├── main.tf         # Route53 A-Alias record → ALB
            ├── variables.tf
            └── outputs.tf
```

---

## 5. Application Workflow

### User Interaction Flow

```
User fills MeasurementForm (weight, height, age, sex, activity, date)
         │
         ▼
POST /api/measurements
         │
         ▼
Express validates input → calculateMetrics() runs Mifflin-St Jeor equations
         │
         ├─ BMI  = weight_kg / (height_m)²
         ├─ BMR  = (10×weight) + (6.25×height) − (5×age) ± sex-offset
         └─ dailyCalories = BMR × activity_multiplier
         │
         ▼
INSERT INTO measurements … RETURNING *
         │
         ▼
JSON response → React updates UI with new record
         │
GET /api/measurements/trends → 30-day avg BMI per day
         │
         ▼
TrendChart renders Chart.js line graph
```

### BMI Category Mapping

| BMI Range | Category |
|-----------|----------|
| < 18.5 | Underweight |
| 18.5 – 24.9 | Normal |
| 25.0 – 29.9 | Overweight |
| ≥ 30.0 | Obese |

### Activity Multipliers (Mifflin-St Jeor)

| Level | Multiplier |
|-------|-----------|
| Sedentary | 1.200 |
| Light | 1.375 |
| Moderate | 1.550 |
| Active | 1.725 |
| Very Active | 1.900 |

### API Endpoints

| Method | Path | Description | Request Body |
|--------|------|-------------|-------------|
| `GET` | `/health` | Server health check | — |
| `POST` | `/api/measurements` | Create measurement & calculate metrics | `{ weightKg, heightCm, age, sex, activity, measurementDate }` |
| `GET` | `/api/measurements` | Retrieve all measurements (newest first) | — |
| `GET` | `/api/measurements/trends` | 30-day average BMI per day | — |

---

## 6. CI/CD Pipeline Overview

The project uses **GitHub Actions** for continuous integration and deployment, with a **self-hosted runner** installed on an EC2 instance inside the same VPC. This allows the runner to reach private-subnet resources directly and to execute Terraform commands with AWS credentials already available via IAM instance profile.

```
Developer pushes to main branch
          │
          ▼
GitHub Actions trigger (push / workflow_dispatch)
          │
          ▼
Self-hosted runner picks up the job
          │
     ┌────┴────────────────────────────────┐
     │  CI Stage                           │
     │  ├── Checkout code                  │
     │  ├── Setup Node.js 20               │
     │  ├── Install frontend dependencies  │
     │  ├── Build React production bundle  │
     │  ├── Install backend dependencies   │
     │  └── Run linting / tests            │
     └────┬────────────────────────────────┘
          │
     ┌────┴────────────────────────────────┐
     │  CD Stage (on main branch only)     │
     │  ├── Setup Terraform                │
     │  ├── terraform init (S3 backend)    │
     │  ├── terraform validate             │
     │  ├── terraform plan                 │
     │  └── terraform apply -auto-approve  │
     └────┬────────────────────────────────┘
          │
          ▼
AWS infrastructure provisioned / updated
Certbot issues Let's Encrypt cert (DNS-01 via Route53)
Certificate imported to ACM
ALB HTTPS listener activates
Application live at https://bmiostad.ostaddevops.click
```

---

## 7. GitHub Actions Workflow Explanation

The workflows live in `.github/workflows/` at the repository root.

### `deploy.yml` — Production Deployment

**Triggers:**
- `push` to the `main` branch
- `workflow_dispatch` (manual trigger from the GitHub UI)

**Key steps:**

```yaml
# Simplified representation of the workflow steps
jobs:
  deploy:
    runs-on: self-hosted          # Uses the self-hosted EC2 runner
    steps:
      - uses: actions/checkout@v4

      # --- Frontend Build ---
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
        working-directory: frontend
      - run: npm run build
        working-directory: frontend

      # --- Backend Dependency Check ---
      - run: npm ci --production
        working-directory: backend

      # --- Terraform Infrastructure ---
      - uses: hashicorp/setup-terraform@v3
        with: { terraform_version: '1.x' }
      - run: terraform init -backend-config=backend-config.tfbackend
        working-directory: terraform
      - run: terraform validate
        working-directory: terraform
      - run: terraform plan -var-file=terraform.tfvars
        working-directory: terraform
      - run: terraform apply -auto-approve -var-file=terraform.tfvars
        working-directory: terraform

      # --- Post-deploy verification ---
      - run: terraform output application_url
        working-directory: terraform
```

**Secrets used by the workflow** (configured in GitHub repository Settings → Secrets):

| Secret Name | Purpose |
|-------------|---------|
| `TF_VAR_DB_PASSWORD` | PostgreSQL database password |
| `AWS_PROFILE` or IAM role | AWS credentials for Terraform |

> **Note:** When running on a self-hosted runner with an EC2 IAM instance profile, AWS credentials are automatically available and no static `AWS_ACCESS_KEY_ID` secrets are required.

### `destroy.yml` — Infrastructure Teardown

**Triggers:** `workflow_dispatch` only (manual, requires confirmation).

```yaml
jobs:
  destroy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init -backend-config=backend-config.tfbackend
        working-directory: terraform
      - run: terraform destroy -auto-approve -var-file=terraform.tfvars
        working-directory: terraform
```

---

## 8. Self-Hosted Runner Setup

The GitHub Actions self-hosted runner is installed on an EC2 instance (or on the frontend EC2 itself) within the same VPC to enable private-network access during deployment.

### Installation Steps

```bash
# 1. On the EC2 instance — download the runner
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.x.x.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.x.x/actions-runner-linux-x64-2.x.x.tar.gz
tar xzf ./actions-runner-linux-x64-2.x.x.tar.gz

# 2. Configure — paste the token from GitHub repo
#    Settings → Actions → Runners → New self-hosted runner
./config.sh \
  --url https://github.com/sarowar-alam/terraform-3-tier-different-servers \
  --token <YOUR_REGISTRATION_TOKEN>

# 3. Install as a systemd service (auto-start on reboot)
sudo ./svc.sh install
sudo ./svc.sh start

# 4. Verify the runner is online in GitHub
#    Settings → Actions → Runners — status should show "Idle"
```

### Runner IAM Permissions

The EC2 runner instance must have an IAM role with at least the following permissions:

| Permission | Purpose |
|------------|---------|
| `ec2:*` | Manage EC2 instances |
| `elasticloadbalancing:*` | Manage ALB resources |
| `route53:*` | Manage DNS records |
| `acm:*` | Import and manage certificates |
| `iam:*` | Create roles and instance profiles |
| `s3:GetObject`, `s3:PutObject` | Terraform state operations |
| `sts:GetCallerIdentity` | AWS credential verification |

### Required Tools on the Runner

```bash
# Terraform
sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs

# AWS CLI v2
sudo apt-get install -y awscli
```

---

## 9. Deployment Process

Terraform provisions all resources in dependency order:

```
Step 1 → IAM Module
         ├── Creates frontend IAM role
         ├── Attaches Route53 policy (DNS-01 challenge)
         ├── Attaches ACM policy (certificate import)
         └── Attaches SSM managed policy (Session Manager)

Step 2 → EC2 Module
         ├── Database EC2 (user-data: database-init.sh)
         │   ├── Installs PostgreSQL
         │   ├── Creates DB/user/grants
         │   ├── Configures pg_hba.conf (VPC CIDR)
         │   └── Runs SQL migrations
         ├── Backend EC2 (depends_on: database)
         │   ├── Installs Node.js 20 + PM2
         │   ├── Clones git repo (branch: main)
         │   ├── Creates .env with DB connection string
         │   ├── npm install --production
         │   └── pm2 start + pm2 startup systemd
         └── Frontend EC2 (depends_on: backend)
             ├── Installs Nginx + Node.js 20 + Certbot
             ├── Clones git repo + npm run build
             ├── Deploys dist/ to /var/www/bmi-health-tracker
             ├── Configures Nginx (SPA routing + /api/* proxy)
             ├── Runs Certbot (DNS-01 via Route53)
             ├── Imports Let's Encrypt cert to AWS ACM
             └── Saves cert ARN to /tmp/certificate-arn.txt

Step 3 → null_resource: wait_for_certificate
         └── PowerShell loop polls ACM every 30 s (up to 10 min)
             until the Certbot-tagged certificate appears

Step 4 → ALB Module
         ├── Creates Application Load Balancer (public subnets)
         ├── Creates target group (port 80, health check /)
         ├── HTTP listener: redirect → HTTPS 301
         └── HTTPS listener: TLS 1.3, ELBSecurityPolicy-TLS13-1-2-2021-06

Step 5 → DNS Module
         └── Route53 A-Alias record → ALB (dualstack)

Step 6 → Root: aws_lb_target_group_attachment
         └── Registers frontend EC2 in the ALB target group
```

**Total deployment time:** approximately 15–20 minutes.

---

## 10. Environment Variables

### Backend `.env` (auto-generated by `backend-init.sh`)

| Variable | Example Value | Description |
|----------|--------------|-------------|
| `DATABASE_URL` | `postgresql://bmi_user:***@<DB_PRIVATE_IP>:5432/bmi_health_tracker` | Full PostgreSQL connection string |
| `DB_HOST` | `<Database EC2 private IP>` | Database host (private IP, not DNS) |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `bmi_health_tracker` | Database name |
| `DB_USER` | `bmi_user` | Database user |
| `DB_PASSWORD` | `***` | Database password — **use a strong secret** |
| `PORT` | `3000` | Express server port |
| `NODE_ENV` | `production` | Node environment |
| `FRONTEND_URL` | `https://bmiostad.ostaddevops.click` | Allowed CORS origin |
| `CORS_ORIGIN` | `*` | CORS wildcard (restrict in production) |

Template: [`backend/.env.example`](../backend/.env.example)

### Terraform Variables (`terraform.tfvars`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `aws_region` | Yes | `ap-south-1` | AWS region |
| `aws_profile` | Yes | — | AWS CLI named profile |
| `vpc_id` | Yes | — | Existing VPC ID |
| `public_subnet_ids` | Yes | — | 2× public subnet IDs (ALB) |
| `private_subnet_ids` | Yes | — | 2× private subnet IDs (EC2) |
| `alb_security_group_id` | Yes | — | SG allowing 80/443 from 0.0.0.0/0 |
| `frontend_security_group_id` | Yes | — | SG allowing :80 from ALB SG |
| `backend_security_group_id` | Yes | — | SG allowing :3000 from Frontend SG |
| `database_security_group_id` | Yes | — | SG allowing :5432 from Backend SG |
| `hosted_zone_id` | Yes | — | Route53 hosted zone ID |
| `domain_name` | Yes | — | FQDN for the application |
| `key_name` | Yes | — | EC2 key pair name |
| `git_repo_url` | Yes | — | GitHub repository HTTPS URL |
| `git_branch` | No | `main` | Branch to deploy |
| `db_name` | No | `bmidb` | PostgreSQL database name |
| `db_user` | No | `bmi_user` | PostgreSQL username |
| `db_password` | **Sensitive** | — | PostgreSQL password |
| `db_port` | No | `5432` | PostgreSQL port |
| `backend_port` | No | `3000` | Backend Express port |
| `instance_type_frontend` | No | `t3.small` | Frontend EC2 instance type |
| `instance_type_backend` | No | `t3.small` | Backend EC2 instance type |
| `instance_type_database` | No | `t3.medium` | Database EC2 instance type |
| `project_name` | No | `bmi-health-tracker` | Resource name prefix |
| `environment` | No | `production` | Environment label |
| `common_tags` | No | `{}` | Additional resource tags |

> **Security note:** Never commit `terraform.tfvars` or `backend-config.tfbackend` to version control. Both files are listed in `.gitignore`.

### S3 Backend Config (`backend-config.tfbackend`)

| Key | Value |
|-----|-------|
| `bucket` | `batch-10-tf-states` |
| `key` | `bmi-health-tracker/terraform.tfstate` |
| `region` | `ap-south-1` |
| `encrypt` | `true` |
| `profile` | `sarowar-ostad` |

---

## 11. Prerequisites

### Local Machine

| Tool | Minimum Version | Install |
|------|----------------|---------|
| Terraform | >= 1.0 | [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads) |
| AWS CLI | v2 | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| Node.js | 20.x LTS | [nodejs.org](https://nodejs.org/) |
| Git | any recent | [git-scm.com](https://git-scm.com/) |

### AWS Account Requirements

Before running `terraform apply`, the following AWS resources must exist (pre-provisioned, **not** created by this Terraform):

- [ ] VPC with DNS hostnames enabled
- [ ] 2 public subnets (for ALB) in different AZs
- [ ] 2 private subnets (for EC2) in different AZs
- [ ] NAT Gateway (allows private EC2 instances to reach the internet for `apt-get` and `git clone`)
- [ ] Security groups: ALB, Frontend, Backend, Database (with rules described in [Section 10](#10-environment-variables))
- [ ] Route53 hosted zone for your domain
- [ ] EC2 key pair (for SSH access)
- [ ] S3 bucket for Terraform state (with versioning and server-side encryption enabled)
- [ ] AWS CLI named profile configured (`aws configure --profile <profile-name>`)

---

## 12. Local Development Setup

```bash
# Clone the repository
git clone https://github.com/sarowar-alam/terraform-3-tier-different-servers.git
cd terraform-3-tier-different-servers
```

### Backend

```bash
cd backend

# Install dependencies
npm install

# Create local .env
cp .env.example .env
# Edit .env and set DATABASE_URL pointing to a local PostgreSQL instance

# Run in development mode (nodemon auto-reload)
npm run dev
# Server starts on http://localhost:3000
```

### Frontend

```bash
cd frontend

# Install dependencies
npm install

# Start Vite dev server
npm run dev
# App starts on http://localhost:5173
# API requests to /api/* are proxied to http://localhost:3000 (vite.config.js)
```

### Local Database

```bash
# Start PostgreSQL locally (Ubuntu / macOS with brew)
sudo service postgresql start   # Ubuntu
# or
brew services start postgresql  # macOS

# Create database and user
psql -U postgres << 'SQL'
CREATE DATABASE bmi_health_tracker;
CREATE USER bmi_user WITH PASSWORD 'localpassword';
GRANT ALL PRIVILEGES ON DATABASE bmi_health_tracker TO bmi_user;
\c bmi_health_tracker
GRANT ALL ON SCHEMA public TO bmi_user;
SQL

# Run migrations
psql -U bmi_user -d bmi_health_tracker -f backend/migrations/001_create_measurements.sql
psql -U bmi_user -d bmi_health_tracker -f backend/migrations/002_add_measurement_date.sql
```

---

## 13. Build and Run Instructions

### Frontend — Production Build

```bash
cd frontend
npm install
npm run build
# Output: frontend/dist/  (static files for Nginx)
```

### Backend — Production Start

```bash
cd backend
npm install --production

# Using PM2 (recommended for production)
pm2 start ecosystem.config.js
pm2 save
pm2 startup   # follow the printed command to enable on reboot

# Using Node directly
node src/server.js
```

### Nginx — Reload After Frontend Deploy

```bash
# Verify configuration
sudo nginx -t

# Copy new build
sudo cp -r frontend/dist/* /var/www/bmi-health-tracker/
sudo chown -R www-data:www-data /var/www/bmi-health-tracker/

# Reload without dropping connections
sudo systemctl reload nginx
```

---

## 14. Testing Instructions

### Manual API Testing

```bash
# Health check
curl http://localhost:3000/health

# Create a measurement
curl -X POST http://localhost:3000/api/measurements \
  -H "Content-Type: application/json" \
  -d '{
    "weightKg": 70,
    "heightCm": 175,
    "age": 30,
    "sex": "male",
    "activity": "moderate",
    "measurementDate": "2026-04-21"
  }'

# Get all measurements
curl http://localhost:3000/api/measurements

# Get 30-day trends
curl http://localhost:3000/api/measurements/trends
```

### Input Validation

The API enforces these constraints on `POST /api/measurements`:

| Field | Required | Constraints |
|-------|----------|------------|
| `weightKg` | Yes | > 0, < 1000 |
| `heightCm` | Yes | > 0, < 300 |
| `age` | Yes | > 0, < 150 |
| `sex` | Yes | `"male"` or `"female"` |
| `activity` | No | `sedentary`, `light`, `moderate`, `active`, `very_active` |
| `measurementDate` | No | Defaults to current date |

### Database Verification

```bash
# On the database EC2 instance (via SSM Session Manager)
sudo -u postgres psql -d bmi_health_tracker -c "\dt"
sudo -u postgres psql -d bmi_health_tracker -c "SELECT COUNT(*) FROM measurements;"
```

### Terraform Plan Dry-Run

```bash
cd terraform
terraform init -backend-config=backend-config.tfbackend
terraform validate
terraform plan -var-file=terraform.tfvars -out=tfplan
# Review the plan before applying
```

---

## 15. Production Deployment Steps

### First-Time Deployment

```bash
# 1. Clone repository
git clone https://github.com/sarowar-alam/terraform-3-tier-different-servers.git
cd terraform-3-tier-different-servers/terraform

# 2. Copy and populate configuration files
cp terraform.tfvars.example terraform.tfvars
cp backend-config.tfbackend.example backend-config.tfbackend

# 3. Edit terraform.tfvars with your AWS resource IDs
#    (VPC, subnets, security groups, domain, key pair, DB password)
vim terraform.tfvars

# 4. Edit backend-config.tfbackend with your S3 bucket name and profile
vim backend-config.tfbackend

# 5. Initialise Terraform with S3 backend
terraform init -backend-config=backend-config.tfbackend

# 6. Review the execution plan
terraform plan -var-file=terraform.tfvars

# 7. Apply infrastructure (takes ~15–20 minutes)
terraform apply -var-file=terraform.tfvars

# 8. Retrieve application URL
terraform output application_url
```

### Subsequent Deployments (via GitHub Actions)

Push to the `main` branch — the GitHub Actions `deploy.yml` workflow handles the rest automatically.

### Destroy Infrastructure

```bash
# WARNING: This deletes all resources including EC2 instances
cd terraform
terraform destroy -var-file=terraform.tfvars
```

Or trigger the `destroy.yml` workflow manually from the GitHub Actions tab.

### Re-running Init Scripts on Existing Instances

Each init script is saved to `/usr/local/bin/` and can be re-executed:

```bash
# Database EC2
sudo bash /usr/local/bin/init-database.sh

# Backend EC2
sudo bash /usr/local/bin/init-backend.sh

# Frontend EC2
sudo bash /usr/local/bin/init-frontend.sh
```

---

## 16. Monitoring and Logging

### Log Locations

| Component | Log Path | How to View |
|-----------|----------|-------------|
| EC2 User Data (init) | `/var/log/user-data.log` | `cat /var/log/user-data.log` |
| EC2 User Data (re-run) | `/var/log/user-data-manual.log` | `cat /var/log/user-data-manual.log` |
| Nginx Access | `/var/log/nginx/bmi-access.log` | `tail -f /var/log/nginx/bmi-access.log` |
| Nginx Error | `/var/log/nginx/bmi-error.log` | `tail -f /var/log/nginx/bmi-error.log` |
| Backend (PM2) | `/home/ubuntu/bmi-health-tracker/backend/logs/` | `pm2 logs bmi-backend` |
| PostgreSQL | `/var/log/postgresql/` | `tail -f /var/log/postgresql/postgresql-*.log` |

### Health Checks

| Endpoint | Checked By | Interval | Thresholds |
|----------|-----------|----------|-----------|
| `GET /` (frontend) | ALB Target Group | 30 s | 2 healthy / 3 unhealthy |
| `GET /health` (backend) | Manual / monitoring | — | Returns `{ "status": "ok" }` |

### PM2 Monitoring

```bash
# Live process list
pm2 list

# Real-time log stream
pm2 logs bmi-backend

# CPU / memory metrics
pm2 monit

# Application restart (zero-downtime reload)
pm2 reload bmi-backend
```

### SSL Certificate Renewal

Certbot is configured to renew certificates automatically twice daily via cron:

```
# /etc/cron.d/certbot-renew
0 0,12 * * * root certbot renew --quiet \
  --deploy-hook "systemctl reload nginx && /usr/local/bin/update-acm-cert.sh"
```

After renewal, `/usr/local/bin/update-acm-cert.sh` automatically re-imports the updated certificate to AWS ACM, keeping the ALB listener in sync.

### Recommended CloudWatch Setup (Future)

```bash
# Install CloudWatch agent on each EC2
sudo apt-get install -y amazon-cloudwatch-agent

# Suggested alarms to create via AWS Console or Terraform:
# - EC2 CPUUtilization > 80% for 5 minutes
# - ALB TargetResponseTime > 2 seconds
# - ALB UnHealthyHostCount > 0
# - ALB HTTPCode_ELB_5XX_Count > 10 per minute
# - DiskSpace /dev/xvda1 > 85%
```

---

## 17. Security Best Practices Applied

| Control | Implementation |
|---------|---------------|
| **Private subnets** | All EC2 instances placed in private subnets; only ALB is internet-facing |
| **Least-privilege security groups** | Frontend: port 80 from ALB SG only; Backend: port 3000 from Frontend SG only; Database: port 5432 from Backend SG only |
| **TLS 1.3** | ALB HTTPS listener uses `ELBSecurityPolicy-TLS13-1-2-2021-06` |
| **Encrypted EBS volumes** | All root block devices have `encrypted = true` |
| **Encrypted Terraform state** | S3 backend configured with `encrypt = true` |
| **Sensitive variables** | `db_password` declared `sensitive = true` in Terraform; never printed in plan output |
| **No hardcoded credentials** | AWS credentials via named CLI profile or EC2 IAM instance profile |
| **Least-privilege IAM** | Frontend role grants only Route53 (specific hosted zone), ACM, and SSM; no wildcard admin policies |
| **Security headers in Nginx** | `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `X-XSS-Protection: 1; mode=block` |
| **Nginx version hidden** | `server_tokens off` in Nginx config |
| **`.env` file permissions** | `chmod 600 .env` on the backend instance |
| **Auto-renewed certificates** | Certbot cron runs twice daily; ACM updated automatically on renewal |
| **HTTP → HTTPS redirect** | ALB HTTP listener issues HTTP 301 redirect to HTTPS |
| **`gitignore` protection** | `terraform.tfvars` and `backend-config.tfbackend` excluded from version control |
| **Input validation** | API validates all fields before DB insert; parameterised queries via `pg` (no SQL injection) |

---

## 18. Troubleshooting

### Application Not Loading

```bash
# 1. Check ALB target health in AWS Console
#    EC2 → Load Balancers → bmi-health-tracker-alb → Target Groups

# 2. Check Nginx status on the frontend EC2
sudo systemctl status nginx
sudo nginx -t
cat /var/log/nginx/bmi-error.log

# 3. Verify the React build is deployed
ls -la /var/www/bmi-health-tracker/
```

### API Errors (5xx)

```bash
# Check PM2 process status
pm2 list
pm2 logs bmi-backend --lines 100

# Check backend is listening
curl http://localhost:3000/health

# Restart backend
pm2 restart bmi-backend
```

### Database Connection Failures

```bash
# On the backend EC2 — test connection
psql postgresql://bmi_user:<password>@<DB_PRIVATE_IP>:5432/bmi_health_tracker -c "SELECT NOW();"

# On the database EC2 — check PostgreSQL is running
sudo systemctl status postgresql

# Verify pg_hba.conf allows VPC CIDR
cat /etc/postgresql/14/main/pg_hba.conf | grep "10.0"
```

### Certificate Not Generated

```bash
# On the frontend EC2 — check Certbot logs
cat /var/log/letsencrypt/letsencrypt.log

# Check AWS credentials are available
aws sts get-caller-identity

# Check IAM role is attached
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Re-run Certbot manually
sudo certbot certonly \
  --dns-route53 \
  -d bmiostad.ostaddevops.click \
  --preferred-challenges dns \
  --agree-tos \
  --non-interactive \
  --email admin@ostaddevops.click
```

### Terraform `wait_for_certificate` Times Out

```bash
# The null_resource polls ACM every 30 s for up to 10 minutes.
# If it times out, check the frontend EC2 user-data log:
aws ec2 get-console-output \
  --instance-id <FRONTEND_INSTANCE_ID> \
  --region ap-south-1 \
  --profile sarowar-ostad

# Or connect via SSM Session Manager:
aws ssm start-session \
  --target <FRONTEND_INSTANCE_ID> \
  --region ap-south-1 \
  --profile sarowar-ostad
```

### DNS Not Resolving

```bash
# Check Route53 record
dig bmiostad.ostaddevops.click

# Verify ALB DNS name
terraform output alb_dns_name
# Curl the ALB directly to bypass DNS
curl -H "Host: bmiostad.ostaddevops.click" http://<ALB_DNS_NAME>/health
```

### Terraform State Lock

```bash
# If a previous apply was interrupted, release the lock:
terraform force-unlock <LOCK_ID>
# Lock ID is shown in the error message
```

---

## 19. Cost Estimation

> Estimated monthly AWS costs in `ap-south-1` (Mumbai). Actual costs vary with traffic.

| Resource | Specification | Est. Monthly Cost |
|----------|--------------|------------------|
| Frontend EC2 | t3.medium (2 vCPU, 4 GB) | ~$35 |
| Backend EC2 | t3.medium (2 vCPU, 4 GB) | ~$35 |
| Database EC2 | t3.medium (2 vCPU, 4 GB) | ~$35 |
| ALB | Application Load Balancer | ~$18 |
| EBS Storage | 3× (20 GB + 30 GB) gp3 | ~$7 |
| Route53 | Hosted zone + queries | ~$1 |
| NAT Gateway | Data transfer | ~$35–50 |
| S3 (state) | < 1 MB | < $0.01 |
| **Total** | | **~$166–181/month** |

---

## 20. Future Improvements

### Application

- [ ] User authentication and session management (JWT or AWS Cognito)
- [ ] Multi-user profiles with data isolation
- [ ] Goal-setting and progress notifications
- [ ] Export measurements to CSV / PDF
- [ ] Mobile-responsive UI improvements
- [ ] Unit tests for `calculations.js` and API routes

### Infrastructure

- [ ] Auto Scaling Groups for frontend and backend tiers
- [ ] Migrate database to AWS RDS (Multi-AZ, automated backups)
- [ ] CloudFront CDN for static frontend assets
- [ ] Redis (ElastiCache) caching layer for API responses
- [ ] CloudWatch dashboards, alarms, and SNS notifications
- [ ] AWS WAF on the ALB for web application protection
- [ ] Multi-environment support (dev / staging / prod via Terraform workspaces)
- [ ] Terraform state locking with DynamoDB
- [ ] Secrets Manager or Parameter Store instead of `.env` files
- [ ] VPC Flow Logs and CloudTrail for audit compliance

---

## 21. Contributor Guidelines

1. **Fork** the repository and create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Follow the code style** of the existing files (no trailing whitespace, consistent indentation).

3. **Test locally** before opening a pull request:
   - Start backend and frontend in dev mode
   - Verify the API endpoints respond correctly
   - Run `terraform validate` and `terraform plan` for infrastructure changes

4. **Do not commit:**
   - `terraform.tfvars` (contains real AWS resource IDs)
   - `backend-config.tfbackend` (contains S3 bucket name and profile)
   - `.env` files
   - Any file containing AWS credentials or passwords

5. **Pull Request checklist:**
   - [ ] PR title describes the change clearly
   - [ ] No sensitive data included
   - [ ] `terraform validate` passes for infrastructure changes
   - [ ] `npm run build` succeeds for frontend changes
   - [ ] Description explains why the change is needed

6. **Branch naming conventions:**

   | Prefix | Use For |
   |--------|---------|
   | `feature/` | New features |
   | `fix/` | Bug fixes |
   | `infra/` | Terraform / infrastructure changes |
   | `docs/` | Documentation updates |

---

## 22. License

This project is for educational and demonstration purposes as part of the **Ostad DevOps Batch-08** course.

```
MIT License

Copyright (c) 2026 MD Sarowar Alam

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

---

## Author

**MD Sarowar Alam**
Lead DevOps Engineer, WPP Production
📧 Email: [sarowar@hotmail.com](mailto:sarowar@hotmail.com)
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/

---
