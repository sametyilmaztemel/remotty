# remotyy macOS Menu Bar App — Architecture

## Overview

Native macOS menu bar application that runs the remotyy host daemon.
Provides one-click start/stop, status monitoring, and configuration.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  macOS Menu Bar App (SwiftUI)                     │
│                                                    │
│  ┌────────────────────────────────────────┐       │
│  │  MenuBarExtra (system tray icon)        │       │
│  │  ┌──────────────────────────────────┐  │       │
│  │  │ MenuBarView                       │  │       │
│  │  │ - Status indicator                │  │       │
│  │  │ - Host info display               │  │       │
│  │  │ - Start/Stop button               │  │       │
│  │  │ - Open Settings                   │  │       │
│  │  │ - Quit                            │  │       │
│  │  └──────────────────────────────────┘  │       │
│  └────────────────────────────────────────┘       │
│                                                    │
│  ┌────────────────────────────────────────┐       │
│  │  HostManager (ObservableObject)         │       │
│  │  - NSTask → remotyy host binary        │       │
│  │  - PID tracking                        │       │
│  │  - Auto-restart on crash               │       │
│  │  - Launch at login (SMAppService)      │       │
│  └────────────────────────────────────────┘       │
│                                                    │
│  ┌────────────────────────────────────────┐       │
│  │  SettingsView (TabView)                 │       │
│  │  - Signaling URL                        │       │
│  │  - Hostname                             │       │
│  │  - Master Password                      │       │
│  │  - Launch at login                      │       │
│  │  - About                                │       │
│  └────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

## Key Features

### Menu Bar App
- Uses SwiftUI `MenuBarExtra` for native macOS tray icon
- Dynamic icon: `terminal` (stopped) / `terminal.fill` (running)
- Color-coded: Gray (stopped), Green (running)

### Host Manager
- Spawns `remotyy host` as a subprocess
- Monitors process lifecycle
- Reports status changes
- Handles graceful shutdown

### Settings
- Full configuration via SwiftUI Form
- Secure master password storage (Keychain)
- Launch at login via `SMAppService`

## Setup

1. Build remotyy Go binary first: `make build`
2. Build the macOS app: `make build-macos-app`
3. Or open in Xcode: `open remotyy-macOS/Package.swift`

## Requirements

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+
- remotyy binary in PATH
