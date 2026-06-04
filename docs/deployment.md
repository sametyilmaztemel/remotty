# remotyy Deployment Guide

## Quick Start

### 1. Signal Server

```bash
# Build
go build -o remotyy ./cmd/remotyy

# Run with config
./remotyy serve --config remotyy.yaml
```

Minimal config:
```yaml
signal:
  port: 9000
  auth_token: "change-me-in-production"
  rate_limit: 60
  allowed_origins:
    - "https://your-domain.com"
```

### 2. Host Daemon

```bash
./remotyy host --config host.yaml
```

Host config:
```yaml
host:
  signal_url: ws://your-server:9000
  name: "my-server"
  master_password: "a-strong-password"
  require_auth: true
  max_sessions: 5
  features:
    - terminal
    - screen
    - file
```

### 3. Client

```bash
# TUI client
./remotyy connect --host my-server --signal ws://your-server:9000

# Web client — serve via signal server or separately
cd web && npm run build
# Place dist/ in signal.web_dir
```

---

## Production Deployment

### Systemd Service (Signal Server)

```ini
# /etc/systemd/system/remotyy-signal.service
[Unit]
Description=remotyy Signal Server
After=network.target

[Service]
Type=simple
User=remotyy
Group=remotyy
ExecStart=/usr/local/bin/remotyy serve --config /etc/remotyy/signal.yaml
Restart=always
RestartSec=5
LimitNOFILE=65535

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/remotyy /var/lib/remotyy
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

```bash
sudo useradd -r -s /bin/false remotyy
sudo mkdir -p /etc/remotyy /var/log/remotyy /var/lib/remotyy
sudo chown remotyy:remotyy /var/log/remotyy /var/lib/remotyy
sudo systemctl daemon-reload
sudo systemctl enable --now remotyy-signal
```

### Systemd Service (Host Daemon)

```ini
# /etc/systemd/system/remotyy-host.service
[Unit]
Description=remotyy Host Daemon
After=network.target remotyy-signal.service

[Service]
Type=simple
User=remotyy
Group=remotyy
ExecStart=/usr/local/bin/remotyy host --config /etc/remotyy/host.yaml
Restart=always
RestartSec=5

# PTY access needs devpts
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/var/log/remotyy /var/lib/remotyy /dev/pts
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

### Docker Compose

```yaml
version: "3.8"

services:
  signal:
    image: remotyy/remotyy:latest
    command: serve --config /etc/remotyy.yaml
    ports:
      - "9000:9000"
    volumes:
      - ./remotyy.yaml:/etc/remotyy.yaml:ro
      - signal-data:/var/lib/remotyy
    restart: always
    security_opt:
      - no-new-privileges:true

  host:
    image: remotyy/remotyy:latest
    command: host --config /etc/host.yaml
    volumes:
      - ./host.yaml:/etc/host.yaml:ro
      - host-data:/var/lib/remotyy
    depends_on:
      - signal
    restart: always
    # PTY support
    privileged: false
    devices:
      - /dev/pts:/dev/pts

volumes:
  signal-data:
  host-data:
```

### Reverse Proxy (Nginx)

```nginx
server {
    listen 443 ssl http2;
    server_name remotyy.example.com;

    ssl_certificate /etc/ssl/certs/remotyy.pem;
    ssl_certificate_key /etc/ssl/private/remotyy.key;

    # Web UI
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket
    location /ws {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

### Cloudflare Tunnel

```bash
cloudflared tunnel create remotyy
cloudflared tunnel route dns remotyy remotyy.example.com

# ~/.cloudflared/config.yml
tunnel: remotyy
credentials-file: ~/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: remotyy.example.com
    service: http://localhost:9000
  - service: http_status:404
```

---

## Security Checklist

- [ ] `auth_token` set to a strong random value
- [ ] `allowed_origins` configured (not `*`)
- [ ] `dev_mode` is `false`
- [ ] TLS enabled (or behind reverse proxy with TLS)
- [ ] `rate_limit` set (60-120 req/min recommended)
- [ ] Host `require_auth` is `true` with strong password
- [ ] `max_sessions` limited per host
- [ ] Firewall: only expose port 443/80 (reverse proxy)
- [ ] Log rotation configured
- [ ] Regular updates applied

## Monitoring

```bash
# Health check
curl http://localhost:9000/health

# List connected hosts
curl http://localhost:9000/api/hosts
```

## Troubleshooting

**WebSocket connection refused:**
- Check auth token matches between client and server
- Verify `allowed_origins` includes client origin
- Check rate limit isn't too low

**Host not appearing in list:**
- Verify `signal_url` is reachable from host
- Check host logs for connection errors
- Ensure heartbeat is working (default 15s interval)

**WebRTC connection fails:**
- Verify STUN/TURN servers are accessible
- Check firewall allows UDP traffic for ICE
- For NAT traversal issues, consider adding TURN server
