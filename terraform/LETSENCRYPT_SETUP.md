# Let's Encrypt Certificate with Certbot - Implementation Guide

## Overview

This implementation uses **Let's Encrypt** certificates generated on the frontend EC2 instance using **Certbot** with the **Route53 DNS challenge**. The certificate is then automatically exported to **AWS Certificate Manager (ACM)** for use with the Application Load Balancer.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Frontend EC2 Instance                    │
│                                                              │
│  1. Certbot generates certificate                          │
│     ├─ Uses Route53 DNS challenge                          │
│     ├─ IAM role provides Route53 permissions              │
│     └─ Creates wildcard cert: *.domain.com                │
│                                                              │
│  2. Certificate stored locally                              │
│     ├─ /etc/letsencrypt/live/domain.com/fullchain.pem     │
│     └─ /etc/letsencrypt/live/domain.com/privkey.pem       │
│                                                              │
│  3. Certificate exported to ACM                            │
│     ├─ Uses aws acm import-certificate                    │
│     ├─ IAM role provides ACM permissions                  │
│     └─ Returns certificate ARN                            │
│                                                              │
│  4. Nginx configured with HTTPS                            │
│     ├─ SSL certificate paths configured                   │
│     ├─ HTTP redirects to HTTPS                            │
│     └─ TLS 1.2/1.3 enabled                                │
│                                                              │
│  5. Auto-renewal configured                                │
│     ├─ Cron job runs certbot renew                        │
│     ├─ On renewal: reloads Nginx                          │
│     └─ Updates ACM certificate                             │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │      ACM       │
                    │   Certificate  │
                    └────────┬───────┘
                             │
                             ▼
                    ┌────────────────┐
                    │      ALB       │
                    │  (uses cert)   │
                    └────────────────┘
```

## Components

### 1. IAM Module (`modules/iam/`)

**Purpose**: Provides necessary permissions for certificate management

**IAM Role**: `bmi-health-tracker-frontend-certbot-role`

**Permissions**:
- **Route53**: 
  - `route53:ListHostedZones` - List hosted zones
  - `route53:GetChange` - Get change status
  - `route53:ChangeResourceRecordSets` - Create DNS challenge records
  - `route53:ListResourceRecordSets` - List records
  
- **ACM**:
  - `acm:ImportCertificate` - Import certificate to ACM
  - `acm:ListCertificates` - List certificates
  - `acm:DescribeCertificate` - Get certificate details
  - `acm:AddTagsToCertificate` - Tag certificates

**Instance Profile**: Attached to frontend EC2 instance

### 2. Frontend Init Script (`modules/ec2/templates/frontend-init.sh`)

**Certificate Generation Process**:

```bash
# 1. Install Certbot + plugins
apt-get install -y certbot python3-certbot-dns-route53 python3-certbot-nginx awscli

# 2. Wait for IAM role propagation
sleep 30

# 3. Generate wildcard certificate
certbot certonly \
  --dns-route53 \
  -d domain.com -d "*.domain.com" \
  --preferred-challenges dns \
  --agree-tos \
  --non-interactive \
  --email admin@domain.com

# 4. Export to ACM
aws acm import-certificate \
  --certificate fileb:///etc/letsencrypt/live/domain.com/fullchain.pem \
  --private-key fileb:///etc/letsencrypt/live/domain.com/privkey.pem \
  --region us-east-1

# 5. Configure Nginx with HTTPS
# Updates Nginx config to use certificate and redirect HTTP to HTTPS

