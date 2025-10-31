# 🌐 Network Architecture & Container Discovery

## Overview
This document explains how the docker-socket-proxy and Traefik network configuration enables proper container discovery across different networks.

## Network Configuration

### Current Setup ✅
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   dockerproxy   │    │     traefik      │    │   app services  │
│                 │    │                  │    │   (n8n, kasm)   │
│ Network:        │    │ Networks:        │    │ Network:        │
│ - dockerproxy   │◄──►│ - proxy          │◄──►│ - proxy         │
│                 │    │ - dockerproxy    │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                                               │
         │              Docker Socket                    │
         └──────────────────┬────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │ Docker      │
                    │ Daemon      │
                    │ (All        │
                    │ Containers) │
                    └─────────────┘
```

## How Container Discovery Works

### 1. Docker Socket Access 🔑
- **dockerproxy** has read-only access to `/var/run/docker.sock`
- This gives it access to **ALL containers** in the Docker daemon
- Network membership is **irrelevant** for discovery via Docker socket

### 2. Network Communication 🔗
- **dockerproxy** ↔ **traefik**: Communication via `dockerproxy` network
- **traefik** ↔ **app services**: Traffic routing via `proxy` network
- **traefik** acts as a bridge between the two networks

### 3. Service Discovery Process 🔍
1. **dockerproxy** queries Docker daemon for all containers
2. **dockerproxy** filters containers with `traefik.enable=true` labels
3. **traefik** receives container info via `tcp://dockerproxy:2375`
4. **traefik** routes traffic to services on the `proxy` network

## Key Configuration Points

### Docker Socket Proxy (`dockerproxy`)
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro  # 🔑 Full Docker access
networks:
  - dockerproxy  # 🔒 Isolated communication with Traefik
environment:
  CONTAINERS: 1  # ✅ Enable container discovery
  NETWORKS: 1    # ✅ Enable network discovery
  EVENTS: 1      # ✅ Enable real-time updates
```

### Traefik Configuration
```yaml
# traefik.yml
providers:
  docker:
    endpoint: "tcp://dockerproxy:2375"  # 🔗 Connect via proxy
    network: "proxy"                    # 🌐 Default network for services
    watch: true                         # 🔄 Real-time discovery
```

### Application Services
```yaml
networks:
  - proxy  # 🌐 Must be on proxy network for Traefik routing
labels:
  - "traefik.enable=true"  # 🏷️ Enable discovery
```

## Why This Configuration Works

### ✅ Security Benefits
- **No direct Docker socket access** in Traefik container
- **Minimal permissions** for docker-socket-proxy
- **Network isolation** between proxy communication and service traffic

### ✅ Discovery Capabilities
- **Full container visibility** via Docker socket
- **Cross-network discovery** (dockerproxy can see containers on any network)
- **Real-time updates** via Docker events API

### ✅ Traffic Flow
- **Secure proxy communication** on isolated `dockerproxy` network
- **Service traffic routing** on shared `proxy` network
- **Clean separation** of concerns

## Troubleshooting

### If services aren't being discovered:
1. **Check labels**: Ensure `traefik.enable=true` is set
2. **Check network**: Ensure service is on `proxy` network
3. **Check proxy health**: `docker logs dockerproxy`
4. **Check Traefik logs**: `docker logs traefik`

### Common Issues:
- **Missing `proxy` network**: Create with `docker network create proxy`
- **Incorrect endpoint**: Ensure Traefik points to `tcp://dockerproxy:2375`
- **Permission issues**: Verify docker-socket-proxy has socket access

## Verification Commands

```bash
# Check networks
docker network ls

# Check container discovery
curl -s http://localhost:2375/containers/json | jq '.[].Names'

# Check Traefik configuration
docker exec traefik cat /traefik.yml

# Check service health
docker-compose ps
docker-compose logs dockerproxy
docker-compose logs traefik
```

This architecture provides secure, efficient container discovery while maintaining proper network isolation and security boundaries.