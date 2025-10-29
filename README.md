# 🌐 Traefik Reverse Proxy Service

## 📋 Overview

Traefik is the central reverse proxy and load balancer for the HomeLab infrastructure. It serves as the main entry point for all HTTP/HTTPS traffic, providing:

- **Automatic SSL/TLS certificate management** via Let's Encrypt and Cloudflare DNS challenge
- **Dynamic service discovery** through Docker labels
- **HTTP to HTTPS redirection** for all services
- **Dashboard monitoring** with basic authentication
- **Real IP detection** for services behind Cloudflare

## 🏗️ Architecture

```
Internet → Cloudflare → Traefik (Port 80/443) → Internal Services
                           ↓
                    Dashboard (traefik-dashboard.internal.labratech.org)
```

## 📦 Prerequisites

### Required Dependencies
- Docker and Docker Compose
- External `proxy` network created
- Cloudflare account with API token
- Domain registered with Cloudflare DNS

### Network Setup
```bash
# Create the external proxy network
docker network create proxy
```

## ⚙️ Configuration

### 1. Environment Variables

Copy and configure the `.env` file:

```bash
# Basic Authentication for Traefik Dashboard
# Generate with: echo $(htpasswd -nb admin your_password) | sed -e s/\\$/\\$\\$/g
TRAEFIK_DASHBOARD_CREDENTIALS="admin:$$2y$$10$$..."
```

### 2. Cloudflare API Token

Create a Cloudflare API token with the following permissions:
- **Zone:Zone:Read** (for all zones)
- **Zone:DNS:Edit** (for specific zone: `labratech.org`)

Save the token in `cf_api_token.txt`:
```bash
echo "your_cloudflare_api_token_here" > cf_api_token.txt
```

### 3. SSL/TLS Configuration

The service is configured for:
- **Primary domain**: `internal.labratech.org`
- **Wildcard certificate**: `*.internal.labratech.org`
- **ACME email**: `genstuff543@pm.me`
- **DNS Challenge**: Cloudflare provider

### 4. File Structure

```
traekif/
├── docker-compose.yaml    # Main service definition
├── .env                   # Environment variables
├── cf_api_token.txt      # Cloudflare API token (create this)
├── setup-traefik.sh      # Automated setup script
├── validate-config.sh    # Configuration validation script
├── README.md             # This documentation
├── AGENTS.md             # Agent guidelines for management
├── TROUBLESHOOTING.md    # Detailed troubleshooting guide
└── data/
    ├── traefik.yml       # Main Traefik configuration
    ├── config.yml        # Additional dynamic config (optional)
    └── acme.json         # SSL certificates storage (auto-created)
```

## 🚀 Deployment

### Quick Start

#### Automated Setup (Recommended)
```bash
# Make setup script executable and run
chmod +x setup-traefik.sh
./setup-traefik.sh
```

#### Manual Setup

1. **Clone and navigate to directory**:
   ```bash
   cd traekif
   ```

2. **Set up environment**:
   ```bash
   # Create Cloudflare API token file
   echo "your_cloudflare_api_token" > cf_api_token.txt
   
   # Configure dashboard credentials in .env
   nano .env
   ```

3. **Set correct permissions**:
   ```bash
   # ACME file must have specific permissions
   touch data/acme.json
   chmod 600 data/acme.json
   ```

4. **Deploy the service**:
   ```bash
   docker-compose up -d
   ```

### Verification

```bash
# Run validation script
chmod +x validate-config.sh
./validate-config.sh

# Check service status
docker-compose ps

# View logs
docker-compose logs -f traefik

# Test dashboard access
curl -k https://traefik-dashboard.internal.labratech.org
```

## 📊 Dashboard Access

- **URL**: `https://traefik-dashboard.internal.labratech.org`
- **Authentication**: Basic Auth (configured in `.env`)
- **Features**:
  - Service discovery status
  - Router and middleware configuration
  - Certificate management
  - Real-time metrics

## 🔧 Service Integration

Other services connect to Traefik using Docker labels:

```yaml
services:
  your-service:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.service-name.rule=Host(`service.internal.labratech.org`)"
      - "traefik.http.routers.service-name.tls=true"
      - "traefik.http.routers.service-name.tls.certresolver=cloudflare"
    networks:
      - proxy
```

## 🔍 Monitoring & Troubleshooting

> 📖 **Detailed troubleshooting guide available**: See [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md) for comprehensive issue resolution.

### Common Issues

