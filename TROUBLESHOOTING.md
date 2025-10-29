# 🔧 Traefik Troubleshooting Guide

## 🚨 Common Issues and Solutions

### 1. Certificate Generation Failures

#### Symptoms
- Dashboard shows "Default Certificate" instead of Let's Encrypt certificate
- Logs show ACME challenge failures
- Browser shows certificate warnings

#### Diagnosis
```bash
# Check ACME logs
docker-compose logs traefik | grep -i "acme\|certificate\|challenge"

# Verify Cloudflare API token
docker-compose exec traefik cat /run/secrets/cf_api_token

# Test DNS resolution
dig TXT _acme-challenge.internal.labratech.org @1.1.1.1
```

#### Solutions

**Invalid Cloudflare API Token**
```bash
# Recreate token with correct permissions:
# Zone:Zone:Read (all zones)
# Zone:DNS:Edit (specific zone: labratech.org)
echo "new_token_here" > cf_api_token.txt
docker-compose restart traefik
```

**DNS Propagation Issues**
```bash
# Enable propagation check bypass in traefik.yml
# Uncomment these lines:
# disablePropagationCheck: true
# delayBeforeCheck: 60s
```

**Rate Limiting from Let's Encrypt**
```bash
# Switch to staging server temporarily
# In traefik.yml, change:
caServer: https://acme-staging-v02.api.letsencrypt.org/directory
```

### 2. Dashboard Access Issues

#### Symptoms
- 404 errors when accessing dashboard
- Authentication not working
- Connection timeouts

#### Diagnosis
```bash
# Check container status
docker-compose ps

# Test local access
curl -k https://localhost:443 -H "Host: traefik-dashboard.internal.labratech.org"

# Check DNS resolution
nslookup traefik-dashboard.internal.labratech.org
```

#### Solutions

**Authentication Problems**
```bash
# Generate new credentials
htpasswd -nb admin newpassword | sed -e s/\\$/\\$\\$/g

# Update .env file
TRAEFIK_DASHBOARD_CREDENTIALS="admin:$$2y$$10$$..."

# Restart service
docker-compose restart traefik
```

**DNS Resolution Issues**
```bash
# Add to /etc/hosts (temporary fix)
echo "127.0.0.1 traefik-dashboard.internal.labratech.org" >> /etc/hosts

# Or configure local DNS server
```

### 3. Service Discovery Problems

#### Symptoms
- Services not appearing in Traefik dashboard
- 404 errors for configured services
- Routes not being created

#### Diagnosis
```bash
# Check proxy network
docker network inspect proxy

# Verify service labels
docker inspect service-name | grep -A 20 Labels

# Check Traefik configuration
curl -s http://localhost:8080/api/rawdata | jq '.http.routers'
```

#### Solutions

**Network Issues**
```bash
# Ensure service is on proxy network
networks:
  - proxy

# Recreate proxy network if needed
docker network rm proxy
docker network create proxy
```

**Label Configuration**
```bash
# Verify required labels
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.service.rule=Host(\`service.domain.com\`)"
  - "traefik.http.routers.service.tls=true"
  - "traefik.http.routers.service.tls.certresolver=cloudflare"
```

### 4. SSL/TLS Issues

#### Symptoms
- Mixed content warnings
- Certificate errors
- Insecure connections

#### Diagnosis
```bash
# Check certificate details
openssl s_client -connect traefik-dashboard.internal.labratech.org:443 -servername traefik-dashboard.internal.labratech.org

# Verify ACME storage
docker-compose exec traefik cat /acme.json | jq '.cloudflare.Certificates'
```

#### Solutions

**Force Certificate Regeneration**
```bash
# Remove existing certificates
docker-compose down
rm data/acme.json
touch data/acme.json
chmod 600 data/acme.json
docker-compose up -d
```

**Fix Middleware Configuration**
```bash
# Ensure HTTPS redirection
- "traefik.http.middlewares.https-redirect.redirectscheme.scheme=https"
- "traefik.http.routers.service.middlewares=https-redirect"
```

### 5. Performance Issues

#### Symptoms
- Slow response times
- High CPU/memory usage
- Connection timeouts

#### Diagnosis
```bash
# Check resource usage
docker stats traefik

# Monitor connection counts
docker-compose exec traefik netstat -an | grep :443 | wc -l

# Check logs for errors
docker-compose logs traefik | grep -i "error\|timeout\|fail"
```

