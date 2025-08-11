#!/bin/bash

# Dendrite Docker Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[*]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# ASCII Banner
echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════╗
║     Dendrite Matrix Server Deployment    ║
║          with WhatsApp Bridge             ║
╚══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check Docker and Docker Compose
print_status "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if setup has been run
if [ ! -f .env ]; then
    print_error ".env file not found. Please run setup.sh first."
    exit 1
fi

# Function to wait for service to be healthy
wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=0
    
    print_info "Waiting for $service to be healthy..."
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose ps | grep -q "$service.*healthy"; then
            print_status "$service is healthy!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    print_error "$service failed to become healthy"
    return 1
}

# Pull latest images
print_status "Pulling latest Docker images..."
docker-compose pull

# Build Dendrite image
print_status "Building Dendrite Docker image..."
docker-compose build

# Start services
print_status "Starting services..."
docker-compose up -d

# Wait for PostgreSQL to be ready
wait_for_service "postgres"

# Wait for Dendrite to be ready
print_info "Waiting for Dendrite to start..."
sleep 10

# Check if Dendrite is running
if docker-compose ps | grep -q "dendrite.*Up"; then
    print_status "Dendrite is running!"
else
    print_error "Dendrite failed to start. Check logs with: docker-compose logs dendrite"
    exit 1
fi

# Check if Element Web is running
if docker-compose ps | grep -q "element-web.*Up"; then
    print_status "Element Web is running!"
else
    print_error "Element Web failed to start. Check logs with: docker-compose logs element-web"
    exit 1
fi

# Check if WhatsApp bridge is running
if docker-compose ps | grep -q "mautrix-whatsapp.*Up"; then
    print_status "WhatsApp bridge is running!"
else
    print_error "WhatsApp bridge failed to start. Check logs with: docker-compose logs mautrix-whatsapp"
    exit 1
fi

# Check if Traefik is running
if docker-compose ps | grep -q "traefik.*Up"; then
    print_status "Traefik is running!"
else
    print_error "Traefik failed to start. Check logs with: docker-compose logs traefik"
    exit 1
fi

# Show service status
print_status "All services are running!"
echo ""
docker-compose ps

# Create admin user if it doesn't exist
print_info "Creating admin user..."
docker exec dendrite-server create-account --config /etc/dendrite/dendrite.yaml --username admin --admin || true

# Display access information
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}            Deployment Successful!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
print_info "Access Points:"
echo "  • Element Web UI: https://app.yifanyiscrm.com"
echo "  • Matrix API: https://api.yifanyiscrm.com"
echo "  • Federation: https://api.yifanyiscrm.com:8448"
echo ""
print_info "Admin Commands:"
echo "  • Create user: docker exec -it dendrite-server create-account --config /etc/dendrite/dendrite.yaml --username USERNAME"
echo "  • View logs: docker-compose logs -f [service_name]"
echo "  • Stop services: docker-compose down"
echo "  • Restart services: docker-compose restart"
echo ""
print_info "WhatsApp Bridge:"
echo "  • Login: Use Element Web to start a chat with @whatsappbot:api.yifanyiscrm.com"
echo "  • Send 'login' to the bot to get QR code for WhatsApp Web"
echo ""
print_warning "Security Notes:"
echo "  • Change all default passwords in .env file"
echo "  • Review firewall settings"
echo "  • Enable fail2ban for production use"
echo "  • Regular backup of PostgreSQL database"
echo ""
print_status "Deployment complete! 🚀"