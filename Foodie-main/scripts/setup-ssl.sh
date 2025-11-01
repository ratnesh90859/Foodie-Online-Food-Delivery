#!/bin/bash

# SSL Certificate Setup Script using Let's Encrypt
# Run this after setting up your domain DNS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if domain is provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    print_error "Usage: $0 <main-domain> <admin-domain> <api-domain>"
    echo "Example: $0 myapp.com admin.myapp.com api.myapp.com"
    exit 1
fi

MAIN_DOMAIN=$1
ADMIN_DOMAIN=$2
API_DOMAIN=$3
EMAIL="admin@$MAIN_DOMAIN"

print_status "Setting up SSL certificates for:"
echo "  - Main: $MAIN_DOMAIN"
echo "  - Admin: $ADMIN_DOMAIN" 
echo "  - API: $API_DOMAIN"
echo "  - Email: $EMAIL"

# Verify domains point to this server
print_status "Verifying domain DNS configuration..."
SERVER_IP=$(curl -s ifconfig.me)
MAIN_IP=$(dig +short $MAIN_DOMAIN)
ADMIN_IP=$(dig +short $ADMIN_DOMAIN)
API_IP=$(dig +short $API_DOMAIN)

echo "Server IP: $SERVER_IP"
echo "Main domain IP: $MAIN_IP"
echo "Admin domain IP: $ADMIN_IP"
echo "API domain IP: $API_IP"

if [ "$SERVER_IP" != "$MAIN_IP" ] || [ "$SERVER_IP" != "$ADMIN_IP" ] || [ "$SERVER_IP" != "$API_IP" ]; then
    print_warning "Some domains don't point to this server. SSL certificate generation might fail."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Stop nginx to free port 80
print_status "Stopping nginx temporarily..."
sudo systemctl stop nginx 2>/dev/null || true

# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Generate certificates
print_status "Generating SSL certificates..."

# Main domain certificate
sudo certbot certonly --standalone \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $MAIN_DOMAIN \
    -d www.$MAIN_DOMAIN

# Admin domain certificate
sudo certbot certonly --standalone \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $ADMIN_DOMAIN

# API domain certificate  
sudo certbot certonly --standalone \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $API_DOMAIN

# Copy certificates to nginx ssl directory
print_status "Copying certificates to nginx directory..."
sudo cp /etc/letsencrypt/live/$MAIN_DOMAIN/fullchain.pem /etc/nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/$MAIN_DOMAIN/privkey.pem /etc/nginx/ssl/private.key

# Update nginx configuration files with actual domain names
print_status "Updating nginx configuration with your domains..."
cd /opt/foodie

# Update frontend config
sudo sed -i "s/your-domain.com/$MAIN_DOMAIN/g" nginx/sites-available/frontend.conf

# Update admin config
sudo sed -i "s/admin.your-domain.com/$ADMIN_DOMAIN/g" nginx/sites-available/admin.conf

# Update API config
sudo sed -i "s/api.your-domain.com/$API_DOMAIN/g" nginx/sites-available/api.conf

# Fix proxy_params include (create the file)
sudo tee /etc/nginx/proxy_params > /dev/null <<EOF
proxy_http_version 1.1;
proxy_set_header Upgrade \$http_upgrade;
proxy_set_header Connection 'upgrade';
proxy_set_header Host \$host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto \$scheme;
proxy_cache_bypass \$http_upgrade;
proxy_buffering off;
EOF

# Update environment files with domains
print_status "Updating environment configuration..."
sed -i "s/your-domain.com/$MAIN_DOMAIN/g" .env.production
sed -i "s/admin.your-domain.com/$ADMIN_DOMAIN/g" .env.production
sed -i "s/api.your-domain.com/$API_DOMAIN/g" .env.production

# Setup automatic certificate renewal
print_status "Setting up automatic certificate renewal..."
sudo tee /etc/cron.d/letsencrypt > /dev/null <<EOF
0 2 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx"
EOF

# Start nginx
print_status "Starting nginx..."
sudo systemctl start nginx
sudo systemctl enable nginx

print_status "SSL setup completed! 🎉"
print_status "Your applications will be available at:"
echo "  - Frontend: https://$MAIN_DOMAIN"
echo "  - Admin: https://$ADMIN_DOMAIN"
echo "  - API: https://$API_DOMAIN"
echo
print_warning "Next steps:"
echo "1. Update your .env file with the correct domain names"
echo "2. Deploy your application with ./deploy.sh"
echo "3. Test all endpoints to ensure SSL is working correctly"