#### 1. Certificate Generation Failures
```bash
# Check ACME logs
docker-compose logs traefik | grep -i acme

# Verify Cloudflare API token
docker-compose exec traefik cat /run/secrets/cf_api_token

# Check DNS propagation
dig TXT _acme-challenge.internal.labratech.org
```

#### 2. Service Discovery Issues
```bash
# Verify proxy network
docker network ls | grep proxy

# Check service labels
docker inspect service-name | grep -A 20 Labels

# View Traefik configuration
curl -u admin:password https://traefik-dashboard.internal.labratech.org/api/rawdata
```

#### 3. Dashboard Access Problems
```bash
# Test basic auth credentials
echo -n "admin:password" | base64

# Check router configuration
docker-compose logs traefik | grep -i dashboard
```

### Health Checks

```bash
# Service health
docker-compose ps

# Certificate status
docker-compose exec traefik cat /acme.json | jq '.cloudflare.Certificates'

# Network connectivity
docker-compose exec traefik ping 1.1.1.1
```

### Log Analysis

```bash
# Real-time logs
docker-compose logs -f traefik

# Error logs only
docker-compose logs traefik 2>&1 | grep -i error

# Certificate-related logs
docker-compose logs traefik 2>&1 | grep -i "certificate\|acme\|cloudflare"
```

## 🔒 Security Considerations

### Network Security
- **No new privileges**: Container runs with `no-new-privileges:true`
- **Read-only mounts**: Configuration files mounted as read-only
- **Isolated networks**: Uses external `proxy` network for service isolation

### SSL/TLS Security
- **Modern TLS**: Supports TLS 1.2+ with secure cipher suites
- **HSTS headers**: Enforces HTTPS connections
- **Certificate automation**: Automatic renewal prevents expired certificates

### Access Control
- **Dashboard protection**: Basic authentication required
- **API access**: Limited to authenticated users
- **Docker socket**: Read-only access to Docker daemon

### Best Practices
1. **Rotate API tokens** regularly
2. **Monitor certificate expiration** (auto-renewal should handle this)
3. **Review access logs** for suspicious activity
4. **Keep Traefik updated** to latest stable version
5. **Backup ACME certificates** stored in `acme.json`

## 🔄 Maintenance

### Updates
```bash
# Pull latest image
docker-compose pull

# Recreate container
docker-compose up -d --force-recreate
```

### Backup
```bash
# Backup certificates
cp data/acme.json data/acme.json.backup.$(date +%Y%m%d)

# Backup configuration
tar -czf traefik-config-backup-$(date +%Y%m%d).tar.gz data/ .env
```

### Certificate Renewal
Certificates auto-renew 30 days before expiration. Manual renewal:
```bash
# Force certificate renewal (if needed)
docker-compose restart traefik
```

## 🌟 Features

### Current Features
- ✅ Automatic SSL/TLS with Let's Encrypt
- ✅ Cloudflare DNS challenge
- ✅ HTTP to HTTPS redirection
- ✅ Docker service discovery
- ✅ Dashboard with authentication
- ✅ Real IP detection plugin
- ✅ Wildcard certificate support

### Optional Features (Commented)
- 🔄 HTTP/3 support (ports 443/udp)
- 🔄 File-based configuration (`config.yml`)
- 🔄 Staging ACME server for testing

## 🛠️ Management Scripts

### Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup-traefik.sh` | Automated initial setup | `chmod +x setup-traefik.sh && ./setup-traefik.sh` |
| `validate-config.sh` | Configuration validation | `chmod +x validate-config.sh && ./validate-config.sh` |

### Script Features

**Setup Script (`setup-traefik.sh`)**:
- ✅ Creates Docker proxy network
- ✅ Sets up SSL certificate storage with correct permissions
- ✅ Validates Cloudflare API token configuration
- ✅ Checks dashboard credentials
- ✅ Deploys and monitors initial certificate generation
- ✅ Provides post-deployment verification

**Validation Script (`validate-config.sh`)**:
- ✅ Checks all required files exist
- ✅ Validates file permissions (especially `acme.json`)
- ✅ Verifies Docker network configuration
- ✅ Tests Docker Compose syntax
- ✅ Validates environment variables
- ✅ Checks service status and accessibility

## 📚 Additional Resources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md) - Comprehensive troubleshooting guide
- [`AGENTS.md`](./AGENTS.md) - Agent guidelines for service management

---

**Note**: This service is critical infrastructure. Always test changes in a staging environment before applying to production.