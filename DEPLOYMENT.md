# Dendrite Matrix Server Docker Deployment Guide

Complete containerized deployment of Dendrite Matrix server with WhatsApp bridge, Element Web, and Traefik reverse proxy with HTTPS.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   Internet (HTTPS)                      │
└────────────┬──────────────────────┬────────────────────┘
             │                      │
             ▼                      ▼
    app.yifanyiscrm.com    api.yifanyiscrm.com
             │                      │
┌────────────▼──────────────────────▼────────────────────┐
│                 Traefik (Reverse Proxy)                 │
│                  - SSL Termination                      │
│                  - Let's Encrypt                        │
└────────┬──────────────┬──────────────┬────────────────┘
         │              │              │
         ▼              ▼              ▼
┌─────────────┐ ┌──────────────┐ ┌──────────────┐
│ Element Web │ │   Dendrite   │ │   WhatsApp   │
│             │ │ Matrix Server│ │    Bridge    │
└─────────────┘ └──────┬───────┘ └──────┬───────┘
                       │                 │
                       ▼                 ▼
                ┌──────────────────────────┐
                │      PostgreSQL          │
                │    - dendrite DB         │
                │    - mautrix_whatsapp DB │
                └──────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker & Docker Compose installed
- Domains `api.yifanyiscrm.com` and `app.yifanyiscrm.com` pointing to server
- Ports 80, 443, 8448 open in firewall

### Deployment Steps

1. **Initialize Setup**
   ```bash
   chmod +x scripts/setup.sh scripts/deploy.sh
   sudo ./scripts/setup.sh
   ```

2. **Configure Environment**
   ```bash
   # Edit .env file
   nano .env
   # Update LETSENCRYPT_EMAIL
   ```

3. **Deploy Services**
   ```bash
   sudo ./scripts/deploy.sh
   ```

4. **Create Admin User**
   ```bash
   docker exec -it dendrite-server create-account \
     --config /etc/dendrite/dendrite.yaml \
     --username admin --admin
   ```

## Configuration Files

### Directory Structure

```
dendrite/
├── docker-compose.yml          # Main Docker Compose configuration
├── Dockerfile.dendrite         # Dendrite build configuration
├── .env                        # Environment variables
├── init-db.sql                # Database initialization
├── config/
│   ├── dendrite.yaml          # Dendrite server configuration
│   ├── mautrix-whatsapp.yaml # WhatsApp bridge configuration
│   ├── element-config.json   # Element Web configuration
│   ├── traefik/
│   │   └── dynamic.yml       # Traefik dynamic configuration
│   └── appservices/          # Application service registrations
├── scripts/
│   ├── setup.sh              # Initial setup script
│   └── deploy.sh             # Deployment script
└── data/                     # Persistent data (created at runtime)
    ├── dendrite/
    ├── traefik/
    └── whatsapp/
```

### Key Configuration Points

#### Dendrite (`config/dendrite.yaml`)
- Server name: `api.yifanyiscrm.com`
- Database: PostgreSQL
- Matrix spec v1.4 support enabled
- Refresh token support (MSC2918)
- Threading support (MSC2836)

#### WhatsApp Bridge (`config/mautrix-whatsapp.yaml`)
- Bridge user prefix: `whatsapp_`
- Double puppeting enabled
- End-to-end encryption support
- History sync: 30 days

#### Element Web (`config/element-config.json`)
- Default server: `api.yifanyiscrm.com`
- All modern features enabled
- Custom branding supported

#### Traefik
- Automatic SSL via Let's Encrypt
- HTTP to HTTPS redirect
- Security headers configured
- Rate limiting enabled

## Service Management

### Start Services
```bash
docker-compose up -d
```

### Stop Services
```bash
docker-compose down
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f dendrite
docker-compose logs -f mautrix-whatsapp
docker-compose logs -f traefik
```

### Restart Services
```bash
docker-compose restart
docker-compose restart dendrite
```

### Update Services
```bash
docker-compose pull
docker-compose up -d
```

## WhatsApp Bridge Usage

1. Login to Element Web at https://app.yifanyiscrm.com
2. Start chat with `@whatsappbot:api.yifanyiscrm.com`
3. Send `login` to receive QR code
4. Scan with WhatsApp mobile app
5. WhatsApp chats will appear as Matrix rooms

### Bridge Commands
- `login` - Get QR code for login
- `logout` - Disconnect WhatsApp
- `ping` - Check bridge status
- `help` - Show all commands

## Database Management