#### Solutions

**Resource Limits**
```yaml
# Add to docker-compose.yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'
```

**Connection Tuning**
```yaml
# In traefik.yml
serversTransport:
  maxIdleConnsPerHost: 200
  idleConnTimeout: 90s
```

## 🔍 Diagnostic Commands

### Quick Health Check
```bash
#!/bin/bash
echo "🏥 Traefik Health Check"
echo "======================"

# Container status
echo "📦 Container Status:"
docker-compose ps

# Network connectivity
echo "🌐 Network Test:"
docker-compose exec traefik ping -c 1 1.1.1.1

# Certificate status
echo "🔒 Certificate Status:"
docker-compose exec traefik ls -la /acme.json

# Dashboard access
echo "📊 Dashboard Test:"
curl -k -s -o /dev/null -w "Status: %{http_code}\n" https://traefik-dashboard.internal.labratech.org

# Recent errors
echo "🚨 Recent Errors:"
docker-compose logs --tail=20 traefik | grep -i error
```

### Certificate Debugging
```bash
#!/bin/bash
echo "🔒 Certificate Debugging"
echo "========================"

# ACME file content
echo "📄 ACME Certificates:"
docker-compose exec traefik cat /acme.json | jq '.cloudflare.Certificates[] | {domains: .domain.main, san: .domain.sans, notAfter: .certificate}'

# DNS challenge test
echo "🌐 DNS Challenge Test:"
dig TXT _acme-challenge.internal.labratech.org @1.1.1.1

# Certificate validation
echo "✅ Certificate Validation:"
echo | openssl s_client -connect traefik-dashboard.internal.labratech.org:443 -servername traefik-dashboard.internal.labratech.org 2>/dev/null | openssl x509 -noout -dates
```

### Service Discovery Debug
```bash
#!/bin/bash
echo "🔍 Service Discovery Debug"
echo "=========================="

# List all routers
echo "🛣️  Active Routers:"
curl -s http://localhost:8080/api/http/routers | jq '.[] | {name: .name, rule: .rule, service: .service}'

# List all services
echo "🎯 Active Services:"
curl -s http://localhost:8080/api/http/services | jq '.[] | {name: .name, servers: .loadBalancer.servers}'

# Check proxy network members
echo "🌐 Proxy Network Members:"
docker network inspect proxy | jq '.[].Containers'
```

## 🛠️ Recovery Procedures

### Complete Reset
```bash
#!/bin/bash
echo "🔄 Performing complete Traefik reset..."

# Stop service
docker-compose down

# Backup current config
mkdir -p backups/$(date +%Y%m%d_%H%M%S)
cp -r data/ .env backups/$(date +%Y%m%d_%H%M%S)/

# Reset certificates
rm -f data/acme.json
touch data/acme.json
chmod 600 data/acme.json

# Restart service
docker-compose up -d

echo "✅ Reset complete. Monitor logs: docker-compose logs -f traefik"
```

### Configuration Rollback
```bash
#!/bin/bash
echo "⏪ Rolling back to previous configuration..."

# Stop current service
docker-compose down

# Restore from backup (adjust path as needed)
BACKUP_DIR="backups/20241029_120000"  # Replace with actual backup
cp -r $BACKUP_DIR/* .

# Restart with previous config
docker-compose up -d

echo "✅ Rollback complete"
```

## 📞 Getting Help

### Log Collection
```bash
# Collect comprehensive logs for support
mkdir -p support_logs
docker-compose logs traefik > support_logs/traefik.log
docker-compose config > support_logs/compose_config.yaml
docker network inspect proxy > support_logs/network_info.json
docker-compose ps > support_logs/container_status.txt
tar -czf traefik_support_$(date +%Y%m%d_%H%M%S).tar.gz support_logs/
```

### Useful Resources
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cloudflare API Docs](https://developers.cloudflare.com/api/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Docker Networking Guide](https://docs.docker.com/network/)

### Community Support
- [Traefik Community Forum](https://community.traefik.io/)
- [Docker Community](https://forums.docker.com/)
- [Reddit r/selfhosted](https://reddit.com/r/selfhosted)

---

**💡 Pro Tip**: Always test changes in a staging environment and keep backups of working configurations!