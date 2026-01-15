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

# Detect actual user (not root)
if [ "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
elif [ "$USER" != "root" ]; then
    ACTUAL_USER="$USER"
    ACTUAL_HOME="$HOME"
else
    ACTUAL_USER="ubuntu"
    ACTUAL_HOME="/home/ubuntu"
fi

echo -e "${YELLOW}Running as: $(whoami), App user: $ACTUAL_USER${NC}"

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-bmi_db}"
DB_USER="${DB_USER:-bmi_user}"
DB_PASSWORD="${DB_PASSWORD:-0stad2025}"
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

# Install Node.js 20.x LTS
echo -e "${GREEN}[3/6] Installing Node.js 20.x LTS...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Verify installation
node --version
npm --version

# Install PM2 globally
echo -e "${GREEN}[4/6] Installing PM2 process manager...${NC}"
npm install -g pm2

# Setup application directory
echo -e "${GREEN}[5/6] Setting up application...${NC}"
APP_DIR="$ACTUAL_HOME/app"

# Check if directory exists and handle accordingly
if [ -d "$APP_DIR" ]; then
    echo "App directory exists, checking for git repository..."
    if [ -d "$APP_DIR/.git" ]; then
        echo "Git repository found, pulling latest changes..."
        cd $APP_DIR
        git fetch origin
        git reset --hard origin/$GIT_BRANCH
        git pull origin $GIT_BRANCH
    else
        echo "Not a git repository, removing and cloning fresh..."
        rm -rf $APP_DIR
        mkdir -p $APP_DIR
        cd $APP_DIR
        git clone -b $GIT_BRANCH $GIT_REPO .
    fi
else
    echo "Creating new app directory..."
    mkdir -p $APP_DIR
    cd $APP_DIR
    git clone -b $GIT_BRANCH $GIT_REPO .
fi

# Navigate to backend
cd $APP_DIR/backend

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

# Delete old PM2 process if exists
su - $ACTUAL_USER -c "pm2 delete bmi-backend" 2>/dev/null || true

# Start application as the actual user
su - $ACTUAL_USER -c "cd $APP_DIR/backend && pm2 start src/server.js --name bmi-backend --time"
su - $ACTUAL_USER -c "pm2 save"

# Setup PM2 startup (run as root)
env PATH=$PATH:/usr/bin pm2 startup systemd -u $ACTUAL_USER --hp $ACTUAL_HOME

# Change ownership to actual user
chown -R $ACTUAL_USER:$ACTUAL_USER $APP_DIR

# Verify PM2 directory exists and has correct permissions
if [ -d "$ACTUAL_HOME/.pm2" ]; then
    chown -R $ACTUAL_USER:$ACTUAL_USER $ACTUAL_HOME/.pm2
fi

# Wait and verify
sleep 5
su - $ACTUAL_USER -c "pm2 list"

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
