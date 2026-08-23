# Nearo Production Deployment Guide

Target Subdomain: `nearo.asiverticals.me`  
Infrastructure: Docker, Cloudflare, PostgreSQL (PostGIS), Redis, FastAPI, Flutter

---

## 1. Cloudflare DNS & SSL Configuration

1. In the Cloudflare Dashboard for `asiverticals.me`:
   * Add an **A Record**:
     * **Name:** `nearo` (Resolves to `nearo.asiverticals.me`)
     * **IPv4 Address:** `<YOUR_SERVER_PUBLIC_IP>`
     * **Proxy Status:** Proxied (Orange Cloud enabled for DDoS & Edge Caching)
2. **SSL/TLS Mode:** Set encryption mode to **Full (Strict)**.
3. **WebSockets:** Ensure WebSockets are enabled under **Network** settings for realtime SOS dispatching.

---

## 2. Server Environment Setup (Ubuntu 22.04 / 24.04 LTS)

### 2.1 Install Docker Engine & Compose
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL [https://download.docker.com/linux/ubuntu/gpg](https://download.docker.com/linux/ubuntu/gpg) | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] [https://download.docker.com/linux/ubuntu](https://download.docker.com/linux/ubuntu) \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
3. Environment Variables Configuration
Create /backend/.env on the host machine:

Ini, TOML
# Production Environment Variables
PROJECT_NAME="Nearo API"
ENVIRONMENT="production"
DOMAIN="nearo.asiverticals.me"

# Security
SECRET_KEY="generate-a-strong-random-64-character-secret-key"
ALGORITHM="HS256"
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=30

# Database (PostGIS)
POSTGRES_SERVER="db"
POSTGRES_USER="nearo_admin"
POSTGRES_PASSWORD="secure_db_password_here"
POSTGRES_DB="nearo_db"
POSTGRES_PORT=5432
DATABASE_URL="postgresql+asyncpg://nearo_admin:secure_db_password_here@db:5432/nearo_db"

# Redis Cache & PubSub
REDIS_URL="redis://redis:6379/0"

# CORS
BACKEND_CORS_ORIGINS=["[https://nearo.asiverticals.me](https://nearo.asiverticals.me)"]
4. Database Initialization & PostGIS Extensions
Once containers are launched, run migrations and enable extensions:

Bash
# Execute schema migration inside PostgreSQL container
docker compose exec db psql -U nearo_admin -d nearo_db -f /docs/02_DATABASE_SCHEMA.sql
5. Application Launch with Docker Compose
Run the multi-container stack from the repository root:

Bash
# Build and start services in detached mode
docker compose up -d --build

# Verify container health status
docker compose ps

# Inspect live FastAPI backend logs
docker compose logs -f app
6. Verification & Healthcheck
Verify the API gateway response:

Bash
curl -I [https://nearo.asiverticals.me/api/v1/health](https://nearo.asiverticals.me/api/v1/health)
# Expected: HTTP/2 200 OK