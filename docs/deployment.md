# Deployment Guide

## Docker Compose (Signaling + Web)

```yaml
version: '3.8'

services:
  remotyy-signal:
    image: golang:1.22-alpine
    container_name: remotyy-signal
    ports:
      - "9000:9000"
    environment:
      - REMOTYY_AUTH_TOKEN=${REMOTYY_AUTH_TOKEN:-}
    volumes:
      - .:/app
    working_dir: /app
    command: sh -c "go run ./cmd/remotyy-signal --port 9000"
    restart: unless-stopped
    networks:
      - remotyy-net

  remotyy-web:
    image: node:20-alpine
    container_name: remotyy-web
    ports:
      - "3000:3000"
    volumes:
      - ./web:/app
    working_dir: /app
    command: sh -c "npm install && npx vite --host 0.0.0.0 --port 3000"
    restart: unless-stopped
    networks:
      - remotyy-net

networks:
  remotyy-net:
    driver: bridge
```

## Systemd Services

### remotyy-signal.service

```ini
[Unit]
Description=remotyy Signaling Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/remotyy
EnvironmentFile=/etc/remotyy/signal.env
ExecStart=/home/ubuntu/remotyy/remotyy-signal --port ${REMOTYY_PORT:-9000}
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

### remotyy-host.service

```ini
[Unit]
Description=remotyy Host Daemon
After=network.target remotyy-signal.service
Wants=remotyy-signal.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/remotyy
EnvironmentFile=/etc/remotyy/host.env
ExecStart=/home/ubuntu/remotyy/remotyy-host --signal ${REMOTYY_SIGNAL_URL} --name ${REMOTYY_HOST_NAME} --master-password ${REMOTYY_MASTER_PASSWORD}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## Manual Deployment

### Signaling Server

```bash
# Production (with auth)
REMOTYY_AUTH_TOKEN="$(openssl rand -hex 32)" ./remotyy-signal --port 9000

# With TLS termination via nginx/caddy
# Reverse proxy ws://localhost:9000 → wss://yourdomain.com/ws
```

### Host Daemon

```bash
# As a service (launchd on macOS)
cat > ~/Library/LaunchAgents/com.remotyy.host.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.remotyy.host</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/remotyy-host</string>
        <string>--signal</string>
        <string>ws://localhost:9000</string>
        <string>--name</string>
        <string>my-mac</string>
        <string>--master-password</string>
        <string>***</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST
launchctl load ~/Library/LaunchAgents/com.remotyy.host.plist
```

## Cloudflare Tunnel

```yaml
# config.yml for cloudflared
tunnel: YOUR_TUNNEL_ID
credentials-file: /home/ubuntu/.cloudflared/credentials.json

ingress:
  - hostname: remotyy.yourdomain.com
    service: http://localhost:3000
    originRequest:
      noTLSVerify: true
  - service: http_status:404
```
