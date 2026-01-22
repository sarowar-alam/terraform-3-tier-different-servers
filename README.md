# BMI Health Tracker - 3-Tier AWS Deployment

A full-stack health and fitness tracking application deployed as a 3-tier architecture on AWS using Terraform Infrastructure as Code.

## Project Overview

This project consists of two main components:

1. **Application** - A BMI (Body Mass Index) and health metrics tracking web application
2. **Infrastructure** - Terraform configuration for automated AWS deployment

### Application Stack

- **Frontend**: React 18 + Vite - Single Page Application
- **Backend**: Node.js 18 + Express - RESTful API
- **Database**: PostgreSQL 14 - Relational database
- **Process Management**: PM2 - Node.js process manager
- **Web Server**: Nginx - Reverse proxy and static file serving

### Infrastructure Stack

- **Cloud Provider**: AWS
- **Infrastructure as Code**: Terraform (modular architecture)
- **Load Balancing**: Application Load Balancer (ALB) with HTTPS
- **DNS**: Route53 with auto-validated ACM certificates
- **Compute**: EC2 instances in private subnets
- **State Management**: S3 backend with named profile support

## Features

### Application Features

- 📊 **BMI Calculation** - Calculate Body Mass Index from height and weight
- 🔥 **BMR Calculation** - Basal Metabolic Rate using Mifflin-St Jeor equation
- 🍎 **Calorie Tracking** - Daily calorie needs based on activity level
- 📈 **Trend Analysis** - 30-day BMI trends with interactive charts
- 📝 **Historical Records** - Track measurements over time
- 🎯 **BMI Categories** - Underweight, Normal, Overweight, Obese classification

### Infrastructure Features

- 🔒 **Secure Architecture** - All compute in private subnets
- 🌐 **HTTPS Support** - Auto-validated SSL/TLS certificates
- ⚖️ **Load Balanced** - High availability with ALB
- 🤖 **Automated Deployment** - Zero-touch infrastructure provisioning
- 📦 **Modular Design** - Reusable Terraform modules
- 🏷️ **Tagging Strategy** - Comprehensive resource tagging
- 🔐 **Encrypted Storage** - EBS volumes with encryption enabled

## Architecture

```
                          ┌─────────────────┐
                          │   Route53 DNS   │
                          │   + ACM Cert    │
                          └────────┬────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │  Application Load Balancer  │
                    │      (Public Subnets)       │
                    └──────────────┬──────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │              Private Network (VPC)                  │
        │                                                      │
        │  ┌─────────────┐   ┌─────────────┐   ┌───────────┐│
        │  │  Frontend   │──▶│   Backend   │──▶│ Database  ││
        │  │   Nginx     │   │  Node.js    │   │PostgreSQL ││
        │  │   React     │   │   Express   │   │           ││
        │  │  Port: 80   │   │  Port: 3000 │   │Port: 5432 ││
        │  └─────────────┘   └─────────────┘   └───────────┘│
        │                                                      │
        └──────────────────────────────────────────────────────┘
```

## Project Structure

```
terraform-3-tier-different-servers/
├── README.md                          # This file
├── IMPLEMENTATION_AUTO.sh             # Legacy automated deployment script
│
├── frontend/                          # React Frontend Application
│   ├── src/
│   │   ├── App.jsx                   # Main application component
│   │   ├── api.js                    # API client configuration
│   │   ├── components/
│   │   │   ├── MeasurementForm.jsx   # Add measurement form
│   │   │   └── TrendChart.jsx        # BMI trend visualization
│   │   └── ...
│   ├── index.html
│   ├── package.json
│   └── vite.config.js                # Vite build configuration
│
├── backend/                           # Node.js Backend API
│   ├── src/
│   │   ├── server.js                 # Express server setup
│   │   ├── routes.js                 # API route handlers
│   │   ├── db.js                     # PostgreSQL connection pool
│   │   └── calculations.js           # BMI/BMR calculations
│   ├── migrations/                   # Database migrations
│   │   ├── 001_create_measurements.sql
│   │   └── 002_add_measurement_date.sql
│   ├── ecosystem.config.js           # PM2 configuration
│   └── package.json
│
├── database/                          # Database Setup
│   └── setup-database.sh             # PostgreSQL initialization script
│
└── terraform/                         # Infrastructure as Code
    ├── README.md                     # Detailed deployment guide
    ├── QUICK_START.md                # 5-minute quick start
    ├── DEPLOYMENT_CHECKLIST.md       # Pre-deployment verification
    ├── IMPLEMENTATION_SUMMARY.md     # Architecture overview
    ├── VARIABLES_REFERENCE.md        # Variable documentation
    │
    ├── main.tf                       # Root module
    ├── variables.tf                  # Input variables
    ├── outputs.tf                    # Output values
    ├── backend.tf                    # S3 state backend
    ├── terraform.tfvars.example      # Configuration template
    ├── backend-config.tfbackend.example
    ├── deploy.sh                     # Automated deployment helper
    │
    └── modules/                      # Terraform modules
        ├── alb/                      # Application Load Balancer
        ├── dns/                      # Route53 DNS records
        └── ec2/                      # EC2 compute instances
            └── templates/            # User data scripts
                ├── database-init.sh  # PostgreSQL setup
                ├── backend-init.sh   # Node.js/PM2 setup
                └── frontend-init.sh  # Nginx/React setup
```

