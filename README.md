# remotyy

> **Remote terminal & screen access via WebRTC**  
> Cross-platform host daemon + web/CLI/native clients.  
> Open-source alternative to Macky.

remotyy gives you secure, encrypted remote access to any machine — your Mac, a Linux server, a Raspberry Pi, or a cloud VM — directly from your browser, terminal, or native app. No open ports, no VPN, no SSH key management.

```
                    ┌──────────────────┐
                    │  Signaling Server│  (self-hosted or cloud)
                    │  ws://host:9000  │
                    └───────┬──────────┘
                            │ WebSocket (blind relay)
                  ┌─────────┴─────────┐
                  ▼                   ▼
          ┌──────────────┐   ┌──────────────────┐
          │  Host Daemon  │   │  Client(s)        │
          │  (target mac) │   │  Web / CLI / iOS  │
          │  pty → shell  │   │  macOS / TUI      │
          │  WebRTC P2P   │◄──┤  xterm.js/Term    │
          │  DTLS-SRTP    │   │  WebRTC DataChan  │
          └──────────────┘   └──────────────────┘
```

## Features

- **🔒 E2E Encrypted** — WebRTC DTLS-SRTP, end-to-end encrypted tunnel
- **🌐 Cross-platform host** — macOS, Linux (ARM64/AMD64), Windows
- **🖥 Web client** — Terminal in your browser via xterm.js
- **📟 CLI client** — `remotyy connect` from any terminal
- **📱 iOS app** — Native SwiftUI client (via Xcode)
- **🖥 macOS app** — Menu bar host controller (via Xcode)
- **🦀 Tauri desktop** — Cross-platform native wrapper (Rust)
- **🗄️ Config management** — YAML + env vars + CLI flags
- **🔑 Dual-layer auth** — Signaling token + Master Password (bcrypt)
- **📋 Device allow list** — Explicitly approve devices
- **🕶 Blind signaling** — Server coordinates handshake only
- **📹 Screen sharing** — macOS + Linux (in progress)
- **📁 File transfer** — Chunked with SHA256 checksums (in progress)
- **📝 Session recording** — Full terminal capture & replay (in progress)
- **📊 REST API** — Health checks, host listing, metrics

## Quick Start

### 1. Signaling Server

```bash
# Clone and build
git clone https://github.com/remotyy/remotyy.git
cd remotyy
go build ./cmd/remotyy

# Start signaling server (dev mode)
./remotyy signal --dev --port 9000
```

### 2. Host Daemon

On the machine you want to access remotely:

```bash
./remotyy host --signal ws://your-server:9000 --name "my-machine"
```

With a master password (recommended):

```bash
./remotyy host --signal ws://your-server:9000 --name "my-machine" \
  --master-password "your-secret-password"
```

### 3. Connect

**Web client:**
```bash
cd web && npm install && npm run dev
# → http://localhost:3000
```

**CLI client:**
```bash
# List available hosts
./remotyy connect --signal ws://your-server:9000

# Connect to a host
./remotyy connect host-id --signal ws://your-server:9000
```

## Architecture

```
remotyy/
├── cmd/remotyy/              # Main CLI (signal | host | connect)
│   └── cmd/                  # Cobra subcommands
├── internal/
│   ├── auth/                 # bcrypt/argon2 password hashing
│   ├── config/               # Viper config (YAML + env + flags)
│   ├── host/                 # Host daemon, session management
│   ├── client/               # Client library
│   ├── signal/               # WebSocket signaling server
│   ├── webrtc/               # pion/webrtc engine wrapper
│   ├── pty/                  # PTY session manager
│   ├── screen/               # Screen capture framework
│   ├── transfer/             # File transfer protocol
│   ├── mux/                  # Connection multiplexer
│   ├── protocol/             # Wire protocol definitions
│   └── logging/              # Structured logging + audit
├── web/                      # React + TypeScript web client
│   └── src/
│       ├── components/       # Terminal, Screen, FileTransfer UI
│       ├── hooks/            # useSignaling, useWebRTC
│       └── lib/              # Protocol, WebRTC, Signaling clients
├── ios/remotyy/              # Native iOS app (SwiftUI)
├── remotyy-macOS/            # Native macOS menu bar app (SwiftUI)
├── src-tauri/                # Tauri desktop wrapper (Rust)
├── tui/                      # Bubble Tea TUI client (Go)
├── deploy/                   # Docker, systemd, launchd configs
├── docs/                     # Documentation
├── .github/workflows/        # CI/CD
├── Makefile
└── remotyy.example.yaml
```

## Build

```bash
# Go binaries (cross-platform)
make build-all                                    # Current platform
make build-linux-arm64                            # ARM64 Linux
make build-linux-amd64                            # AMD64 Linux
make build-darwin-arm64                           # Apple Silicon

# Web client
cd web && npm install && npm run build

# Tauri desktop app
make build-tauri                                  # Requires Rust

# macOS menu bar app
make build-macos-app                              # Requires Xcode

# iOS app (open in Xcode)
open ios/remotyy/
```

## Deployment Options

- **Single machine:** Run signaling + host + web all on one machine
- **VPS/Cloud:** Signaling on a public server, hosts connect from anywhere
- **Local network:** No signaling server needed with Bonjour discovery
- **Docker:** `docker compose up` for signaling + web
- **systemd:** Production service files for Linux servers

## Security

| Layer | Mechanism |
|-------|-----------|
| Transport | WebRTC DTLS-SRTP (E2E encrypted) |
| Signaling | Optional bearer token authentication |
| Device auth | Host must explicitly approve each device |
| Terminal auth | Master Password (bcrypt, never leaves host) |
| Data path | Blind signaling — server only coordinates handshake |
| NAT traversal | STUN/ICE — no open ports required |

## Comparison

| Feature | Macky ($29) | remotyy (free) |
|---------|-------------|----------------|
| Host platform | macOS only | macOS, Linux, Windows |
| Client platform | iOS only | Web, CLI, iOS, macOS, TUI |
| Signaling | Proprietary cloud | Self-hosted or cloud |
| File transfer | ❌ | ✅ (in progress) |
| Port forwarding | ❌ | ✅ (planned) |
| Clipboard sync | ❌ | ✅ (planned) |
| Session recording | ❌ | ✅ (in progress) |
| Open source | ❌ | ✅ MIT |
| Price | $29 lifetime | Free |

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a pull request

## License

MIT — see [LICENSE](LICENSE)

---

Built with [pion/webrtc](https://github.com/pion/webrtc) (Go) + [xterm.js](https://xtermjs.org/) + [Tauri](https://tauri.app/)
