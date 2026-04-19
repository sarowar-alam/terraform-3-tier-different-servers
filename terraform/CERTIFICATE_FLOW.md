# Certificate Management Flow

## 🎯 **Corrected Design**

The project now uses **ONE certificate source**: **Let's Encrypt via Certbot**

---

## 📋 **What Was Wrong Before**

### ❌ **Old Flow (Duplicate Certificates)**:
1. Terraform creates AWS ACM certificate
2. Terraform creates Route53 validation records
3. ALB uses AWS ACM certificate
4. Frontend server creates Let's Encrypt certificate via Certbot
5. Certbot imports certificate to ACM
6. **Result**: TWO certificates exist, ALB uses the wrong one

### ✅ **New Flow (Single Certificate Source)**:
1. ALB starts with **HTTP only** (no certificate)
2. Frontend server uses **Certbot** to create Let's Encrypt certificate
3. Certbot **imports** certificate to ACM
4. Certificate ARN is saved to `/tmp/certificate-arn.txt`
5. **Manually update** ALB to use imported certificate (optional)

---

## 🔄 **Certificate Flow Diagram**

```
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Terraform Deploy (HTTP Only)                      │
├─────────────────────────────────────────────────────────────┤
│  • ALB created with HTTP listener (port 80)                │
│  • No HTTPS listener initially                              │
│  • No certificate created by Terraform                      │
│  • Frontend EC2 instance created with IAM role             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Frontend Instance Initialization                  │
├─────────────────────────────────────────────────────────────┤
│  • User data script runs on boot                           │
│  • Installs Certbot + Route53 plugin                       │
│  • Waits for IAM role to propagate (30s)                   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 3: Certbot Certificate Generation                    │
├─────────────────────────────────────────────────────────────┤
│  • Certbot requests Let's Encrypt certificate              │
│  • Uses DNS-01 challenge (Route53)                         │
│  • Certbot automatically:                                   │
│    - Creates TXT records in Route53                        │
│    - Validates domain ownership                            │
│    - Gets certificate from Let's Encrypt                   │
│    - Removes TXT records                                   │
│  • Certificate saved to:                                    │
│    /etc/letsencrypt/live/DOMAIN/fullchain.pem             │
│    /etc/letsencrypt/live/DOMAIN/privkey.pem               │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 4: Import Certificate to AWS ACM                     │
├─────────────────────────────────────────────────────────────┤
│  • Frontend script uses AWS CLI                            │
│  • Command: aws acm import-certificate                     │
│  • Certificate ARN returned and saved to:                  │
│    /tmp/certificate-arn.txt                                │
│  • Certificate now available in ACM console                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 5: Nginx Configuration (Frontend Server)             │
├─────────────────────────────────────────────────────────────┤
│  • Nginx configured with Let's Encrypt certificate         │
│  • HTTPS (port 443) enabled on frontend instance          │
│  • HTTP (port 80) redirects to HTTPS                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 6: Update ALB to Use Certificate (OPTIONAL/MANUAL)   │
├─────────────────────────────────────────────────────────────┤
│  1. Get certificate ARN:                                    │
│     ssh ubuntu@frontend-ip                                  │
│     cat /tmp/certificate-arn.txt                           │
│                                                             │
│  2. Edit: terraform/modules/alb/main.tf                    │
│     - Uncomment HTTPS listener                             │
│     - Add certificate ARN                                   │
│     - Change HTTP listener to redirect to HTTPS            │
│                                                             │
│  3. Apply changes:                                          │
│     terraform apply                                         │
│                                                             │
│  4. Result: End-to-end HTTPS (ALB → Frontend)             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 **Current Configuration**

### **ALB Module** (`modules/alb/main.tf`)
- ✅ HTTP listener (port 80) → Forwards to frontend
- ⏸️ HTTPS listener (port 443) → **COMMENTED OUT** (enable manually after Certbot)
- ❌ No AWS ACM certificate creation

### **Frontend Init Script** (`modules/ec2/templates/frontend-init.sh`)
- ✅ Installs Certbot with Route53 plugin
- ✅ Requests Let's Encrypt certificate
- ✅ Imports certificate to ACM
- ✅ Configures Nginx with HTTPS
- ✅ Saves certificate ARN to `/tmp/certificate-arn.txt`

### **IAM Module** (`modules/iam/main.tf`)
- ✅ Frontend instance role with:
  - Route53 permissions (for DNS-01 challenge)
  - ACM import permissions

---

## 📖 **Deployment Steps**

### **Initial Deployment**

```bash
# 1. Deploy infrastructure (HTTP only)
cd terraform
terraform init -backend-config=backend-config.tfbackend
terraform plan
terraform apply

# 2. Wait for instances to initialize (5-10 minutes)
# Monitor: AWS Console > EC2 > Instances > System Log