# 6. Setup auto-renewal
# Cron job: 0 0,12 * * * certbot renew --quiet --deploy-hook
```

## Certificate Details

### Generated Certificates

**Location**: `/etc/letsencrypt/live/${domain_name}/`

**Files**:
- `fullchain.pem` - Certificate + intermediate chain
- `privkey.pem` - Private key
- `cert.pem` - Certificate only
- `chain.pem` - Intermediate certificates

**Domain Coverage**:
- Primary domain: `bmi.example.com`
- Wildcard: `*.example.com` (covers all subdomains)

**Validity**: 90 days (auto-renewed at 60 days)

**Provider**: Let's Encrypt (Free)

## Nginx HTTPS Configuration

The script automatically configures Nginx with:

### HTTP Server (Port 80)
- Redirects all traffic to HTTPS (301 permanent)

### HTTPS Server (Port 443)
- **SSL Certificate**: `/etc/letsencrypt/live/domain/fullchain.pem`
- **Private Key**: `/etc/letsencrypt/live/domain/privkey.pem`
- **Protocols**: TLSv1.2, TLSv1.3
- **Ciphers**: HIGH:!aNULL:!MD5
- **HSTS**: Enabled (max-age=31536000)
- **HTTP/2**: Enabled

## Automatic Renewal

### Cron Job

**Schedule**: Twice daily at 00:00 and 12:00

**Command**: `certbot renew --quiet --deploy-hook`

**Deploy Hook**: Runs after successful renewal
1. Reloads Nginx: `systemctl reload nginx`
2. Updates ACM certificate: `/usr/local/bin/update-acm-cert.sh`

### ACM Update Script

**Location**: `/usr/local/bin/update-acm-cert.sh`

**Function**:
```bash
# Re-imports certificate to ACM with same ARN
aws acm import-certificate \
  --certificate-arn $EXISTING_ARN \
  --certificate fileb:///etc/letsencrypt/live/domain/fullchain.pem \
  --private-key fileb:///etc/letsencrypt/live/domain/privkey.pem
```

**Why**: ACM certificate must be updated separately from local Nginx certificate

## Advantages of This Approach

### ✅ Benefits

1. **Free Certificates**: Let's Encrypt is free (vs ACM requires domain validation)
2. **Wildcard Support**: Single cert covers all subdomains
3. **Full Control**: Direct access to certificates on EC2
4. **Automated Renewal**: Certbot handles renewal automatically
5. **ACM Integration**: Best of both worlds (Let's Encrypt + ACM)
6. **No Manual DNS**: Route53 plugin handles DNS challenge automatically

### ⚠️ Considerations

1. **Initial Setup Time**: 2-3 minutes for certificate generation
2. **IAM Role Required**: EC2 needs Route53 and ACM permissions
3. **Regional Limitation**: Certificate must be imported to ALB region
4. **Renewal Dependency**: If EC2 is down during renewal, manual intervention needed
5. **Single Point of Failure**: Certificate generation tied to frontend EC2

## Troubleshooting

### Certificate Generation Failed

**Symptom**: "Certificate generation failed" in user-data log

**Check**:
```bash
# 1. Verify IAM role is attached
aws sts get-caller-identity

# 2. Check Route53 permissions
aws route53 list-hosted-zones

# 3. Manual certificate generation
certbot certonly --dns-route53 -d domain.com --dry-run

# 4. View detailed logs
tail -f /var/log/letsencrypt/letsencrypt.log
```

**Common Issues**:
- IAM role not propagated yet (wait 60 seconds)
- Route53 hosted zone ID mismatch
- Domain not pointing to correct nameservers
- Rate limit exceeded (5 per domain per week)

### Certificate Not Imported to ACM

**Symptom**: Certificate generated but not in ACM

**Check**:
```bash
# 1. Verify ACM permissions
aws acm list-certificates --region us-east-1

# 2. Check certificate files exist
ls -la /etc/letsencrypt/live/domain.com/

# 3. Manual import
aws acm import-certificate \
  --certificate fileb:///etc/letsencrypt/live/domain.com/fullchain.pem \
  --private-key fileb:///etc/letsencrypt/live/domain.com/privkey.pem \
  --region us-east-1

# 4. Check for errors
tail -f /var/log/user-data.log | grep -i acm
```

### Nginx Not Using HTTPS

**Symptom**: Still serving HTTP instead of HTTPS

**Check**:
```bash
# 1. Verify Nginx config
nginx -t

# 2. Check certificate paths
ls -la /etc/letsencrypt/live/domain.com/

# 3. Reload Nginx
systemctl reload nginx

# 4. Check Nginx logs
tail -f /var/log/nginx/error.log
```

### Auto-Renewal Not Working

**Symptom**: Certificate expired

**Check**:
```bash
# 1. Test renewal
certbot renew --dry-run

# 2. Check cron job
cat /etc/cron.d/certbot-renew

# 3. View renewal logs
cat /var/log/letsencrypt/letsencrypt.log

# 4. Manual renewal
certbot renew --force-renewal
```

## Manual Operations

### Generate Certificate Manually

```bash
# SSH to frontend instance
ssh -i key.pem ubuntu@<frontend-private-ip>

