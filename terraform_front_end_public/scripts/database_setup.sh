#!/bin/bash
################################################################################
# Database Server Initialization Script
# Templatefile variables: db_name, db_user, db_password, db_port, git_repo, git_branch
#
# Re-run manually at any time:
#   sudo bash /usr/local/bin/init-database.sh
################################################################################

set -e
exec > >(tee -a /var/log/user-data.log) 2>&1

echo "======================================================"
echo " Database Server Initialization — $(date)"
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
echo "[2/7] Installing PostgreSQL, git, netcat..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  postgresql postgresql-contrib git curl netcat-openbsd

# Verify SSM agent is running (pre-installed on Ubuntu 22.04 AWS AMIs)
echo "Verifying SSM agent..."
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || true
systemctl start  snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || \
  systemctl start amazon-ssm-agent 2>/dev/null || true

# ----------------------------------------------------------------------------
# Detect installed PostgreSQL version
# ----------------------------------------------------------------------------
echo "[3/7] Detecting PostgreSQL version..."
PG_VERSION=$(ls /etc/postgresql/ 2>/dev/null | sort -V | tail -1)
if [ -z "$PG_VERSION" ]; then
  echo "ERROR: PostgreSQL installation not found"
  exit 1
fi
echo "  Detected PostgreSQL $PG_VERSION"
PG_CONF="/etc/postgresql/$${PG_VERSION}/main/postgresql.conf"
PG_HBA="/etc/postgresql/$${PG_VERSION}/main/pg_hba.conf"

# Start PostgreSQL
systemctl start postgresql
systemctl enable postgresql
sleep 5

# ----------------------------------------------------------------------------
# Create database and user
# ----------------------------------------------------------------------------
echo "[4/7] Creating database and user..."
sudo -u postgres psql << PSQL_EOF
-- Idempotent: drop and recreate for clean state on re-runs
DROP DATABASE IF EXISTS ${db_name};
DROP USER     IF EXISTS ${db_user};

CREATE DATABASE ${db_name};
CREATE USER ${db_user} WITH PASSWORD '${db_password}';
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};

\c ${db_name}
GRANT ALL ON SCHEMA public TO ${db_user};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES    TO ${db_user};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${db_user};
PSQL_EOF

# ----------------------------------------------------------------------------
# Configure PostgreSQL for VPC access
# ----------------------------------------------------------------------------
echo "[5/7] Configuring PostgreSQL networking..."

# Listen on all interfaces
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $${PG_CONF}

# Tune connections and memory
sed -i "s/max_connections = 100/max_connections = 200/"   $${PG_CONF}
sed -i "s/shared_buffers = 128MB/shared_buffers = 256MB/" $${PG_CONF}

# Allow MD5 auth from all RFC-1918 ranges (private VPC traffic only)
cat >> $${PG_HBA} << HBA_EOF

# Allow connections from VPC private address ranges
host  all  all  10.0.0.0/8      md5
host  all  all  172.16.0.0/12   md5
host  all  all  192.168.0.0/16  md5
HBA_EOF

systemctl restart postgresql
sleep 5

# Verify PostgreSQL is listening on the correct port
echo "PostgreSQL listening on:"
ss -tlnp | grep ":${db_port}" || echo "  (will be available after full restart)"

# ----------------------------------------------------------------------------
# Clone repository and run migrations
# ----------------------------------------------------------------------------
echo "[6/7] Running database migrations..."
cd /tmp
rm -rf bmi-app
git clone -b ${git_branch} ${git_repo} bmi-app || {
  echo "ERROR: Failed to clone ${git_repo}"
  exit 1
}

MIGRATION_DIR="/tmp/bmi-app/backend/migrations"
if [ -d "$${MIGRATION_DIR}" ]; then
  for migration in $${MIGRATION_DIR}/*.sql; do
    if [ -f "$${migration}" ]; then
      echo "  Running: $(basename $${migration})"
      sudo -u postgres psql -d ${db_name} -f "$${migration}"
    fi
  done
else
  echo "  No migrations directory found — skipping"
fi

rm -rf /tmp/bmi-app

# Verify tables were created
echo "[7/7] Verifying database..."
sudo -u postgres psql -d ${db_name} -c "\dt" 2>/dev/null || true

# Save script for manual re-runs
cp /var/log/user-data.log /var/log/user-data-database.log
echo "Script can be re-run: sudo bash /usr/local/bin/init-database.sh"
cp "$0" /usr/local/bin/init-database.sh 2>/dev/null || true
chmod +x /usr/local/bin/init-database.sh 2>/dev/null || true

echo "======================================================"
echo " Database Initialization Complete — $(date)"
echo " Host     : $(hostname -I | awk '{print $1}')"
echo " Database : ${db_name}"
echo " User     : ${db_user}"
echo " Port     : ${db_port}"
echo "======================================================"
