#!/bin/bash
################################################################################
# Backend Server Initialization Script
# Templatefile variables:
#   db_host, db_port, db_name, db_user, db_password,
#   backend_port, frontend_url, git_repo, git_branch
#
# Re-run manually:  sudo bash /usr/local/bin/init-backend.sh
################################################################################

set -e
exec > >(tee -a /var/log/user-data.log) 2>&1

echo "======================================================"
echo " Backend Server Initialization — $(date)"
echo "======================================================"

# ----------------------------------------------------------------------------
# System update
# ----------------------------------------------------------------------------
echo "[1/7] Updating system packages..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# ----------------------------------------------------------------------------
# Install packages
# ----------------------------------------------------------------------------
echo "[2/7] Installing dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  git curl build-essential netcat-openbsd

# Verify SSM agent is running (pre-installed on Ubuntu 24.04 AWS AMIs)
echo "Verifying SSM agent..."
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || true
systemctl start  snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || \
  systemctl start amazon-ssm-agent 2>/dev/null || true

# Install Node.js 20.x LTS
echo "[3/7] Installing Node.js 20.x LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null
apt-get install -y nodejs
node --version
npm  --version

# Install PM2 globally
npm install -g pm2
pm2 --version

# Ensure HOME is set — user_data runs as root and HOME may not be defined
export HOME=/root

# ----------------------------------------------------------------------------
# Wait for database to be reachable before continuing
# Polls :db_port every 10 s, max 30 attempts = up to 5 minutes
# ----------------------------------------------------------------------------
echo "[4/7] Waiting for database at ${db_host}:${db_port}..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  if nc -z -w 3 "${db_host}" "${db_port}" 2>/dev/null; then
    echo "  [$ATTEMPT/$MAX_ATTEMPTS] Database reachable — continuing"
    break
  fi
  echo "  [$ATTEMPT/$MAX_ATTEMPTS] Not reachable yet — retrying in 10 s..."
  sleep 10
done

if ! nc -z -w 3 "${db_host}" "${db_port}" 2>/dev/null; then
  echo "WARNING: Database still unreachable after $MAX_ATTEMPTS attempts."
  echo "Backend will start anyway and retry connections via pg pool."
fi

# ----------------------------------------------------------------------------
# Clone repository and configure backend
# ----------------------------------------------------------------------------
echo "[5/7] Setting up application..."
APP_DIR="/home/ubuntu/bmi-health-tracker"
mkdir -p $${APP_DIR}
cd $${APP_DIR}

git clone -b ${git_branch} ${git_repo} . || {
  echo "ERROR: Failed to clone ${git_repo}"
  exit 1
}

cd backend

# Create .env — single-quoted heredoc so bash does NOT expand dollar-signs in
# substituted values (e.g. a db_password that contains a dollar sign).
# Terraform templatefile has already replaced all template variables above.
cat > .env << 'ENV_EOF'
# Database
DATABASE_URL=postgresql://${db_user}:${db_password}@${db_host}:${db_port}/${db_name}
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}

# Server
PORT=${backend_port}
NODE_ENV=production

# CORS
FRONTEND_URL=${frontend_url}
CORS_ORIGIN=*
ENV_EOF

chmod 600 .env

# Install production dependencies
echo "Installing npm dependencies..."
npm install --production

# ----------------------------------------------------------------------------
# Start backend with PM2
# ----------------------------------------------------------------------------
echo "[6/7] Starting backend with PM2..."

# Ensure PM2 is clean before starting
pm2 delete bmi-backend 2>/dev/null || true
pm2 start src/server.js --name bmi-backend --time
pm2 save

# Register PM2 startup — grep the generated sudo command and run it directly
# (piping to tail -1 | bash breaks when output contains dollar signs)
PM2_STARTUP=$(env PATH=$${PATH}:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu 2>&1 | grep 'sudo ' | head -1 || true)
if [ -n "$${PM2_STARTUP}" ]; then
  eval "$${PM2_STARTUP}" || true
fi

# Fix ownership
chown -R ubuntu:ubuntu $${APP_DIR} 2>/dev/null || true

# ----------------------------------------------------------------------------
# Health check
# ----------------------------------------------------------------------------
echo "[7/7] Verifying backend health endpoint..."
sleep 8
for i in 1 2 3 4 5; do
  if curl -sf http://localhost:${backend_port}/health > /dev/null 2>&1; then
    echo "  Health check passed (attempt $i)"
    break
  fi
  echo "  Attempt $i — not ready yet, waiting 5 s..."
  sleep 5
done

pm2 status

# Save script for re-runs
cp "$0" /usr/local/bin/init-backend.sh 2>/dev/null || true
chmod +x /usr/local/bin/init-backend.sh 2>/dev/null || true

echo "======================================================"
echo " Backend Initialization Complete — $(date)"
echo " Host     : $(hostname -I | awk '{print $1}')"
echo " Port     : ${backend_port}"
echo " API      : http://localhost:${backend_port}/api"
echo " Health   : http://localhost:${backend_port}/health"
echo "======================================================"
pm2 list
