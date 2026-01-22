#!/bin/bash
################################################################################
# Database Server Initialization Script
# This script sets up PostgreSQL and initializes the BMI database
#
# To re-run this script after initial boot:
#   sudo bash /usr/local/bin/init-database.sh
################################################################################

set -e

# Logging
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "=================================="
echo "Database Server Initialization"
echo "Started: $(date)"
echo "=================================="

# Save this script to /usr/local/bin for manual re-runs
if [ ! -f /usr/local/bin/init-database.sh ]; then
    cat <<'SCRIPT_EOF' > /usr/local/bin/init-database.sh
#!/bin/bash
# This is a saved copy of the user-data script
# Run with: sudo bash /usr/local/bin/init-database.sh
exec > >(tee -a /var/log/user-data-manual.log)
exec 2>&1
set -e
SCRIPT_EOF
    
    # Append the rest of this script
    tail -n +32 "$$0" >> /usr/local/bin/init-database.sh 2>/dev/null || true
    chmod +x /usr/local/bin/init-database.sh
    echo "Script saved to /usr/local/bin/init-database.sh for manual re-runs"
fi

# Update system
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install required packages
echo "Installing PostgreSQL (default version)..."
apt-get install -y postgresql postgresql-contrib git curl

# Note: Installs PostgreSQL 16 on Ubuntu 24.04, PostgreSQL 15 on Ubuntu 22.04

# Configure PostgreSQL
echo "Configuring PostgreSQL..."

# Start PostgreSQL service
systemctl start postgresql
systemctl enable postgresql

# Wait for PostgreSQL to be ready
sleep 5

# Create database and user
echo "Creating database and user..."
sudo -u postgres psql << EOF
-- Create database
CREATE DATABASE ${db_name};

-- Create user
CREATE USER ${db_user} WITH PASSWORD '${db_password}';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};

-- Connect to the database and grant schema privileges
\c ${db_name}
GRANT ALL ON SCHEMA public TO ${db_user};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${db_user};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${db_user};
EOF

# Configure PostgreSQL to listen on all interfaces
# Ubuntu 22.04 installs PostgreSQL 14 by default
PG_VERSION="14"
PG_CONF="/etc/postgresql/$${PG_VERSION}/main/postgresql.conf"
PG_HBA="/etc/postgresql/$${PG_VERSION}/main/pg_hba.conf"

echo "Configuring PostgreSQL connection settings..."

# Update postgresql.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $${PG_CONF}
sed -i "s/max_connections = 100/max_connections = 200/" $${PG_CONF}
sed -i "s/shared_buffers = 128MB/shared_buffers = 256MB/" $${PG_CONF}

# Update pg_hba.conf to allow connections from VPC
echo "host    all             all             10.0.0.0/8              md5" >> $${PG_HBA}
echo "host    all             all             172.16.0.0/12           md5" >> $${PG_HBA}
echo "host    all             all             192.168.0.0/16          md5" >> $${PG_HBA}

# Restart PostgreSQL
systemctl restart postgresql

# Clone repository to get migration files
echo "Cloning repository..."
cd /tmp
git clone -b ${git_branch} ${git_repo} bmi-app || {
    echo "Failed to clone repository"
    exit 1
}

# Run migrations
echo "Running database migrations..."
cd /tmp/bmi-app/backend/migrations

for migration in *.sql; do
    if [ -f "$${migration}" ]; then
        echo "Running migration: $${migration}"
        sudo -u postgres psql -d ${db_name} -f "$${migration}"
    fi
done

# Cleanup
rm -rf /tmp/bmi-app

# Verify database setup
echo "Verifying database setup..."
sudo -u postgres psql -d ${db_name} -c "\dt"

echo "=================================="
echo "Database Server Initialization Complete"
echo "Completed: $(date)"
echo "=================================="
echo "Database: ${db_name}"
echo "User: ${db_user}"
echo "Port: ${db_port}"
echo "=================================="
