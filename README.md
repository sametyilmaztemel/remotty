# remotyy

> **remote terminal, open source.**  
> Cross-platform host daemon + web client + CLI for encrypted remote terminal access via WebRTC.

remotyy, Macky'nin açık kaynak alternatifidir. Mac'inizin veya Linux sunucunuzun terminaline herhangi bir tarayıcıdan veya CLI'dan, güvenli ve şifreli bir WebRTC bağlantısıyla erişmenizi sağlar.

## Features

- **🔒 E2E Encrypted** — WebRTC DTLS-SRTP, end-to-end encrypted tunnel
- **🌐 Cross-platform host** — macOS, Linux (ARM64, AMD64), any machine
- **🖥 Web client** — Terminal in your browser via xterm.js
- **📟 CLI client** — Connect from terminal (coming soon)
- **🔑 Dual-layer auth** — Signaling auth + Master Password
- **📋 Device allow list** — Host explicitly approves devices
- **🕶 Blind signaling** — Server coordinates handshake only, traffic never touches cloud
- **🔄 Auto-reconnect** — Host reconnects to signaling server with backoff
- **🚀 Self-hosted** — Run your own signaling server, zero third-party dependency
- **🤖 Hermes integration** — Works with Hermes Agent on ARM (Oracle Cloud)

## Architecture

```
                    ┌──────────────────┐
                    │  Signaling Server │  (Go — self-hosted)
                    │  ws://host:9000   │
                    └───────┬──────────┘
                            │ WebSocket
                  ┌─────────┴─────────┐
                  ▼                   ▼
          ┌──────────────┐   ┌──────────────────┐
          │  Host Daemon │   │  Client           │
          │  (Mac/Linux) │   │  (Web / CLI)      │
          │              │   │                   │
          │  pty → shell │   │  xterm.js/TUI     │
          │  WebRTC      │◄──┤  WebRTC (P2P)     │
          │  DTLS-SRTP   │   │  DataChannel      │
          └──────────────┘   └──────────────────┘
```

## Quick Start

### 1. Signaling Server

```bash
# Run locally (dev mode)
cd remotyy
go run ./cmd/remotyy-signal --port 9000 --dev

# Or with auth token
REMOTYY_AUTH_TOKEN=mysecret go run ./cmd/remotyy-signal --port 9000
```

### 2. Host Daemon

On the machine you want to access remotely:

```bash
# Start host (connects to signaling server)
go run ./cmd/remotyy-host \
  --signal ws://signaling-server-ip:9000 \
  --name "my-mac"

# With master password
go run ./cmd/remotyy-host \
  --signal ws://signaling-server-ip:9000 \
  --name "my-server" \
  --master-password "my-secret-pw"
```

### 3. Web Client

```bash
cd web
npm install
npm run dev
# → opens http://localhost:3000
```

Enter the signaling server URL, click Connect, select a host, and you're in.

### 4. CLI Client

```bash
# List available hosts
go run ./cmd/remotyy ls --signal ws://localhost:9000

# Connect to a host
go run ./cmd/remotyy connect <host-id> --signal ws://localhost:9000
```

## Build

```bash
# Build all binaries
make build-all

# Cross-compile for specific platforms
make build-linux-arm64    # ARM64 Linux (Oracle Cloud)
make build-linux-amd64    # AMD64 Linux
make build-darwin-arm64   # Apple Silicon Mac
```

Binaries will be in `bin/`.

## Project Structure

```
remotyy/
├── cmd/
│   ├── remotyy/           # CLI client (list/connect)
│   ├── remotyy-host/      # Host daemon binary
│   └── remotyy-signal/    # Signaling server binary
├── internal/
│   ├── auth/              # Password hashing (bcrypt)
│   ├── config/            # Version info
│   ├── host/              # Host daemon logic
│   ├── protocol/          # Message types
│   ├── pty/               # PTY sessions
│   ├── signal/            # Signaling server
│   └── webrtc/            # WebRTC engine (pion)
├── web/                   # Web client (xterm.js)
│   ├── index.html
│   ├── style.css
│   └── app.js
├── docs/                  # Documentation
├── deploy/                # Deployment configs
│   ├── docker-compose.yml # Signaling server + web
│   └── systemd/           # systemd service files
├── Makefile
└── README.md
```

## Deployment on ARM (Oracle Cloud)

remotyy is designed to work seamlessly with your ARM Oracle Cloud instance:

### Signaling Server on ARM

```bash
# Build for ARM
make build-linux-arm64

# Deploy to ARM
scp bin/remotyy-signal-linux-arm64 arm-oracle:~/remotyy-signal
scp deploy/remotyy-signal.service arm-oracle:

# Install systemd service
ssh arm-oracle
sudo mv remotyy-signal.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now remotyy-signal
```

### Host Daemon on ARM

```bash
scp bin/remotyy-host-linux-arm64 arm-oracle:~/remotyy-host
ssh arm-oracle
./remotyy-host --signal ws://localhost:9000 --name "arm-oracle" \
  --master-password "your-password"
```

### Hermes Integration

remotyy includes a Hermes skill for agent-based remote terminal access:

```bash
# Hermes connects to ARM's remotyy host
remotyy connect <arm-host-id> --signal ws://arm-oracle:9000
```

See [docs/hermes-integration.md](docs/hermes-integration.md) for details.

## Security

| Layer | Mechanism |
|-------|-----------|
| Transport | WebRTC DTLS-SRTP (E2E encrypted) |
| Signaling | Optional bearer token auth |
| Device auth | Host approve/reject per device ID |
| Terminal auth | Master Password (bcrypt, never leaves host) |
| Data path | Blind signaling — server sees only handshake |
| NAT traversal | STUN, ICE, no open ports required |

## Comparison: remotyy vs Macky

| Feature | Macky ($29) | remotyy (free) |
|---------|-------------|----------------|
| Mac host | ✅ macOS 15+ | ✅ macOS (any) |
| Linux host | ❌ | ✅ ARM64 + AMD64 |
| Web client | ❌ (iOS only) | ✅ Any browser |
| CLI client | ❌ | ✅ Terminal |
| iOS client | ✅ App Store | ✅ Via web |
| Self-hosted signal | ❌ | ✅ |
| Open source | ❌ | ✅ MIT |
| Hermes integration | ❌ | ✅ |
| Screen sharing | ✅ | 🚧 (planned) |
| Device allow list | ✅ | ✅ |
| Master password | ✅ | ✅ |
| Blind signaling | ✅ | ✅ |

## Roadmap

- [x] Signaling server (WebSocket, rooms, host registry)
- [x] Host daemon (pty, WebRTC, auth)
- [x] Web client (xterm.js terminal)
- [x] CLI client (list/connect)
- [x] Master password auth
- [ ] Screen sharing (WebRTC video track)
- [ ] iOS client (web app PWA)
- [ ] File transfer (data channel)
- [ ] End-to-end tests
- [ ] Docker images
- [ ] Hermes skill package

## Development

```bash
# Run all tests
make test

# Dev mode (signaling in background)
make dev &
sleep 2
make dev-host &

# Open web client
cd web && npm run dev
```

## License

MIT — see [LICENSE](LICENSE)

---

Built with ❤️ and [pion/webrtc](https://github.com/pion/webrtc) (Go) + [xterm.js](https://xtermjs.org/)
