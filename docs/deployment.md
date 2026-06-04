# Deployment Guide

## Docker Compose

```yaml
services:
  remotyy-signal:
    build:
      context: .
      dockerfile: deploy/Dockerfile.signal
    ports:
      - "9000:9000"
    environment:
      - REMOTYY_AUTH_TOKEN=${REMOTYY_AUTH_TOKEN:-}
    restart: unless-stopped

  remotyy-web:
    image: nginx:alpine
    ports:
      - "3000:80"
    volumes:
      - ./web/dist:/usr/share/nginx/html:ro
```

## systemd (Linux)

```bash
sudo cp deploy/remotyy-signal.service /etc/systemd/system/
sudo systemctl enable --now remotyy-signal

sudo cp deploy/remotyy-host.service /etc/systemd/system/
sudo systemctl enable --now remotyy-host
```

## launchd (macOS)

```bash
cp deploy/com.remotyy.host.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.remotyy.host.plist
```

## Cloudflare Tunnel

```yaml
ingress:
  - hostname: remotyy.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
```
