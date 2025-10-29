#!/bin/bash
# 🚀 Traefik Quick Setup Script

set -e

echo "🌐 Setting up Traefik Reverse Proxy..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Create proxy network
print_step "Creating Docker proxy network..."
if docker network ls | grep -q "proxy"; then
    print_warning "Proxy network already exists"
else
    docker network create proxy
    print_success "Proxy network created"
fi

# Step 2: Set up acme.json with correct permissions
print_step "Setting up SSL certificate storage..."
if [ ! -f "data/acme.json" ]; then
    touch data/acme.json
    print_success "Created acme.json file"
fi

chmod 600 data/acme.json
print_success "Set acme.json permissions to 600"

# Step 3: Check for Cloudflare API token
print_step "Checking Cloudflare API token..."
if [ ! -f "cf_api_token.txt" ] || [ ! -s "cf_api_token.txt" ]; then
    print_error "Cloudflare API token missing or empty"
    echo ""
    echo "📝 Please create your Cloudflare API token:"
    echo "   1. Go to https://dash.cloudflare.com/profile/api-tokens"
    echo "   2. Create token with permissions:"
    echo "      - Zone:Zone:Read (all zones)"
    echo "      - Zone:DNS:Edit (specific zone: labratech.org)"
    echo "   3. Save token to file:"
    echo "      echo 'your_token_here' > cf_api_token.txt"
    echo ""
    read -p "Press Enter after creating the token file..."
    
    if [ ! -f "cf_api_token.txt" ] || [ ! -s "cf_api_token.txt" ]; then
        print_error "Token file still missing. Exiting."
        exit 1
    fi
fi
print_success "Cloudflare API token found"

# Step 4: Check dashboard credentials
print_step "Checking dashboard credentials..."
if [ ! -f ".env" ]; then
    print_error ".env file missing"
    exit 1
fi

if grep -q "your_secure_token_here" .env; then
    print_error "Dashboard credentials not configured"
    echo ""
    echo "📝 Please configure dashboard credentials:"
    echo "   1. Generate credentials:"
    echo "      htpasswd -nb admin your_password"
    echo "   2. Update .env file with the output (escape $ as $$)"
    echo ""
    read -p "Press Enter after updating .env file..."
fi
print_success "Dashboard credentials configured"

# Step 5: Validate configuration
print_step "Validating Docker Compose configuration..."
if docker-compose config > /dev/null 2>&1; then
    print_success "Configuration is valid"
else
    print_error "Configuration validation failed"
    docker-compose config
    exit 1
fi

# Step 6: Deploy Traefik
print_step "Deploying Traefik service..."
docker-compose up -d

# Wait a moment for startup
sleep 5

# Step 7: Check deployment
print_step "Checking deployment status..."
if docker-compose ps | grep -q "traefik.*Up"; then
    print_success "Traefik is running"
else
    print_error "Traefik failed to start"
    echo "Check logs with: docker-compose logs traefik"
    exit 1
fi

# Step 8: Monitor certificate generation
print_step "Monitoring initial certificate generation..."
echo "This may take a few minutes for the first SSL certificate..."

# Wait for certificate generation (timeout after 5 minutes)
timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker-compose logs traefik 2>&1 | grep -q "certificate obtained"; then
        print_success "SSL certificate obtained successfully"
        break
    elif docker-compose logs traefik 2>&1 | grep -q "error.*certificate"; then
        print_error "Certificate generation failed"
        echo "Check logs: docker-compose logs traefik"
        break
    fi
    
    sleep 10
    elapsed=$((elapsed + 10))
    echo -n "."
done

if [ $elapsed -ge $timeout ]; then
    print_warning "Certificate generation taking longer than expected"
    echo "Monitor with: docker-compose logs -f traefik"
fi

echo ""
print_success "🎉 Traefik setup complete!"
echo ""
echo "📊 Access Information:"
echo "   Dashboard: https://traefik-dashboard.internal.labratech.org"
echo "   Username: admin (or as configured)"
echo "   Password: (as configured in .env)"
echo ""
echo "🔍 Monitoring Commands:"
echo "   Status: docker-compose ps"
echo "   Logs: docker-compose logs -f traefik"
echo "   Validation: ./validate-config.sh"
echo ""
echo "📚 Next Steps:"
echo "   1. Access the dashboard to verify everything is working"
echo "   2. Add other services to the proxy network"
echo "   3. Configure service labels for automatic discovery"