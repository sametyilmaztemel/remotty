# remotty: Görev Dağılımı

> Oluşturulma: 2026-06-05
> Hedef: Phase 0 "Production Polish" tamamlanana kadar

## Mimari

```
Mac (Hermes Desktop) ──── ARM (Oracle 24/7)
  ├── iOS App (SwiftUI)       ├── Go Backend (signaling, host daemon)
  ├── macOS App (Swift)       ├── Web Client (xterm.js, Vite)
  ├── Go signaling server     ├── WebRTC test/CI
  ├── Swift toolchain         ├── Docker builds
  └── Xcode build             └── docs, release
```

## Mac Görevleri

| # | Görev | Öncelik | Detay |
|---|-------|---------|-------|
| M1 | iOS App: 4 bağlantı bug'ını düzelt | P0 | connect never sent, data channels not created, mock data, channelId |
| M2 | iOS App: WebRTC connection flow | P0 | signaling → ICE → data channel |
| M3 | iOS App: Terminal view + keyboard | P0 | xterm.js benzeri, WebRTC data channel üzerinden |
| M4 | macOS App: Session list polish | P1 | NSStatusItem menüsünde bağlı cihazlar, durum |
| M5 | iOS Screen sharing view | P1 | JPEG frame display, pinch-to-zoom |
| M6 | iOS Touch injection | P1 | Tap→click, drag→move |
| M7 | macOS: Launch at login | P1 | launchd plist + auto-start host |
| M8 | macOS: Lid-closed mode | P1 | caffeinate + power detection |

## ARM Görevleri

| # | Görev | Öncelik | Detay |
|---|-------|---------|-------|
| A1 | Terminal stability: reconnect/resize | P0 | exponential backoff, resize events |
| A2 | Screen sharing E2E: JPEG frame pipeline | P0 | data channel → web/CLI viewer |
| A3 | Web client: Screen viewer | P1 | Canvas-based JPEG frame display |
| A4 | Web client: Connection status UI | P1 | reconnect button, session info |
| A5 | CI: iOS test build pipeline | P1 | GitHub Actions + xcodebuild |
| A6 | File transfer: Wire up over WebRTC | P2 | internal/transfer → data channel |
| A7 | Clipboard sync: Wire up | P2 | bidirectional pasteboard sync |
| A8 | Release: v0.8.0 DMG + Docker | P1 | cross-platform release pipeline |

## İletişim

- Ortak memory: Honcho (`hermes-arm` workspace, `samet` peer)
- Görev tamamlanınca: `honcho_conclude` ile kaydet
- Blocker'da: diğer agent'a not bırak
- Repo: `sametyilmaztemel/remotty` (MIT)
- Kod EN, açıklama TR
