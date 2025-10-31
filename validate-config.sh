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
    # Check dashboard credentials
    if grep -q "TRAEFIK_DASHBOARD_CREDENTIALS=" .env; then
        if grep -q "your_bcrypt_hash_here" .env; then
            print_status 1 "Dashboard credentials not configured"
            echo "   Generate with: echo \$(htpasswd -nb admin your_password) | sed -e s/\\\\\$/\\\\\$\\\\\$/g"
        else
            print_status 0 "Dashboard credentials configured"
        fi
    else
        print_status 1 "TRAEFIK_DASHBOARD_CREDENTIALS missing from .env"
    fi
    
    # Check ACME email
    if grep -q "ACME_EMAIL=" .env; then
        if grep -q "youremail@email.com" .env; then
            print_status 1 "ACME email not configured (still using example)"
            echo "   Update ACME_EMAIL in .env file"
        else
            print_status 0 "ACME email configured"
        fi
    else
        print_status 1 "ACME_EMAIL missing from .env"
    fi
    
    # Check domain configuration
    if grep -q "DOMAIN_MAIN=" .env; then
        if grep -q "local.example.com" .env; then
            print_status 1 "Domain configuration not updated (still using example)"
            echo "   Update DOMAIN_MAIN, DOMAIN_WILDCARD, and DOMAIN_DASHBOARD in .env file"
        else
            print_status 0 "Domain configuration updated"
        fi
    else
        print_status 1 "DOMAIN_MAIN missing from .env"
    fi
    
    # Check ACME server configuration
    if grep -q "ACME_CA_SERVER=" .env; then
        if grep -q "staging" .env; then
            print_warning "Using ACME staging server (good for testing)"
        else
            print_status 0 "Using ACME production server"
        fi
    else
        print_status 1 "ACME_CA_SERVER missing from .env"
    fi
else
    print_status 1 ".env file missing"
    echo "   Copy from: cp .env.example .env"
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
    
    # Check if dashboard is accessible (load domain from .env if available)
    DASHBOARD_DOMAIN="traefik-dashboard.local.example.com"
    if [ -f ".env" ] && grep -q "DOMAIN_DASHBOARD=" .env; then
        DASHBOARD_DOMAIN=$(grep "DOMAIN_DASHBOARD=" .env | cut -d'=' -f2)
    fi
    
    if curl -k -s -o /dev/null -w "%{http_code}" "https://${DASHBOARD_DOMAIN}" | grep -q "200\|401"; then
        print_status 0 "Dashboard is accessible at https://${DASHBOARD_DOMAIN}"
    else
        print_status 1 "Dashboard is not accessible at https://${DASHBOARD_DOMAIN}"
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
echo "   2. Copy and configure: cp .env.example .env"
echo "   3. Update domains, email, and credentials in .env"
echo "   4. Deploy with: docker-compose up -d"
echo "   5. Monitor logs: docker-compose logs -f traefik"
echo "   6. Access dashboard: https://\${DOMAIN_DASHBOARD} (from your .env file)"