#!/bin/bash
# 🔍 Traefik Configuration Validation Script

set -e

echo "🚀 Validating Traefik Configuration..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if required files exist
echo "📁 Checking required files..."

files=("docker-compose.yaml" ".env" "data/traefik.yml" "cf_api_token.txt")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        print_status 0 "$file exists"
    else
        print_status 1 "$file missing"
        if [ "$file" == "cf_api_token.txt" ]; then
            echo "   Create with: echo 'your_cloudflare_api_token' > cf_api_token.txt"
        fi
    fi
done

# Check acme.json permissions
echo ""
echo "🔒 Checking file permissions..."

if [ -f "data/acme.json" ]; then
    perms=$(stat -c "%a" data/acme.json 2>/dev/null || stat -f "%A" data/acme.json 2>/dev/null || echo "unknown")
    if [ "$perms" == "600" ]; then
        print_status 0 "acme.json permissions correct (600)"
    else
        print_status 1 "acme.json permissions incorrect ($perms)"
        echo "   Fix with: chmod 600 data/acme.json"
    fi
else
    print_warning "acme.json doesn't exist yet (will be created on first run)"
    echo "   Create with: touch data/acme.json && chmod 600 data/acme.json"
fi

# Check if proxy network exists
echo ""
echo "🌐 Checking Docker network..."

if docker network ls | grep -q "proxy"; then
    print_status 0 "proxy network exists"
else
    print_status 1 "proxy network missing"
    echo "   Create with: docker network create proxy"
fi

# Validate docker-compose syntax
echo ""
echo "📋 Validating Docker Compose syntax..."

if docker-compose config > /dev/null 2>&1; then
    print_status 0 "docker-compose.yaml syntax valid"
else
    print_status 1 "docker-compose.yaml syntax invalid"
    echo "   Check with: docker-compose config"
fi

# Check environment variables
echo ""
echo "🔧 Checking environment variables..."

if [ -f ".env" ]; then
    if grep -q "TRAEFIK_DASHBOARD_CREDENTIALS=" .env; then
        if grep -q "your_secure_token_here" .env; then
            print_status 1 "Dashboard credentials not configured"
            echo "   Generate with: echo \$(htpasswd -nb admin your_password) | sed -e s/\\\\\$/\\\\\$\\\\\$/g"
        else
            print_status 0 "Dashboard credentials configured"
        fi
    else
        print_status 1 "TRAEFIK_DASHBOARD_CREDENTIALS missing from .env"
    fi
fi

# Check Cloudflare token
echo ""
echo "☁️  Checking Cloudflare configuration..."

if [ -f "cf_api_token.txt" ]; then
    if [ -s "cf_api_token.txt" ]; then
        print_status 0 "Cloudflare API token file has content"
    else
        print_status 1 "Cloudflare API token file is empty"
    fi
else
    print_status 1 "Cloudflare API token file missing"
fi

# Check if Traefik is running
echo ""
echo "🐳 Checking service status..."

if docker-compose ps | grep -q "traefik.*Up"; then
    print_status 0 "Traefik container is running"
    
    # Check if dashboard is accessible
    if curl -k -s -o /dev/null -w "%{http_code}" https://traefik-dashboard.internal.labratech.org | grep -q "200\|401"; then
        print_status 0 "Dashboard is accessible"
    else
        print_status 1 "Dashboard is not accessible"
        echo "   Check DNS resolution and certificate generation"
    fi
else
    print_warning "Traefik container is not running"
    echo "   Start with: docker-compose up -d"
fi

echo ""
echo "🎉 Validation complete!"
echo ""
echo "📚 Next steps:"
echo "   1. Fix any issues shown above"
echo "   2. Deploy with: docker-compose up -d"
echo "   3. Monitor logs: docker-compose logs -f traefik"
echo "   4. Access dashboard: https://traefik-dashboard.internal.labratech.org"