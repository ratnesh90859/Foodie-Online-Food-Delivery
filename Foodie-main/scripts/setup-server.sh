#!/bin/bash

# EC2 Server Setup Script for Foodie Application
# This script sets up Docker, Docker Compose, and necessary tools on Ubuntu EC2

set -e  # Exit on any error

echo "🚀 Starting EC2 Server Setup for Foodie Application..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Update system packages
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
print_status "Installing essential packages..."
sudo apt install -y \
    curl \
    wget \
    unzip \
    git \
    htop \
    vim \
    ufw \
    fail2ban \
    certbot \
    python3-certbot-nginx

# Install Docker
print_status "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
print_status "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create docker group and add user
sudo groupadd -f docker
sudo usermod -aG docker $USER

# Setup firewall
print_status "Configuring firewall..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 3000  # Frontend dev
sudo ufw allow 3001  # Admin dev
sudo ufw allow 4000  # Backend API

# Configure fail2ban
print_status "Configuring fail2ban..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Create application directory
print_status "Creating application directory..."
sudo mkdir -p /opt/foodie
sudo chown $USER:$USER /opt/foodie
cd /opt/foodie

# Create necessary directories
mkdir -p logs ssl mongodb_data uploads_data

# Set up log rotation
print_status "Setting up log rotation..."
sudo tee /etc/logrotate.d/foodie > /dev/null <<EOF
/opt/foodie/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    notifempty
    create 0644 $USER $USER
    copytruncate
}
EOF

# Create systemd service for the application
print_status "Creating systemd service..."
sudo tee /etc/systemd/system/foodie.service > /dev/null <<EOF
[Unit]
Description=Foodie Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/foodie
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0
User=$USER
Group=$USER

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable foodie

# Install Node.js (for npm commands if needed)
print_status "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Setup swap if not exists (recommended for small instances)
if [ ! -f /swapfile ]; then
    print_status "Setting up swap file..."
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Create deployment script
print_status "Creating deployment helper scripts..."
tee /opt/foodie/deploy.sh > /dev/null <<'EOF'
#!/bin/bash
# Quick deployment script

echo "🚀 Deploying Foodie Application..."

# Pull latest changes
git pull origin main

# Build and start containers
docker-compose down
docker-compose build --no-cache
docker-compose up -d

echo "✅ Deployment completed!"
echo "Frontend: http://$(curl -s ifconfig.me):3000"
echo "Admin: http://$(curl -s ifconfig.me):3001"
echo "API: http://$(curl -s ifconfig.me):4000"
EOF

chmod +x /opt/foodie/deploy.sh

# Create monitoring script
tee /opt/foodie/monitor.sh > /dev/null <<'EOF'
#!/bin/bash
# System monitoring script

echo "=== Foodie Application Status ==="
echo "Date: $(date)"
echo

echo "=== Docker Containers ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo

echo "=== System Resources ==="
free -h
echo
df -h /
echo

echo "=== Container Logs (last 5 lines) ==="
for container in $(docker ps --format "{{.Names}}"); do
    echo "--- $container ---"
    docker logs --tail 5 $container 2>/dev/null || echo "No logs available"
    echo
done
EOF

chmod +x /opt/foodie/monitor.sh

# Create backup script
tee /opt/foodie/backup.sh > /dev/null <<'EOF'
#!/bin/bash
# Database backup script

BACKUP_DIR="/opt/foodie/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "🔄 Creating database backup..."
docker exec foodie-mongodb mongodump --authenticationDatabase admin -u admin -p admin123 --db foodie --out /tmp/backup
docker cp foodie-mongodb:/tmp/backup $BACKUP_DIR/mongodb_$DATE
docker exec foodie-mongodb rm -rf /tmp/backup

echo "🔄 Creating uploads backup..."
cp -r uploads_data $BACKUP_DIR/uploads_$DATE

echo "✅ Backup completed: $BACKUP_DIR"
ls -la $BACKUP_DIR/
EOF

chmod +x /opt/foodie/backup.sh

# Install monitoring tools
print_status "Installing monitoring tools..."
sudo apt install -y htop iotop nethogs

print_status "Setup completed successfully! 🎉"
print_warning "Please reboot the server to ensure all changes take effect:"
print_warning "sudo reboot"
echo
print_status "After reboot, you can:"
echo "1. Clone your repository to /opt/foodie"
echo "2. Configure your .env file"
echo "3. Run ./deploy.sh to start the application"
echo "4. Use ./monitor.sh to check application status"
echo "5. Use ./backup.sh to backup your data"
echo
print_warning "Don't forget to:"
echo "- Configure your domain DNS to point to this server"
echo "- Setup SSL certificates with Let's Encrypt"
echo "- Update firewall rules as needed"