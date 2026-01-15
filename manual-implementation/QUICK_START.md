# Manual Deployment - Quick Reference

## 📁 Files in This Folder

```
manual-implementation/
├── README.md              ← Complete step-by-step guide (start here!)
├── deploy-database.sh     ← Run on database server
├── deploy-backend.sh      ← Run on backend server
└── deploy-frontend.sh     ← Run on frontend server
```

## 🚀 Deployment Flow

### 1. Manual AWS Setup (AWS Console)
- Create 4 Security Groups (database, backend, frontend, alb)
- Create 1 IAM Role (for certbot)
- Launch 3 EC2 Instances (Ubuntu 22.04 LTS)

### 2. Application Deployment (Scripts)
```bash
# On database server:
git clone https://github.com/sarowar-alam/terraform-3-tier-different-servers.git
cd terraform-3-tier-different-servers/manual-implementation
nano deploy-database.sh  # Edit DB_PASSWORD
sudo ./deploy-database.sh

# On backend server:
git clone https://github.com/sarowar-alam/terraform-3-tier-different-servers.git
cd terraform-3-tier-different-servers/manual-implementation
nano deploy-backend.sh   # Edit DB_HOST, DB_PASSWORD
sudo ./deploy-backend.sh

# On frontend server:
git clone https://github.com/sarowar-alam/terraform-3-tier-different-servers.git
cd terraform-3-tier-different-servers/manual-implementation
nano deploy-frontend.sh  # Edit BACKEND_HOST, DOMAIN
sudo ./deploy-frontend.sh
```

### 3. SSL Certificate (Manual Commands)
```bash
# On frontend server:
sudo apt install certbot python3-certbot-dns-route53

DOMAIN="bmi.ostaddevops.click"
sudo certbot certonly --dns-route53 --non-interactive \
  --agree-tos --email admin@$DOMAIN -d $DOMAIN

sudo aws acm import-certificate \
  --certificate fileb:///etc/letsencrypt/live/$DOMAIN/cert.pem \
  --private-key fileb:///etc/letsencrypt/live/$DOMAIN/privkey.pem \
  --certificate-chain fileb:///etc/letsencrypt/live/$DOMAIN/chain.pem \
  --region ap-south-1
```

### 4. Load Balancer & DNS (AWS Console)
- Create Target Group (HTTP:80) with frontend instance
- Create Application Load Balancer
  - HTTP:80 → Redirect to HTTPS:443
  - HTTPS:443 → Forward to target group (with imported certificate)
- Create Route53 A record (alias to ALB)

## ⏱️ Estimated Time

| Phase | Time | Method |
|-------|------|--------|
| Security Groups | 10 min | Manual (AWS Console) |
| IAM Role | 5 min | Manual (AWS Console) |
| EC2 Instances | 15 min | Manual (AWS Console) |
| Database Deploy | 10 min | Script |
| Backend Deploy | 10 min | Script |
| Frontend Deploy | 10 min | Script |
| SSL Certificate | 15 min | Manual Commands |
| Load Balancer | 20 min | Manual (AWS Console) |
| DNS Configuration | 5 min | Manual (AWS Console) |
| **Total** | **~2 hours** | |

## 🔑 Key Information to Save

```bash
# After creating instances:
DATABASE_IP=10.0.X.X
BACKEND_IP=10.0.Y.Y
FRONTEND_IP=10.0.Z.Z

# After database setup:
DB_NAME="bmi_db"
DB_USER="bmi_user"
DB_PASSWORD="YourPassword"
CONNECTION_STRING="postgresql://bmi_user:YourPassword@10.0.X.X:5432/bmi_db"

# After certificate import:
CERT_ARN="arn:aws:acm:ap-south-1:XXXX:certificate/YYYY"

# After ALB creation:
ALB_DNS_NAME="bmi-alb-123456.ap-south-1.elb.amazonaws.com"
```

## 📋 Checklist

### AWS Infrastructure
- [ ] bmi-database-sg (PostgreSQL:5432, SSH:22)
- [ ] bmi-backend-sg (TCP:3000, SSH:22)
- [ ] bmi-frontend-sg (HTTP:80, SSH:22)
- [ ] bmi-alb-sg (HTTP:80, HTTPS:443 from 0.0.0.0/0)
- [ ] bmi-certbot-role (IAM role for Route53 & ACM)
- [ ] bmi-database instance (Ubuntu 22.04, private subnet)
- [ ] bmi-backend instance (Ubuntu 22.04, private subnet)
- [ ] bmi-frontend instance (Ubuntu 22.04, private subnet, IAM role attached)

### Application Deployment
- [ ] Database: PostgreSQL installed and running
- [ ] Database: Migrations completed
- [ ] Backend: PM2 running with bmi-backend process
- [ ] Backend: Health check returns `{"status":"ok"}`
- [ ] Frontend: Nginx running and serving application
- [ ] Frontend: Can access http://localhost

### SSL & Load Balancer
- [ ] Certificate: Created with Let's Encrypt
- [ ] Certificate: Imported to ACM (ARN saved)
- [ ] Target Group: Created with frontend instance
- [ ] ALB: Created in public subnets
- [ ] ALB Listener: HTTP:80 → Redirect to HTTPS
- [ ] ALB Listener: HTTPS:443 → Forward to target group
- [ ] DNS: A record pointing to ALB

### Final Verification
- [ ] Can access https://bmi.ostaddevops.click
- [ ] HTTP redirects to HTTPS
- [ ] Application loads successfully
- [ ] Can calculate BMI (database working)
- [ ] No browser certificate warnings

## 🆘 Troubleshooting

### Script fails to run
```bash
chmod +x deploy-*.sh
sudo ./deploy-database.sh
```

### Can't connect to database from backend
```bash
# Test from backend server:
telnet $DATABASE_IP 5432
# Should connect (Ctrl+] then 'quit' to exit)
```

### Frontend can't reach backend
```bash
# Test from frontend server:
curl http://$BACKEND_IP:3000/api/health
```

### Certificate import fails
```bash
# Check IAM role is attached
aws sts get-caller-identity

# Verify certificate files exist
sudo ls -la /etc/letsencrypt/live/$DOMAIN/
```

## 📚 Full Documentation

See [README.md](README.md) for complete step-by-step instructions with screenshots and detailed explanations.

## 🔗 Repository

https://github.com/sarowar-alam/terraform-3-tier-different-servers

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide

📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://linkedin.com/in/sarowar)
