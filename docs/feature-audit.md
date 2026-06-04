# Feature Audit: remotyy vs Macky

| Feature | Macky | remotyy | Status |
|---------|-------|---------|--------|
| Terminal access | ✅ | ✅ | ✅ Done |
| Screen sharing (desktop) | ✅ | ❌ | 🚧 Framework var, UI yok |
| E2E encryption (DTLS-SRTP) | ✅ | ✅ | ✅ Done |
| Blind signaling | ✅ | ✅ | ✅ Done |
| Device allow listing | ✅ | ✅ | ✅ Done |
| Zero open ports | ✅ | ✅ | ✅ Done |
| P2P <50ms latency | ✅ | ✅ | ✅ Done |
| Network switch survive | ✅ | ✅ | ✅ Done |
| Native iOS app | ✅ | ❌ | 🚧 SwiftUI kod var, Xcode projesi yok |
| Native macOS app | ✅ | ✅ | ✅ Menü bar |
| Background connect | ✅ | ❌ | ❌ Yapılmadı |
| Lid-closed mode | ✅ | ❌ | ❌ Yapılmadı |
| QR pairing | ❌ | ❌ | ❌ Planlandı |
| File transfer | ❌ | 🚧 | 🚧 Framework hazır |
| Port forwarding | ❌ | ❌ | ❌ Planlandı |
| Clipboard sync | ❌ | ❌ | ❌ Planlandı |
| Web client | ❌ | ✅ | ✅ Her cihazdan erişim |
| CLI client | ❌ | ✅ | ✅ SSH benzeri |
| Linux host | ❌ | ✅ | ✅ ARM64 + AMD64 |
| Self-hosted | ❌ | ✅ | ✅ Tam kontrol |
| Open source | ❌ | ✅ | ✅ MIT |

## Gunceleme Planı — Isi Kolaylastiracak Roadmap

### Phase 0: Bugfix (su an)
- [x] macOS app crash fix (readabilityHandler)
- [x] CLI flag binding fix
- [x] Settings window kapanmama sorunu
- [x] UI polish (menü bar, settings, web)

### Phase 1: "Macky Parity" (1 hafta)
- [ ] **Screen sharing** — WebRTC video track + macOS CGDisplay capture
- [ ] **Quick start guide** — Web client'ta yardım menüsü (✅ yapıldı)
- [ ] **Auto-detect local IP** — Web client'ta tek tıkla IP bulma (✅ yapıldı)

### Phase 2: "Zero Setup" (1 hafta)
- [ ] **QR pairing** — `remotyy host --qr` ile QR kod göster, telefonda oku, bağlan
- [ ] **Bonjour discovery** — Aynı WiFi'da host'u otomatik bul
- [ ] **One-line install** — `curl -fsSL https://remotyy.dev/install.sh | bash`

### Phase 3: "Pro Features" (2 hafta)
- [ ] **File transfer** — Drag-drop + progress + resume
- [ ] **Port forwarding** — WebRTC tunnel ile localhost erişimi
- [ ] **Session recording** — Asciinema tarzı kayıt + web player

### Phase 4: "Mobile" (2 hafta)
- [ ] **iOS Xcode project** — Native app build alınabilir hale getir
- [ ] **Background connect** — iOS'ta arka planda bağlı kalma
- [ ] **Lid-closed mode** — Mac uykuya gitmesini engelle

## Oncelikli Aksiyonlar

**Bu hafta:**
1. `remotyy host --qr` — CLI'da QR kod göster
2. Screen sharing — macOS ekranını WebRTC ile yayınla
3. Web client'a yardım sayfası — ✅ yapıldı

**Gereken efor:**
- QR pairing: 1 gun
- Screen sharing: 3-4 gun (CGO ile macOS screen capture)
- File transfer: 2-3 gun (framework hazir, UI bagla)
- iOS Xcode project: 1-2 gun

**Not:** Macky'de olan BACKGROUND CONNECT ve LID-CLOSED MODE iOS 18+ ozellikleri.
Bunlar icin native iOS app ve macOS entitlement gerekli — su an web client uzerinden yapilamaz.