## Quick Start

### Prerequisites

- AWS account with VPC, subnets, security groups configured
- AWS CLI with named profile
- Terraform >= 1.0
- Route53 hosted zone
- EC2 key pair
- S3 bucket for Terraform state

### Deploy Infrastructure

```bash
# Navigate to terraform directory
cd terraform/

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
cp backend-config.tfbackend.example backend-config.tfbackend

# Edit with your AWS values
vim terraform.tfvars
vim backend-config.tfbackend

# Initialize and deploy
terraform init -backend-config=backend-config.tfbackend
terraform plan
terraform apply
```

**Deployment time:** 15-20 minutes (infrastructure + application initialization)

### Access Application

```bash
# Get application URL
terraform output application_url

# Visit in browser
# https://your-domain.com
```

## Documentation

### Application Documentation

- **Frontend Code**: See [frontend/src/](frontend/src/)
- **Backend API**: See [backend/src/](backend/src/)
- **Database Schema**: See [backend/migrations/](backend/migrations/)

### Infrastructure Documentation

- **[terraform/README.md](terraform/README.md)** - Comprehensive deployment guide with troubleshooting
- **[terraform/QUICK_START.md](terraform/QUICK_START.md)** - 5-minute quick start guide
- **[terraform/DEPLOYMENT_CHECKLIST.md](terraform/DEPLOYMENT_CHECKLIST.md)** - Pre-deployment verification checklist
- **[terraform/IMPLEMENTATION_SUMMARY.md](terraform/IMPLEMENTATION_SUMMARY.md)** - Complete architecture overview
- **[terraform/VARIABLES_REFERENCE.md](terraform/VARIABLES_REFERENCE.md)** - Detailed variable documentation

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| POST | `/api/measurements` | Create new measurement |
| GET | `/api/measurements` | Get all measurements |
| GET | `/api/measurements/trends` | Get 30-day BMI trends |

## Database Schema

**measurements** table:
- `id` - Serial primary key
- `weight_kg` - Numeric(5,2) - Weight in kilograms
- `height_cm` - Numeric(5,2) - Height in centimeters
- `age` - Integer - Age in years
- `sex` - Varchar(10) - Biological sex (male/female)
- `activity_level` - Varchar(30) - Physical activity level
- `bmi` - Numeric(4,1) - Calculated BMI
- `bmi_category` - Varchar(30) - BMI classification
- `bmr` - Integer - Basal Metabolic Rate
- `daily_calories` - Integer - Daily calorie needs
- `measurement_date` - Date - Measurement date
- `created_at` - Timestamptz - Record creation timestamp

## Technology Details

### Frontend
- **Framework**: React 18.2.0 with Hooks
- **Build Tool**: Vite 5.0.0 (fast HMR, optimized builds)
- **HTTP Client**: Axios 1.4.0
- **Charts**: Chart.js 4.4.0 + react-chartjs-2 5.2.0
- **Styling**: Custom CSS with modern features

### Backend
- **Runtime**: Node.js 18 LTS
- **Framework**: Express 4.18.2
- **Database Driver**: pg (node-postgres) 8.10.0
- **CORS**: cors 2.8.5
- **Environment**: dotenv 16.0.0
- **Process Manager**: PM2 for production

