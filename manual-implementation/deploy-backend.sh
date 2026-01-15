#!/bin/bash
################################################################################
# Backend Server Setup Script
# 
# This script installs Node.js, clones the repository, and starts the backend
# 
# Usage: sudo ./deploy-backend.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=================================="
echo "BMI Health Tracker - Backend Setup"
echo "==================================${NC}"

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-bmi_db}"
DB_USER="${DB_USER:-bmi_user}"
DB_PASSWORD="${DB_PASSWORD:-ChangeMe123!}"
BACKEND_PORT="${BACKEND_PORT:-3000}"
FRONTEND_URL="${FRONTEND_URL:-https://bmi.ostaddevops.click}"
GIT_REPO="${GIT_REPO:-https://github.com/sarowar-alam/terraform-3-tier-different-servers.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"

# Validate required variables
if [ "$DB_HOST" == "localhost" ]; then
    echo -e "${RED}ERROR: DB_HOST not set!${NC}"
    echo "Please edit this script and set DB_HOST to your database server IP"
    echo "Example: DB_HOST=\"10.0.1.10\""
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Database Host: $DB_HOST:$DB_PORT"
echo "  Backend Port: $BACKEND_PORT"
echo "  Frontend URL: $FRONTEND_URL"
echo ""

# Update system
echo -e "${GREEN}[1/6] Updating system packages...${NC}"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install dependencies
echo -e "${GREEN}[2/6] Installing build tools...${NC}"
apt-get install -y git curl build-essential

# Install Node.js 18.x LTS
echo -e "${GREEN}[3/6] Installing Node.js 18.x LTS...${NC}"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verify installation
node --version
npm --version

# Install PM2 globally
echo -e "${GREEN}[4/6] Installing PM2 process manager...${NC}"
npm install -g pm2

# Setup application directory
echo -e "${GREEN}[5/6] Setting up application...${NC}"
APP_DIR="/home/ubuntu/app"
mkdir -p $APP_DIR
cd $APP_DIR

# Clone repository
echo "Cloning repository..."
git clone -b $GIT_BRANCH $GIT_REPO .

# Navigate to backend
cd backend

# Create .env file
echo "Creating environment configuration..."
cat > .env <<EOF
# Database Configuration
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD

# Server Configuration
PORT=$BACKEND_PORT
NODE_ENV=production

# CORS Configuration
FRONTEND_URL=$FRONTEND_URL
CORS_ORIGIN=*
EOF

# Set permissions
chmod 600 .env

# Install dependencies
echo "Installing dependencies..."
npm install --production

# Test database connection
echo "Testing database connection..."
node -e "
const { Pool } = require('pg');
const pool = new Pool({ 
    connectionString: 'postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME' 
});
pool.query('SELECT NOW()', (err, res) => {
    if (err) {
        console.error('❌ Database connection failed:', err.message);
        process.exit(1);
    }
    console.log('✅ Database connection successful:', res.rows[0].now);
    pool.end();
});
" || {
    echo -e "${YELLOW}Warning: Database connection failed. Backend will retry on startup.${NC}"
}

# Start with PM2
echo -e "${GREEN}[6/6] Starting backend with PM2...${NC}"
pm2 delete bmi-backend 2>/dev/null || true
pm2 start src/server.js --name bmi-backend --time
pm2 save
pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Setup PM2 startup
env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Change ownership
chown -R ubuntu:ubuntu $APP_DIR
chown -R ubuntu:ubuntu /home/ubuntu/.pm2

# Wait and verify
sleep 5
pm2 list

# Test health endpoint
echo "Testing backend health endpoint..."
sleep 5
curl -f http://localhost:$BACKEND_PORT/health || echo -e "${YELLOW}Warning: Health check failed${NC}"

# Show private IP
PRIVATE_IP=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}"
echo "=================================="
echo "Backend Setup Complete!"
echo "=================================="
echo -e "${NC}"
echo "Backend Details:"
echo "  Host: $PRIVATE_IP"
echo "  Port: $BACKEND_PORT"
echo "  Health: http://$PRIVATE_IP:$BACKEND_PORT/health"
echo "  API: http://$PRIVATE_IP:$BACKEND_PORT/api"
echo ""
echo "PM2 Commands:"
echo "  Status: pm2 status"
echo "  Logs: pm2 logs bmi-backend"
echo "  Restart: pm2 restart bmi-backend"
echo ""
echo -e "${YELLOW}IMPORTANT: Save this IP for frontend configuration!${NC}"
echo ""
