# 🔐 Environment Variables Configuration

This document explains the environment variables that have been extracted from the Traefik configuration files to improve security and flexibility.

## 📋 Overview

Sensitive information has been moved from hardcoded values in `traefik.yml` and `docker-compose.yaml` to environment variables that can be configured in the `.env` file.

## 🔄 Changes Made

### From `traefik.yml`
- **Email address**: `youremail@email.com` → `${ACME_EMAIL}`
- **ACME server URL**: Hardcoded staging URL → `${ACME_CA_SERVER}`

### From `docker-compose.yaml`
- **Dashboard hostname**: `traefik-dashboard.local.example.com` → `${DOMAIN_DASHBOARD}`
- **Main domain**: `local.example.com` → `${DOMAIN_MAIN}`
- **Wildcard domain**: `*.local.example.com` → `${DOMAIN_WILDCARD}`

## 🔧 Required Environment Variables

### ACME Configuration
```bash
# Email address for Let's Encrypt certificate registration and notifications
ACME_EMAIL=your-email@example.com

# ACME server URL - use staging for testing, production for live certificates
# Production: https://acme-v02.api.letsencrypt.org/directory
# Staging: https://acme-staging-v02.api.letsencrypt.org/directory
ACME_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory
```

### Domain Configuration
```bash
# Main domain for your internal services (used for wildcard certificates)
DOMAIN_MAIN=yourdomain.com

# Wildcard domain pattern for subdomains
DOMAIN_WILDCARD=*.yourdomain.com

# Traefik dashboard hostname (subdomain of your main domain)
DOMAIN_DASHBOARD=traefik-dashboard.yourdomain.com
```

### Existing Variables (unchanged)
```bash
# Traefik Dashboard Basic Authentication
TRAEFIK_DASHBOARD_CREDENTIALS=admin:$2y$10$your_bcrypt_hash_here
```

## 🚀 Setup Instructions

1. **Copy the example file**:
   ```bash
   cp .env.example .env
   ```

2. **Update the variables in `.env`**:
   - Replace `youremail@email.com` with your actual email
   - Replace `local.example.com` with your actual domain
   - Update `DOMAIN_DASHBOARD` to your preferred dashboard subdomain
   - Generate proper credentials for `TRAEFIK_DASHBOARD_CREDENTIALS`

3. **Choose ACME server**:
   - **For testing**: Keep staging server (default)
   - **For production**: Change to production server

4. **Validate configuration**:
   ```bash
   ./validate-config.sh
   ```

## 🔒 Security Benefits

- **No hardcoded secrets**: Sensitive information is no longer committed to version control
- **Environment-specific configuration**: Different environments can use different domains/settings
- **Easy credential rotation**: Update `.env` file without modifying configuration files
- **Flexible domain management**: Easy to change domains without editing multiple files

## 🎯 Production Considerations

### For Production Deployment:
1. Set `ACME_CA_SERVER` to production Let's Encrypt server:
   ```bash
   ACME_CA_SERVER=https://acme-v02.api.letsencrypt.org/directory
   ```

2. Use your actual domain names:
   ```bash
   DOMAIN_MAIN=yourdomain.com
   DOMAIN_WILDCARD=*.yourdomain.com
   DOMAIN_DASHBOARD=traefik.yourdomain.com
   ```

3. Use a strong password for dashboard credentials:
   ```bash
   # Generate with:
   docker run --rm httpd:2.4-alpine htpasswd -nbB admin "your_strong_password" | sed -e s/\\$/\\$\\$/g
   ```

### For Development/Testing:
1. Keep staging server (default in `.env.example`)
2. Use local domains or test domains
3. Consider using self-signed certificates for local development

## 🔍 Validation

The `validate-config.sh` script has been updated to check:
- ✅ All required environment variables are present
- ✅ Variables have been updated from example values
- ✅ ACME server configuration (staging vs production)
- ✅ Domain configuration consistency
- ✅ Dashboard accessibility using configured domain

## 🐛 Troubleshooting

### Common Issues:

1. **Variables not substituted**: Ensure `.env` file exists and variables are properly formatted
2. **Dashboard not accessible**: Check DNS resolution for `DOMAIN_DASHBOARD`
3. **Certificate issues**: Verify `ACME_EMAIL` and `ACME_CA_SERVER` are correct
4. **Domain mismatch**: Ensure all domain variables use the same base domain

### Debug Commands:
```bash
# Check environment variable substitution
docker-compose config

# Verify .env file is loaded
docker-compose exec traefik env | grep -E "(ACME|DOMAIN)"

# Check Traefik logs for certificate issues
docker-compose logs traefik | grep -i acme
```