# 3. Check frontend logs
ssh -i ~/.ssh/your-key.pem ubuntu@<frontend-private-ip>
sudo tail -f /var/log/user-data.log

# Look for:
# - "Certificate generated successfully!"
# - "Certificate imported to ACM!"
# - "Nginx configured for HTTPS"

# 4. Get certificate ARN
cat /tmp/certificate-arn.txt
# Example output: arn:aws:acm:ap-south-1:123456789012:certificate/abc-def-123

# 5. Test application
# HTTP (works immediately): http://your-domain.com
# HTTPS: Not available at ALB level yet (only at frontend Nginx)
```

### **Enable HTTPS at ALB (Optional)**

```bash
# 1. Edit: terraform/modules/alb/main.tf
#    - Uncomment HTTPS listener section (lines ~50-60)
#    - Replace certificate ARN with value from /tmp/certificate-arn.txt
#    - Update HTTP listener to redirect to HTTPS

# 2. Apply changes
terraform apply

# 3. Test
# http://your-domain.com → Redirects to HTTPS
# https://your-domain.com → Works with Let's Encrypt certificate
```

---

## 🔄 **Certificate Renewal**

### **Automatic Renewal (Configured by Script)**

Certbot is configured to renew certificates automatically:

```bash
# Cron job (created by frontend init script):
0 0,12 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx && /usr/local/bin/update-acm-cert.sh"
```

**What happens on renewal:**
1. Certbot checks if certificate needs renewal (runs twice daily)
2. If within 30 days of expiry:
   - Requests new certificate from Let's Encrypt
   - Updates files in `/etc/letsencrypt/live/DOMAIN/`
   - Runs deploy hook:
     - Reloads Nginx
     - Updates ACM with new certificate (via script)

### **Manual Renewal (If Needed)**

```bash
# SSH to frontend instance
ssh -i ~/.ssh/your-key.pem ubuntu@<frontend-ip>

# Test renewal (dry run)
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal

# Update ACM manually
sudo /usr/local/bin/update-acm-cert.sh
```

---

## 🎯 **Advantages of This Approach**

### ✅ **Benefits:**

1. **Free SSL Certificates**: Let's Encrypt is free
2. **Automatic Renewal**: Certbot handles renewals (90-day validity)
3. **Wildcard Support**: Can request `*.domain.com` certificates
4. **Full Control**: Certificate on filesystem, can backup/transfer
5. **No Vendor Lock-in**: Not dependent on AWS ACM
6. **Flexibility**: Can use certificate on Nginx AND ALB

### ⚠️ **Considerations:**

1. **Initial Setup Time**: ~5 minutes for Certbot to run
2. **Manual ALB Update**: Need to uncomment HTTPS listener (one-time)
3. **IAM Dependencies**: Frontend needs Route53 and ACM permissions
4. **Monitoring**: Should monitor `/var/log/letsencrypt/letsencrypt.log`

---

## 🐛 **Troubleshooting**

### **Certificate Generation Failed**

```bash
# Check logs
sudo cat /var/log/user-data.log | grep -A 20 "Requesting Let's Encrypt"
sudo cat /var/log/letsencrypt/letsencrypt.log

# Common issues:
# 1. IAM role not propagated → Wait 1-2 minutes
# 2. Route53 permissions missing → Check IAM policy
# 3. Domain not pointing to Route53 → Update nameservers
# 4. Rate limit hit → Wait 1 hour, try again
```

### **Certificate Import to ACM Failed**

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check ACM permissions
aws acm list-certificates --region ap-south-1

# Manual import
sudo aws acm import-certificate \
  --certificate fileb:///etc/letsencrypt/live/DOMAIN/fullchain.pem \
  --private-key fileb:///etc/letsencrypt/live/DOMAIN/privkey.pem \
  --region ap-south-1
```

### **ALB Health Checks Failing**

```bash
# Check ALB target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region ap-south-1

# Check Nginx status on frontend
ssh ubuntu@frontend-ip
sudo systemctl status nginx
sudo nginx -t
curl -I http://localhost/
```

---

## 📚 **Additional Resources**

- **Certbot Documentation**: https://certbot.eff.org/docs/
- **Let's Encrypt Rate Limits**: https://letsencrypt.org/docs/rate-limits/
- **AWS ACM Import**: https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html
- **Certbot DNS-01 Challenge**: https://eff-certbot.readthedocs.io/en/stable/using.html#dns-plugins

---

## ✅ **Summary**

**Before (WRONG):**
- AWS ACM creates certificate
- Certbot creates certificate
- Two certificates exist
- ALB uses wrong one

**After (CORRECT):**
- Only Certbot creates certificate
- Certificate imported to ACM
- One certificate source
- ALB can optionally use imported certificate

**Application works on HTTP immediately, HTTPS can be enabled after Certbot completes (optional).**

---

*MD Sarowar Alam*  
Lead DevOps Engineer, WPP Production
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/

---
