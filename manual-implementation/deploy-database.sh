#!/bin/bash
################################################################################
# Database Server Setup Script
# 
# This script installs and configures PostgreSQL for the BMI Health Tracker
# 
# Usage: sudo ./deploy-database.sh
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=================================="
echo "BMI Health Tracker - Database Setup"
echo "==================================${NC}"

# Configuration (modify these values)
DB_NAME="${DB_NAME:-bmi_db}"
DB_USER="${DB_USER:-bmi_user}"
DB_PASSWORD="${DB_PASSWORD:-0stad2025}"
DB_PORT="${DB_PORT:-5432}"
GIT_REPO="${GIT_REPO:-https://github.com/sarowar-alam/terraform-3-tier-different-servers.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}Please run as root (use sudo)${NC}"
   exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Database Name: $DB_NAME"
echo "  Database User: $DB_USER"
echo "  Database Port: $DB_PORT"
echo ""

# Update system
echo -e "${GREEN}[1/7] Updating system packages...${NC}"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install PostgreSQL
echo -e "${GREEN}[2/7] Installing PostgreSQL...${NC}"
apt-get install -y postgresql postgresql-contrib git curl

# Get PostgreSQL version
PG_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

# Start PostgreSQL
echo -e "${GREEN}[3/7] Starting PostgreSQL service...${NC}"
systemctl start postgresql
systemctl enable postgresql
sleep 5

# Create database and user
echo -e "${GREEN}[4/7] Creating database and user...${NC}"
sudo -u postgres psql <<EOF
-- Drop if exists (for re-runs)
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS $DB_USER;

-- Create database
CREATE DATABASE $DB_NAME;

-- Create user with password
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

-- Connect to database and grant schema privileges
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
EOF

# Configure PostgreSQL for network access
echo -e "${GREEN}[5/7] Configuring PostgreSQL for network access...${NC}"

# Backup original config
cp $PG_CONF $PG_CONF.backup
cp $PG_HBA $PG_HBA.backup

# Update postgresql.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF
sed -i "s/max_connections = 100/max_connections = 200/" $PG_CONF
sed -i "s/shared_buffers = 128MB/shared_buffers = 256MB/" $PG_CONF

# Update pg_hba.conf - allow connections from VPC
cat >> $PG_HBA <<EOF

# Allow connections from VPC private subnets
host    all             all             10.0.0.0/8              md5
host    all             all             172.16.0.0/12           md5
host    all             all             192.168.0.0/16          md5
EOF

# Restart PostgreSQL
echo -e "${GREEN}[6/7] Restarting PostgreSQL...${NC}"
systemctl restart postgresql
sleep 5

# Clone repository and run migrations
echo -e "${GREEN}[7/7] Running database migrations...${NC}"
cd /tmp
rm -rf bmi-app
git clone -b $GIT_BRANCH $GIT_REPO bmi-app || {
    echo -e "${RED}Failed to clone repository. Check GIT_REPO variable.${NC}"
    echo -e "${YELLOW}Skipping migrations. You can run them manually later.${NC}"
    exit 0
}

cd bmi-app/backend/migrations

for migration in *.sql; do
    if [ -f "$migration" ]; then
        echo "  Running: $migration"
        sudo -u postgres psql -d $DB_NAME -f "$migration"
    fi
done

# Cleanup
cd /tmp
rm -rf bmi-app

# Verify setup
echo -e "${GREEN}Verifying database setup...${NC}"
sudo -u postgres psql -d $DB_NAME -c "\dt" || echo -e "${YELLOW}No tables yet (normal if migrations didn't run)${NC}"

# Show connection info
PRIVATE_IP=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}"
echo "=================================="
echo "Database Setup Complete!"
echo "=================================="
echo -e "${NC}"
echo "Database Details:"
echo "  Host: $PRIVATE_IP"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Password: $DB_PASSWORD"
echo ""
echo "Connection String:"
echo "  postgresql://$DB_USER:$DB_PASSWORD@$PRIVATE_IP:$DB_PORT/$DB_NAME"
echo ""
echo "Test Connection:"
echo "  psql -h $PRIVATE_IP -U $DB_USER -d $DB_NAME"
echo ""
echo -e "${YELLOW}IMPORTANT: Save the connection details for backend configuration!${NC}"
echo ""
