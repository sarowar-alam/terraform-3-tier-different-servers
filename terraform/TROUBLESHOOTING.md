# Troubleshooting EC2 User Data Scripts

## 🔍 Check If Scripts Ran Successfully

### 1. Check User Data Logs

```bash
# SSH into the instance
ssh -i "your-key.pem" ubuntu@<instance-ip>

# View the complete user data log
sudo cat /var/log/user-data.log

# Follow log in real-time (if script is still running)
sudo tail -f /var/log/user-data.log

# Check for errors
sudo grep -i error /var/log/user-data.log
sudo grep -i failed /var/log/user-data.log
```

### 2. Check Cloud-Init Status

```bash
# Check cloud-init status
sudo cloud-init status

# View cloud-init logs
sudo cat /var/log/cloud-init-output.log

# Detailed cloud-init logs
sudo cat /var/log/cloud-init.log
```

### 3. Check Service Status

**Database Server:**
```bash
sudo systemctl status postgresql
sudo -u postgres psql -c "\l"  # List databases
```

**Backend Server:**
```bash
pm2 list
pm2 logs
sudo systemctl status pm2-ubuntu
```

**Frontend Server:**
```bash
sudo systemctl status nginx
curl -I http://localhost/
ls -la /var/www/bmi-health-tracker/
```

---

## 🔄 Re-running Scripts After Failure

### **Option 1: Use Saved Scripts** ⭐ Recommended

Each init script is automatically saved to `/usr/local/bin/` for easy re-runs:

```bash
# Database Server
sudo bash /usr/local/bin/init-database.sh

# Backend Server
sudo bash /usr/local/bin/init-backend.sh

# Frontend Server
sudo bash /usr/local/bin/init-frontend.sh
```

Logs for manual runs go to: `/var/log/user-data-manual.log`

### **Option 2: Run Original User Data Script**

```bash
# Find and run the original user data
sudo bash /var/lib/cloud/instances/*/user-data.txt
```

### **Option 3: Force Re-run on Reboot**

```bash
# Clean cloud-init state (forces re-run on next boot)
sudo cloud-init clean --logs

# Reboot the instance
sudo reboot
```

⚠️ **Note**: This will re-run ALL cloud-init stages, including user data

### **Option 4: Terraform Taint (Recreate Instance)**

```powershell
# From your terraform directory
cd terraform

# Mark instance for recreation
terraform taint module.ec2.aws_instance.database
# or
terraform taint module.ec2.aws_instance.backend
# or
terraform taint module.ec2.aws_instance.frontend

# Apply changes (will destroy and recreate)
terraform apply
```

⚠️ **WARNING**: This DESTROYS the instance and creates a new one!
- All data on the instance will be lost
- New private/public IP addresses will be assigned
- Dependent resources may need to be updated

---

## 🐛 Common Issues and Solutions

### Issue 1: Package Installation Fails

**Symptom**: `apt-get` errors in logs

**Solution**:
```bash
# Update package lists
sudo apt-get update

# Fix broken dependencies
sudo apt-get install -f

# Re-run the init script
sudo bash /usr/local/bin/init-<server>.sh
```

### Issue 2: Git Clone Fails

**Symptom**: "fatal: could not read from remote repository"

**Solution**:
```bash
# Check if git is installed
git --version

# Test repository access
git ls-remote https://github.com/your-repo.git

# Clone manually
cd /home/ubuntu
git clone -b main https://github.com/your-repo.git bmi-health-tracker
```

### Issue 3: Database Connection Fails

**Symptom**: Backend can't connect to database

**Solution**:
```bash
# On database server - check PostgreSQL is listening
sudo netstat -plnt | grep 5432
sudo ss -tlnp | grep 5432

# Check pg_hba.conf allows backend IP
sudo cat /etc/postgresql/*/main/pg_hba.conf | grep "10.0"

# Test connection from backend server
psql -h <db-private-ip> -U bmi_user -d bmidb -W
```

### Issue 4: PM2 Not Starting

**Symptom**: Backend not running, PM2 empty list

**Solution**:
```bash
# Check if Node.js is installed
node --version
npm --version

# Navigate to backend directory
cd /home/ubuntu/bmi-health-tracker/backend

# Check .env file exists
cat .env

# Start manually
pm2 start src/server.js --name bmi-backend
pm2 save
```

### Issue 5: Nginx 502 Bad Gateway

**Symptom**: Frontend loads but API calls fail

**Solution**:
```bash
# Check Nginx error logs
sudo tail -f /var/log/nginx/bmi-error.log

# Test backend directly
curl http://<backend-private-ip>:3000/health

# Check Nginx config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### Issue 6: Let's Encrypt Certificate Fails

**Symptom**: HTTPS not working, certificate errors

**Solution**:
```bash
# Check IAM role is attached to instance
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Test AWS credentials
aws sts get-caller-identity

# Check Route53 permissions
aws route53 list-hosted-zones

# Manually request certificate
sudo certbot certonly \
  --dns-route53 \
  -d your-domain.com \
  --agree-tos \
  --non-interactive \
  --email admin@your-domain.com
```

---

## 📊 Monitoring Script Progress

### Real-time Monitoring

```bash
# Watch user data log
watch -n 5 'tail -20 /var/log/user-data.log'

# Monitor system resources
htop

# Check network connectivity
ping -c 3 google.com
curl -I https://github.com
```

### Check Completion Status

Look for these messages at the end of `/var/log/user-data.log`:

**Database:**
```
Database Server Initialization Complete
Completed: <timestamp>
```

**Backend:**
```
Backend Server Initialization Complete
Completed: <timestamp>
```

**Frontend:**
```
Frontend Server Initialization Complete
Completed: <timestamp>
```

---

## 🔐 Security Note

The saved scripts in `/usr/local/bin/` contain sensitive information:
- Database passwords
- API keys (if any)

**Best Practices:**
1. Restrict file permissions:
   ```bash
   sudo chmod 700 /usr/local/bin/init-*.sh
   ```

2. Delete after successful deployment:
   ```bash
   sudo rm /usr/local/bin/init-*.sh
   ```

3. Use AWS Secrets Manager for production:
   - Store credentials in Secrets Manager
   - Fetch them in init scripts
   - Never hardcode in Terraform

---

## 📝 Adding Custom Monitoring

Want notifications when scripts fail? Add to the end of each init script:

```bash
# At the end of init script
if [ $? -eq 0 ]; then
    aws sns publish \
      --topic-arn "arn:aws:sns:region:account:topic" \
      --message "✅ Script completed successfully" \
      --subject "EC2 Init: SUCCESS"
else
    aws sns publish \
      --topic-arn "arn:aws:sns:region:account:topic" \
      --message "❌ Script failed" \
      --subject "EC2 Init: FAILED"
fi
```

---

## 🚨 Emergency Recovery

If all else fails:

1. **Snapshot the volume** (preserve data):
   ```bash
   aws ec2 create-snapshot \
     --volume-id vol-xxxxx \
     --description "Before recovery"
   ```

2. **Create new instance from snapshot**

3. **Use `terraform import`** to bring it under Terraform management:
   ```bash
   terraform import module.ec2.aws_instance.database i-xxxxx
   ```

---

## 📞 Need Help?

1. Check logs: `/var/log/user-data.log`
2. Check cloud-init: `/var/log/cloud-init-output.log`
3. Re-run script: `sudo bash /usr/local/bin/init-<server>.sh`
4. Review this guide
5. Check AWS Console > EC2 > Instance > System Log
