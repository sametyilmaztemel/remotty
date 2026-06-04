# Hermes Integration Guide

remotyy, Hermes Agent ile ARM Oracle Cloud sunucunuz üzerinden çalışacak şekilde tasarlanmıştır.

## Architecture with Hermes

```
┌─────────────────────────────────────────────────┐
│                  ARM Oracle Cloud                │
│                                                   │
│  ┌─────────────┐   ┌──────────────┐              │
│  │  remotyy    │   │  Hermes      │              │
│  │  Signaling  │   │  Gateway     │              │
│  │  :9000      │   │  :8421       │              │
│  └──────┬──────┘   └──────┬───────┘              │
│         │                 │                       │
│  ┌──────▼─────────────────▼───────┐               │
│  │  remotyy Host (ARM)            │               │
│  │  - Terminal access             │               │
│  │  - pty → bash/zsh              │               │
│  └────────────────────────────────┘               │
└───────────────────────────────────────────────────┘
         │
         │ WebRTC P2P (encrypted)
         ▼
┌─────────────────────────────────────────────────┐
│  Client (Any Browser / CLI)                      │
│  - Web UI at remotyy.yourdomain.com              │
│  - CLI from anywhere                             │
└─────────────────────────────────────────────────┘
```

## Setup on ARM

### 1. Build for ARM

```bash
# On Mac or directly on ARM
make build-linux-arm64
```

### 2. Deploy to ARM

```bash
scp bin/remotyy-signal-linux-arm64 arm-oracle:~/remotyy/remotyy-signal
scp bin/remotyy-host-linux-arm64 arm-oracle:~/remotyy/remotyy-host
scp deploy/remotyy-signal.service arm-oracle:
scp deploy/remotyy-host.service arm-oracle:
```

### 3. Install systemd services

```bash
ssh arm-oracle

# Signaling server
sudo mv remotyy-signal.service /etc/systemd/system/
sudo mkdir -p /etc/remotyy

# Configuration
cat > /etc/remotyy/signal.env << 'EOF'
REMOTYY_AUTH_TOKEN=your-secret-token
REMOTYY_PORT=9000
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now remotyy-signal
sudo systemctl status remotyy-signal

# Host daemon
sudo mv remotyy-host.service /etc/systemd/system/
cat > /etc/remotyy/host.env << 'EOF'
REMOTYY_SIGNAL_URL=ws://localhost:9000
REMOTYY_MASTER_PASSWORD=your-master-password
REMOTYY_HOST_NAME=arm-oracle
EOF

sudo systemctl enable --now remotyy-host
sudo systemctl status remotyy-host
```

### 4. Cloudflare Tunnel (optional)

If you want to expose the web client via Cloudflare Tunnel:

```yaml
# Add to your CF tunnel config
ingress:
  - hostname: remotyy.sametyilmaztemel.com
    service: http://localhost:3000
  - service: http_status:404
```

### 5. Access from Mac

```bash
# List ARM hosts via tunnel
remotyy ls --signal wss://remotyy.sametyilmaztemel.com/ws

# Connect
remotyy connect <host-id> --signal wss://remotyy.sametyilmaztemel.com/ws
```

## Hermes Skill

```bash
# Install remotyy Hermes skill
hermes skill add remotyy --repo sametyilmaztemel/remotyy

# Use from Hermes
remotyy ls  # List available hosts
remotyy connect arm-oracle  # Connect to ARM host
```

## Shared Memory (Honcho)

remotyy device registry and host information is synced via Honcho shared memory:

```json
{
  "remotyy": {
    "hosts": {
      "arm-oracle": {
        "platform": "linux/arm64",
        "signal_url": "ws://localhost:9000",
        "features": ["terminal"],
        "last_seen": "2026-06-04T..."
      }
    }
  }
}
```

## Security Notes

- **Always use REMOTYY_AUTH_TOKEN** in production to prevent unauthorized signaling access
- **Set a strong master password** on the host daemon
- **Use Cloudflare Tunnel** or WireGuard instead of exposing ports directly
- The host makes **outbound connections only** — no inbound ports needed
- WebRTC traffic is **E2E encrypted** — signaling server cannot read it
