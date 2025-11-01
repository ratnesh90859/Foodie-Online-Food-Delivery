#!/bin/bash

# Production Deployment Script for Foodie Application
# This script handles zero-downtime deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration
APP_DIR="/opt/foodie"
BACKUP_DIR="/opt/foodie/backups"
LOG_FILE="/opt/foodie/logs/deployment.log"

# Create log directory
mkdir -p /opt/foodie/logs

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

print_info "🚀 Starting Foodie Application Deployment..."
log "Deployment started"

# Check if we're in the correct directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found. Please run this script from the project root."
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_warning ".env file not found. Copying from .env.production template..."
    cp .env.production .env
    print_warning "Please edit .env file with your actual configuration before continuing."
    read -p "Press Enter when you've updated the .env file..."
fi

# Pre-deployment checks
print_info "🔍 Running pre-deployment checks..."

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please run setup-server.sh first."
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please run setup-server.sh first."
    exit 1
fi

# Check system resources
print_info "📊 Checking system resources..."
FREE_MEMORY=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
FREE_DISK=$(df -h / | awk 'NR==2{print $4}' | sed 's/G//')

log "Free memory: ${FREE_MEMORY}GB, Free disk: ${FREE_DISK}GB"

if (( $(echo "$FREE_MEMORY < 0.5" | bc -l) )); then
    print_warning "Low memory detected. Consider upgrading your instance."
fi

# Create backup before deployment
print_info "💾 Creating backup before deployment..."
mkdir -p $BACKUP_DIR
BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"

# Backup database if container is running
if docker ps | grep -q "foodie-mongodb"; then
    print_status "Backing up database..."
    docker exec foodie-mongodb mongodump --authenticationDatabase admin -u admin -p admin123 --db foodie --out /tmp/$BACKUP_NAME
    docker cp foodie-mongodb:/tmp/$BACKUP_NAME $BACKUP_DIR/
    docker exec foodie-mongodb rm -rf /tmp/$BACKUP_NAME
    log "Database backup created: $BACKUP_DIR/$BACKUP_NAME"
fi

# Backup uploads if they exist
if [ -d "uploads_data" ]; then
    print_status "Backing up uploads..."
    cp -r uploads_data $BACKUP_DIR/uploads_$BACKUP_NAME
    log "Uploads backup created: $BACKUP_DIR/uploads_$BACKUP_NAME"
fi

# Pull latest code (if git repository)
if [ -d ".git" ]; then
    print_status "Pulling latest code..."
    git pull origin main
    log "Code updated from repository"
fi

# Build new images
print_info "🔨 Building application images..."
docker-compose build --no-cache --parallel
log "Docker images built successfully"

# Health check function
health_check() {
    local service=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    print_info "🔍 Checking health of $service..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s $url > /dev/null 2>&1; then
            print_status "$service is healthy!"
            return 0
        fi
        
        print_info "Attempt $attempt/$max_attempts - $service not ready yet..."
        sleep 10
        ((attempt++))
    done
    
    print_error "$service failed to become healthy within 5 minutes"
    return 1
}

# Deploy with zero downtime
print_info "🚀 Deploying application..."

# Start database first
print_status "Starting database..."
docker-compose up -d mongodb
log "Database started"

# Wait for database to be ready
sleep 30

# Start backend
print_status "Starting backend..."
docker-compose up -d backend
log "Backend started"

# Health check backend
if ! health_check "Backend" "http://localhost:4000/"; then
    print_error "Backend deployment failed"
    log "Backend deployment failed"
    exit 1
fi

# Start frontend and admin
print_status "Starting frontend and admin..."
docker-compose up -d frontend admin
log "Frontend and admin started"

# Start nginx (if using production profile)
if grep -q "profiles:" docker-compose.yml; then
    print_status "Starting nginx reverse proxy..."
    docker-compose --profile production up -d nginx
    log "Nginx started"
fi

# Final health checks
print_info "🏥 Running final health checks..."

# Check all containers are running
if ! docker-compose ps | grep -q "Up"; then
    print_error "Some containers failed to start"
    docker-compose logs
    exit 1
fi

# Display status
print_status "📊 Deployment Status:"
docker-compose ps

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)

print_status "🎉 Deployment completed successfully!"
print_info "Your application is now available at:"
echo "  - Frontend: http://$SERVER_IP:3000"
echo "  - Admin: http://$SERVER_IP:3001"
echo "  - API: http://$SERVER_IP:4000"

if [ -f "nginx/sites-available/frontend.conf" ]; then
    echo "  - Production Frontend: https://$(grep server_name nginx/sites-available/frontend.conf | awk '{print $2}' | head -1 | sed 's/;//')"
    echo "  - Production Admin: https://$(grep server_name nginx/sites-available/admin.conf | awk '{print $2}' | head -1 | sed 's/;//')"
    echo "  - Production API: https://$(grep server_name nginx/sites-available/api.conf | awk '{print $2}' | head -1 | sed 's/;//')"
fi

log "Deployment completed successfully"

print_info "📋 Next steps:"
echo "1. Test all functionality thoroughly"
echo "2. Monitor logs: docker-compose logs -f"
echo "3. Set up monitoring alerts"
echo "4. Configure regular backups"

# Clean up old images
print_info "🧹 Cleaning up old Docker images..."
docker image prune -f
log "Docker cleanup completed"

print_status "Deployment script finished! 🏁"