### Backup
```bash
# Backup all databases
docker exec dendrite-postgres pg_dumpall -U dendrite > backup_$(date +%Y%m%d).sql

# Backup specific database
docker exec dendrite-postgres pg_dump -U dendrite dendrite > dendrite_backup.sql
docker exec dendrite-postgres pg_dump -U dendrite mautrix_whatsapp > whatsapp_backup.sql
```

### Restore
```bash
# Restore from backup
docker exec -i dendrite-postgres psql -U dendrite < backup.sql
```

### Database Access
```bash
# Connect to PostgreSQL
docker exec -it dendrite-postgres psql -U dendrite -d dendrite
```

## SSL Certificate Management

Traefik automatically manages SSL certificates via Let's Encrypt.

### Certificate Location
```
./data/traefik/letsencrypt/acme.json
```

### Force Certificate Renewal
```bash
# Remove existing certificates
rm ./data/traefik/letsencrypt/acme.json

# Restart Traefik
docker-compose restart traefik
```

### Using Staging Certificates (Testing)
Uncomment in `docker-compose.yml`:
```yaml
- "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
```

## Monitoring & Health Checks

### Service Health
```bash
# Check all services
docker-compose ps

# Health endpoint
curl https://api.yifanyiscrm.com/_matrix/client/versions
```

### Metrics
```bash
# Dendrite metrics (if enabled)
curl http://localhost:8008/metrics
```

### Federation Tester
Test federation at: https://federationtester.matrix.org/

## Security Recommendations

1. **Change Default Passwords**
   - Update all tokens in `.env`
   - Set strong PostgreSQL password
   - Configure Traefik dashboard password

2. **Firewall Rules**
   ```bash
   # Allow only required ports
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw allow 8448/tcp
   ufw enable
   ```

3. **Regular Updates**
   ```bash
   # Update Docker images weekly
   docker-compose pull
   docker-compose up -d
   ```

4. **Backup Strategy**
   - Daily database backups
   - Weekly full system backups
   - Store backups off-site

5. **Monitoring**
   - Set up log aggregation
   - Configure alerting
   - Monitor disk space

## Troubleshooting

### Common Issues

#### Dendrite Won't Start
```bash
# Check logs
docker-compose logs dendrite

# Verify configuration
docker exec dendrite-server dendrite \
  --config /etc/dendrite/dendrite.yaml --verify
```

#### SSL Certificate Issues
```bash
# Check Traefik logs
docker-compose logs traefik

# Verify DNS
nslookup api.yifanyiscrm.com
nslookup app.yifanyiscrm.com
```

#### WhatsApp Bridge Issues
```bash
# Check bridge logs
docker-compose logs mautrix-whatsapp

# Restart bridge
docker-compose restart mautrix-whatsapp
```

#### Database Connection Issues
```bash
# Check PostgreSQL
docker-compose logs postgres

# Test connection
docker exec dendrite-postgres pg_isready -U dendrite
```

### Reset Everything
```bash
# Stop and remove all containers and volumes
docker-compose down -v

# Remove all data
rm -rf data/

# Start fresh
./scripts/setup.sh
./scripts/deploy.sh
```

## Performance Tuning

### PostgreSQL Optimization
Add to `docker-compose.yml`:
```yaml
postgres:
  command:
    - "postgres"
    - "-c"
    - "max_connections=200"
    - "-c"
    - "shared_buffers=512MB"
    - "-c"
    - "effective_cache_size=2GB"
    - "-c"
    - "work_mem=4MB"
```

### Dendrite Optimization
In `config/dendrite.yaml`:
```yaml
global:
  database:
    max_open_conns: 100
    max_idle_conns: 20
    conn_max_lifetime: -1
```

### Docker Resources
```yaml
services:
  dendrite:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

## Matrix Features Support

This deployment supports Matrix v1.4 specification including:
- ✅ Refresh tokens (MSC2918)
- ✅ Threading (MSC2836)
- ✅ Per-thread notifications (MSC3771)
- ✅ Private receipts (MSC2285)
- ✅ End-to-end encryption
- ✅ Voice/Video calls (via Element)
- ✅ File sharing
- ✅ Reactions
- ✅ Edits and redactions
- ✅ Spaces

## Support & Resources

- [Dendrite Documentation](https://github.com/matrix-org/dendrite)
- [Matrix Specification](https://spec.matrix.org/)
- [Element Web](https://element.io/)
- [mautrix-whatsapp](https://docs.mau.fi/bridges/go/whatsapp/index.html)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

## License

Configuration files are provided under MIT License.
Individual components have their own licenses:
- Dendrite: Apache 2.0
- Element Web: Apache 2.0
- mautrix-whatsapp: AGPL-3.0
- Traefik: MIT