### Database
- **RDBMS**: PostgreSQL 14
- **Connection**: Pool-based (max 20 connections)
- **Migrations**: SQL-based migration system
- **Indexing**: Optimized indexes on date and BMI columns

### Infrastructure
- **IaC Tool**: Terraform >= 1.0
- **Provider**: AWS Provider ~> 5.0
- **State Backend**: S3 with encryption
- **Modules**: Custom reusable modules

## Deployment Options

### 1. Terraform (Recommended)
- **Automated**: Complete infrastructure provisioning
- **Repeatable**: Infrastructure as Code
- **Scalable**: Easy to modify and extend
- **Documentation**: [terraform/README.md](terraform/README.md)

### 2. Manual Deployment
- **Script**: Use [IMPLEMENTATION_AUTO.sh](IMPLEMENTATION_AUTO.sh)
- **Target**: Single EC2 instance or manual 3-tier setup
- **Use Case**: Testing or simple deployments

## Cost Estimation

**AWS Monthly Costs (us-east-1):**

| Resource | Specification | Cost |
|----------|--------------|------|
| Frontend EC2 | t3.small | ~$15 |
| Backend EC2 | t3.small | ~$15 |
| Database EC2 | t3.medium | ~$30 |
| Application Load Balancer | ALB | ~$16 |
| EBS Storage | 70 GB gp3 | ~$7 |
| Route53 | Hosted zone | ~$1 |
| Data Transfer | Variable | ~$10-20 |
| **Total** | | **~$95-105/month** |

## Security Features

- ✅ All compute instances in private subnets
- ✅ HTTPS/TLS 1.3 with auto-renewed ACM certificates
- ✅ Least-privilege security group rules
- ✅ EBS volume encryption enabled
- ✅ Database password marked as sensitive
- ✅ Encrypted Terraform state in S3
- ✅ No hardcoded credentials in code

## Monitoring & Maintenance

### Health Checks
- **ALB**: Monitors frontend on port 80 every 30 seconds
- **Backend**: Health endpoint at `/health`
- **Database**: Connection pool monitoring

### Logs
- **Frontend**: `/var/log/nginx/bmi-access.log`, `/var/log/nginx/bmi-error.log`
- **Backend**: PM2 logs via `pm2 logs bmi-backend`
- **Database**: PostgreSQL logs in `/var/log/postgresql/`
- **Deployment**: `/var/log/user-data.log` on each instance

### Maintenance Tasks
- Regular security updates: `apt-get update && apt-get upgrade`
- Database backups: Implement automated backup strategy
- Log rotation: Configured via logrotate
- Monitoring: Set up CloudWatch alarms (recommended)

## Troubleshooting

### Application Issues
- Check backend logs: `pm2 logs bmi-backend`
- Check database connection: `psql -h localhost -U bmi_user -d bmidb`
- Check Nginx configuration: `nginx -t`

### Infrastructure Issues
- View instance logs: `aws ec2 get-console-output --instance-id <id>`
- Check target health: Via ALB Target Groups in AWS Console
- Verify security groups: Ensure proper ingress/egress rules
- DNS issues: `dig your-domain.com` to verify DNS resolution

For detailed troubleshooting, see [terraform/README.md](terraform/README.md).

## Future Enhancements

### Application
- [ ] User authentication and authorization
- [ ] Multi-user support with profiles
- [ ] Goal setting and tracking
- [ ] Export data to CSV/PDF
- [ ] Mobile responsive design improvements

### Infrastructure
- [ ] Auto Scaling Groups for high availability
- [ ] Multi-AZ database with RDS
- [ ] CloudWatch dashboards and alarms
- [ ] CI/CD pipeline with GitHub Actions
- [ ] Multi-environment support (dev/staging/prod)
- [ ] Redis caching layer
- [ ] CloudFront CDN for static assets

## Support & Contact

For issues or questions:
1. Check [terraform/README.md](terraform/README.md) troubleshooting section
2. Review CloudWatch logs in AWS Console
3. Verify security group configurations
4. Check instance system logs

---

**Project Status**: ✅ Production Ready

**Last Updated**: January 15, 2026

**Terraform Version**: >= 1.0

**AWS Provider**: ~> 5.0

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide

📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://linkedin.com/in/sarowar)