# Generate certificate
sudo certbot certonly \
  --dns-route53 \
  -d bmi.example.com -d "*.example.com" \
  --preferred-challenges dns \
  --agree-tos \
  --email admin@example.com

# Import to ACM
sudo aws acm import-certificate \
  --certificate fileb:///etc/letsencrypt/live/bmi.example.com/fullchain.pem \
  --private-key fileb:///etc/letsencrypt/live/bmi.example.com/privkey.pem \
  --region us-east-1
```

### Force Certificate Renewal

```bash
# Force renewal (even if not due)
sudo certbot renew --force-renewal

# Reload Nginx
sudo systemctl reload nginx

# Update ACM
sudo /usr/local/bin/update-acm-cert.sh
```

### Revoke Certificate

```bash
# Revoke certificate
sudo certbot revoke --cert-path /etc/letsencrypt/live/domain.com/cert.pem

# Delete from ACM
aws acm delete-certificate --certificate-arn <arn> --region us-east-1
```

## Monitoring

### Check Certificate Expiry

```bash
# On EC2 instance
sudo certbot certificates

# Via ACM
aws acm describe-certificate --certificate-arn <arn> --region us-east-1 --query 'Certificate.NotAfter'
```

### View Renewal Status

```bash
# Last renewal attempt
sudo grep "Cert has been renewed" /var/log/letsencrypt/letsencrypt.log

# Next scheduled renewal
sudo certbot renew --dry-run
```

## Security Best Practices

1. **Limit IAM Permissions**: Only grant necessary Route53 and ACM permissions
2. **Restrict Certificate Access**: Only root can read private keys (600 permissions)
3. **Monitor Certificate Expiry**: Set up alerts for expiry < 30 days
4. **Rotate Certificates**: Even though auto-renewed, monitor the process
5. **Backup Certificates**: Consider backing up `/etc/letsencrypt/` directory

## Cost Comparison

| Method | Setup | Renewal | Cost |
|--------|-------|---------|------|
| Let's Encrypt + ACM | Automated | Automated | **$0** |
| ACM Only | Manual DNS validation | Auto-renewed | $0 |
| Commercial SSL | Purchase | Manual renewal | $50-300/year |

## Integration with ALB

The ALB can use the certificate in two ways:

### Option 1: Direct EC2 HTTPS (Current Implementation)
- Frontend EC2 handles HTTPS termination
- ALB forwards HTTP traffic to EC2:80
- Nginx redirects to HTTPS and serves with Let's Encrypt cert

### Option 2: ALB HTTPS Termination (Recommended for Production)
- Import Let's Encrypt cert to ACM
- ALB uses ACM certificate for HTTPS termination
- ALB forwards HTTP to EC2:80
- More scalable and manageable

To use Option 2:
1. Let frontend-init.sh complete certificate generation and ACM import
2. Update ALB HTTPS listener to use the imported certificate ARN
3. Get ARN from `/tmp/certificate-arn.txt` on frontend instance

## Terraform Changes Summary

### New Files Created:
- `modules/iam/main.tf` - IAM role and policies
- `modules/iam/variables.tf` - IAM module inputs
- `modules/iam/outputs.tf` - Instance profile name/ARN

### Modified Files:
- `modules/ec2/templates/frontend-init.sh` - Added Certbot + ACM export
- `modules/ec2/main.tf` - Added IAM instance profile
- `modules/ec2/variables.tf` - Added instance profile and region variables
- `main.tf` - Added IAM module
- `outputs.tf` - Added IAM and certificate outputs

## Testing

After deployment:

```bash
# 1. Check certificate on EC2
ssh ubuntu@frontend-ip
sudo certbot certificates

# 2. Check certificate in ACM
aws acm list-certificates --region us-east-1

# 3. Test HTTPS
curl -I https://bmi.example.com

# 4. Verify redirect
curl -I http://bmi.example.com
# Should return 301 redirect to HTTPS
```

## References

- [Certbot Documentation](https://certbot.eff.org/)
- [Certbot Route53 Plugin](https://certbot-dns-route53.readthedocs.io/)
- [AWS ACM Import](https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html)
- [Let's Encrypt](https://letsencrypt.org/)

---

**Implementation Status**: ✅ Complete

**Certificate Type**: Let's Encrypt (Free, Auto-renewed)

**Renewal**: Automated via cron (twice daily check)

**ACM Integration**: Automated export on generation and renewal

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide

📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://linkedin.com/in/sarowar)
