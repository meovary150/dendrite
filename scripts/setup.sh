#!/bin/bash

# Dendrite Docker Setup Script
set -e

echo "======================================"
echo "Dendrite Matrix Server Setup Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Create necessary directories
print_status "Creating directory structure..."
mkdir -p config/appservices
mkdir -p data/dendrite/{media,search,logs}
mkdir -p data/traefik/letsencrypt
mkdir -p data/whatsapp

# Set proper permissions
chmod -R 755 config
chmod -R 755 data

# Generate secure tokens
print_status "Generating secure tokens..."

# Function to generate random token
generate_token() {
    openssl rand -hex 32
}

# Generate tokens if not already set in .env
if [ ! -f .env ]; then
    print_error ".env file not found. Please create it from .env.example"
    exit 1
fi

# Update .env with generated tokens
REGISTRATION_SECRET=$(generate_token)
AS_TOKEN=$(generate_token)
HS_TOKEN=$(generate_token)
PROVISIONING_SECRET=$(generate_token)

print_status "Updating .env file with secure tokens..."
sed -i "s/CHANGE_ME_TO_A_SECURE_SECRET/$REGISTRATION_SECRET/g" .env
sed -i "s/CHANGE_ME_AS_TOKEN_SECURE/$AS_TOKEN/g" .env
sed -i "s/CHANGE_ME_HS_TOKEN_SECURE/$HS_TOKEN/g" .env
sed -i "s/CHANGE_ME_PROVISIONING_SECRET/$PROVISIONING_SECRET/g" .env

# Update configuration files with tokens
print_status "Updating configuration files..."
sed -i "s/CHANGE_ME_TO_A_SECURE_SECRET/$REGISTRATION_SECRET/g" config/dendrite.yaml
sed -i "s/CHANGE_ME_AS_TOKEN_SECURE/$AS_TOKEN/g" config/mautrix-whatsapp.yaml
sed -i "s/CHANGE_ME_HS_TOKEN_SECURE/$HS_TOKEN/g" config/mautrix-whatsapp.yaml
sed -i "s/CHANGE_ME_PROVISIONING_SECRET/$PROVISIONING_SECRET/g" config/mautrix-whatsapp.yaml
sed -i "s/CHANGE_ME_TO_A_SECURE_SECRET/$REGISTRATION_SECRET/g" config/mautrix-whatsapp.yaml

# Create WhatsApp bridge appservice registration
print_status "Creating WhatsApp bridge appservice registration..."
cat > config/appservices/mautrix-whatsapp.yaml <<EOF
id: whatsapp
url: http://mautrix-whatsapp:29318
as_token: $AS_TOKEN
hs_token: $HS_TOKEN
sender_localpart: whatsappbot
rate_limited: false
namespaces:
  users:
    - regex: ^@whatsapp_[0-9]+:api\.yifanyiscrm\.com$
      exclusive: true
  aliases:
    - regex: ^#whatsapp_[0-9]+:api\.yifanyiscrm\.com$
      exclusive: true
EOF

# Create well-known files service
print_status "Creating well-known files..."
cat > docker-compose.wellknown.yml <<'EOF'
version: '3.8'

services:
  wellknown-service:
    image: nginx:alpine
    container_name: wellknown-service
    volumes:
      - ./config/wellknown:/usr/share/nginx/html/.well-known/matrix:ro
    networks:
      - dendrite-network
EOF

# Create well-known files
mkdir -p config/wellknown
cat > config/wellknown/server <<EOF
{
  "m.server": "api.yifanyiscrm.com:443"
}
EOF

cat > config/wellknown/client <<EOF
{
  "m.homeserver": {
    "base_url": "https://api.yifanyiscrm.com"
  },
  "m.identity_server": {
    "base_url": "https://vector.im"
  },
  "org.matrix.msc3575.proxy": {
    "url": "https://api.yifanyiscrm.com"
  }
}
EOF

# Generate Traefik dashboard password
print_status "Setting up Traefik dashboard credentials..."
read -p "Enter password for Traefik dashboard (user: admin): " -s TRAEFIK_PASSWORD
echo
HASHED_PASSWORD=$(docker run --rm httpd:alpine htpasswd -nbB admin "$TRAEFIK_PASSWORD" | sed -e s/\\$/\\$\\$/g)
sed -i "s|TRAEFIK_DASHBOARD_PASSWORD=.*|TRAEFIK_DASHBOARD_PASSWORD=$HASHED_PASSWORD|g" .env

print_status "Setup complete!"
echo ""
print_warning "Important next steps:"
echo "1. Review and update the .env file with your specific settings"
echo "2. Update email address in .env for Let's Encrypt"
echo "3. Ensure domains api.yifanyiscrm.com and app.yifanyiscrm.com point to this server"
echo "4. Review security settings in configuration files"
echo ""
print_status "To start the services, run:"
echo "  docker-compose up -d"
echo ""
print_status "To create the first admin user after services are running:"
echo "  docker exec -it dendrite-server create-account --config /etc/dendrite/dendrite.yaml --username admin --admin"
echo ""
print_status "To monitor logs:"
echo "  docker-compose logs -f"
echo ""
print_status "Access points after deployment:"
echo "  - Element Web: https://app.yifanyiscrm.com"
echo "  - Matrix API: https://api.yifanyiscrm.com"
echo "  - Traefik Dashboard: https://api.yifanyiscrm.com:8080 (admin / your_password)"