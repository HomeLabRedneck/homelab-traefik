# 🤖 Traefik Service Agent Guidelines

## 🎯 Agent Responsibilities

### Primary Agent: Infrastructure Manager
**Role**: Manages Traefik reverse proxy deployment and configuration

**Core Responsibilities**:
- Deploy and configure Traefik reverse proxy service
- Manage SSL/TLS certificates via Let's Encrypt and Cloudflare
- Configure service discovery and routing rules
- Monitor dashboard and service health
- Troubleshoot connectivity and certificate issues

**Key Files to Monitor**:
- `docker-compose.yaml` - Service definition and networking
- `data/traefik.yml` - Main Traefik configuration
- `data/acme.json` - SSL certificate storage
- `.env` - Environment variables and credentials
- `cf_api_token.txt` - Cloudflare API authentication

### Supporting Agent: Security Specialist
**Role**: Ensures secure configuration and access control

**Core Responsibilities**:
- Review and validate SSL/TLS configuration
- Manage authentication credentials and API tokens
- Monitor security headers and middleware
- Audit network access and container permissions
- Implement security best practices

## 🛠️ Tool Usage Guidelines

### Docker Operations
```bash
# Deploy service
docker-compose up -d

# Check service health
docker-compose ps && docker-compose logs traefik

# Update service
docker-compose pull && docker-compose up -d --force-recreate

# Restart for configuration changes
docker-compose restart traefik
```

### SSL Certificate Management
```bash
# Check certificate status
docker-compose exec traefik cat /acme.json | jq '.cloudflare.Certificates'

# Monitor certificate generation
docker-compose logs traefik | grep -i "certificate\|acme"

# Verify DNS challenge
dig TXT _acme-challenge.internal.labratech.org
```

### Configuration Validation
```bash
# Test Traefik configuration syntax
docker-compose config

# Validate dashboard access
curl -k https://traefik-dashboard.internal.labratech.org

# Check service discovery
docker-compose exec traefik wget -qO- http://localhost:8080/api/rawdata
```

## 🔧 Configuration Patterns

### Service Integration Template
When adding new services to the HomeLab, use this label pattern:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.service-name.rule=Host(`service.internal.labratech.org`)"
  - "traefik.http.routers.service-name.entrypoints=https"
  - "traefik.http.routers.service-name.tls=true"
  - "traefik.http.routers.service-name.tls.certresolver=cloudflare"
  - "traefik.http.routers.service-name.middlewares=traefik-real-ip"
networks:
  - proxy
```

### Middleware Configuration
Common middleware patterns for enhanced functionality:

```yaml
# Basic Authentication
- "traefik.http.middlewares.service-auth.basicauth.users=${SERVICE_CREDENTIALS}"

# Security Headers
- "traefik.http.middlewares.security-headers.headers.customrequestheaders.X-Forwarded-Proto=https"

# Rate Limiting
- "traefik.http.middlewares.rate-limit.ratelimit.burst=100"
```

## 🚨 Critical Operations

### High-Risk Actions (Require Confirmation)
- Modifying `acme.json` file (contains SSL certificates)
- Changing Cloudflare API token
- Updating DNS challenge configuration
- Modifying network configuration
- Changing certificate resolver settings

### Safe Operations (Can Execute Directly)
- Viewing logs and status
- Reading configuration files
- Testing connectivity
- Monitoring dashboard
- Checking certificate expiration

## 🔍 Troubleshooting Workflow

### 1. Service Health Check
```bash
# Check container status
docker-compose ps

# Review recent logs
docker-compose logs --tail=50 traefik

# Test network connectivity
docker network inspect proxy
```

### 2. Certificate Issues
```bash
# Check ACME challenge logs
docker-compose logs traefik | grep -i "acme\|challenge\|certificate"

# Verify Cloudflare API token
docker-compose exec traefik cat /run/secrets/cf_api_token

# Test DNS resolution
nslookup internal.labratech.org 1.1.1.1
```

### 3. Service Discovery Problems
```bash
# List discovered services
curl -s http://localhost:8080/api/http/services | jq

# Check router configuration
curl -s http://localhost:8080/api/http/routers | jq

# Verify proxy network membership
docker inspect $(docker-compose ps -q) | grep -A 5 Networks
```

## 📊 Monitoring Guidelines

### Key Metrics to Track
- **Certificate expiration dates** (auto-renewal should occur 30 days before)
- **Service discovery status** (all enabled services should appear)
- **Response times** for dashboard and proxied services
- **Error rates** in Traefik logs
- **Network connectivity** to Cloudflare and Let's Encrypt

### Dashboard Monitoring
- Access: `https://traefik-dashboard.internal.labratech.org`
- Monitor: Active routers, services, and middleware
- Check: Certificate status and expiration dates
- Review: Recent configuration changes

### Log Monitoring
```bash
# Monitor real-time logs
docker-compose logs -f traefik

# Check for errors
docker-compose logs traefik | grep -i "error\|fail\|timeout"

# Certificate-related events
docker-compose logs traefik | grep -i "certificate\|acme\|renewal"
```

## 🔐 Security Protocols

### Access Control
- Dashboard requires basic authentication (configured in `.env`)
- API access limited to localhost and authenticated requests
- Docker socket mounted read-only for security

### Certificate Security
- ACME file permissions must be `600` (owner read/write only)
- API tokens stored as Docker secrets
- Regular rotation of Cloudflare API tokens recommended

### Network Security
- Uses external `proxy` network for service isolation
- No direct internet access except for ACME challenges
- Container runs with `no-new-privileges:true`

## 🔄 Maintenance Schedule

### Daily
- Monitor service health and logs
- Check dashboard accessibility
- Verify certificate status

### Weekly
- Review configuration for any manual changes
- Check for Traefik updates
- Backup `acme.json` file

### Monthly
- Rotate Cloudflare API token
- Review security logs
- Test disaster recovery procedures

## 🚀 Deployment Best Practices

### Pre-Deployment Checklist
- [ ] Cloudflare API token configured and tested
- [ ] Dashboard credentials set in `.env`
- [ ] `acme.json` file permissions set to `600`
- [ ] External `proxy` network exists
- [ ] DNS records properly configured

### Post-Deployment Validation
- [ ] Dashboard accessible with authentication
- [ ] SSL certificates generated successfully
- [ ] Service discovery working for test service
- [ ] HTTP to HTTPS redirection functional
- [ ] Logs show no critical errors

### Rollback Procedures
1. Stop current container: `docker-compose down`
2. Restore previous configuration from backup
3. Restart with previous version: `docker-compose up -d`
4. Verify functionality and certificate validity

---

**⚠️ Important**: Traefik is critical infrastructure. Any changes should be tested thoroughly and have rollback plans ready.