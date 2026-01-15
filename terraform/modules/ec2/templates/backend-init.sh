#!/bin/bash
################################################################################
# Backend Server Initialization Script
# This script sets up Node.js backend with PM2 process manager
#
# To re-run this script after initial boot:
#   sudo bash /usr/local/bin/init-backend.sh
################################################################################

set -e

# Logging
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "=================================="
echo "Backend Server Initialization"
echo "Started: $$(date)"
echo "=================================="

# Save this script to /usr/local/bin for manual re-runs
if [ ! -f /usr/local/bin/init-backend.sh ]; then
    cat <<'SCRIPT_EOF' > /usr/local/bin/init-backend.sh
#!/bin/bash
# This is a saved copy of the user-data script
# Run with: sudo bash /usr/local/bin/init-backend.sh
exec > >(tee -a /var/log/user-data-manual.log)
exec 2>&1
set -e
SCRIPT_EOF
    
    # Append the rest of this script
    tail -n +32 "$$0" >> /usr/local/bin/init-backend.sh 2>/dev/null || true
    chmod +x /usr/local/bin/init-backend.sh
    echo "Script saved to /usr/local/bin/init-backend.sh for manual re-runs"
fi

# Update system
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
apt-get install -y git curl build-essential

# Install Node.js 20.x LTS
echo "Installing Node.js 20.x LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Verify installations
node --version
npm --version

# Install PM2 globally
echo "Installing PM2..."
npm install -g pm2

# Create application directory
echo "Setting up application..."
APP_DIR="/home/ubuntu/bmi-health-tracker"
mkdir -p $$APP_DIR
cd $$APP_DIR

# Clone repository
echo "Cloning repository..."
git clone -b ${git_branch} ${git_repo} .

# Navigate to backend directory
cd backend

# Create .env file
echo "Creating environment configuration..."
cat > .env << EOF
# Database Configuration
DATABASE_URL=postgresql://${db_user}:${db_password}@${db_host}:${db_port}/${db_name}
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}

# Server Configuration
PORT=${backend_port}
NODE_ENV=production

# CORS Configuration
FRONTEND_URL=${frontend_url}
CORS_ORIGIN=*
EOF

# Set proper permissions
chmod 600 .env

# Install dependencies
echo "Installing backend dependencies..."
npm install --production

# Test database connection
echo "Testing database connection..."
node -e "
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL || 'postgresql://${db_user}:${db_password}@${db_host}:${db_port}/${db_name}' });
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('Database connection failed:', err);
    process.exit(1);
  }
  console.log('Database connection successful:', res.rows[0]);
  pool.end();
});
" || echo "Warning: Database connection test failed. Backend will retry on startup."

# Start application with PM2
echo "Starting backend with PM2..."
pm2 start src/server.js --name bmi-backend --time
pm2 save
pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Setup PM2 to start on boot
env PATH=$$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Change ownership
chown -R ubuntu:ubuntu $$APP_DIR
chown -R ubuntu:ubuntu /home/ubuntu/.pm2

# Verify backend is running
sleep 5
pm2 list

# Test backend health endpoint
echo "Testing backend health endpoint..."
sleep 10
curl -f http://localhost:${backend_port}/health || echo "Warning: Health check failed"

echo "=================================="
echo "Backend Server Initialization Complete"
echo "Completed: $(date)"
echo "=================================="
echo "Backend URL: http://localhost:${backend_port}"
echo "API URL: http://localhost:${backend_port}/api"
echo "Health Check: http://localhost:${backend_port}/health"
echo "=================================="
echo "PM2 Status:"
pm2 status
echo "=================================="
