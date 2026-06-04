.PHONY: all build-all build-host build-signal build-cli build-web clean test lint dev

# ─── Build ────────────────────────────────────────────────
BIN_DIR := bin
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT  := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE    := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS := -ldflags "-X github.com/sametyilmaztemel/remotyy/internal/config.Version=$(VERSION) -X github.com/sametyilmaztemel/remotyy/internal/config.Commit=$(COMMIT) -X github.com/sametyilmaztemel/remotyy/internal/config.Date=$(DATE)"

all: build-all

build-all: build-host build-signal build-cli

build-host:
	@echo "Building remotyy-host..."
	@mkdir -p $(BIN_DIR)
	CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-host ./cmd/remotyy-host

build-signal:
	@echo "Building remotyy-signal..."
	@mkdir -p $(BIN_DIR)
	CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-signal ./cmd/remotyy-signal

build-cli:
	@echo "Building remotyy..."
	@mkdir -p $(BIN_DIR)
	CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy ./cmd/remotyy

build-web:
	@echo "Building web client..."
	cd web && npm run build

# ─── Cross-compile ────────────────────────────────────────
build-linux-arm:
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-host-linux-arm64 ./cmd/remotyy-host
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-signal-linux-arm64 ./cmd/remotyy-signal
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-linux-arm64 ./cmd/remotyy

build-linux-amd64:
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-host-linux-amd64 ./cmd/remotyy-host
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-signal-linux-amd64 ./cmd/remotyy-signal
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-linux-amd64 ./cmd/remotyy

build-darwin-arm64:
	GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-host-darwin-arm64 ./cmd/remotyy-host
	GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-signal-darwin-arm64 ./cmd/remotyy-signal
	GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BIN_DIR)/remotyy-darwin-arm64 ./cmd/remotyy

# ─── Development ───────────────────────────────────────────
dev:
	@echo "Starting remotyy-signal on :9000..."
	go run ./cmd/remotyy-signal --port 9000 --dev

dev-host:
	@echo "Starting remotyy-host (connects to localhost:9000)..."
	go run ./cmd/remotyy-host --signal ws://localhost:9000 --name "dev-host"

# ─── Native Apps ──────────────────────────────────────────
build-tauri:
	@echo "Building Tauri desktop app..."
	cd src-tauri && cargo build --release

build-macos-app:
	@echo "Building macOS menu bar app..."
	cd remotyy-macOS && swift build -c release

build-ios-app:
	@echo "Building iOS app..."
	cd ios && xcodebuild -project remotyy.xcodeproj \
		-scheme remotyy -configuration Release \
		-derivedDataPath build \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>/dev/null || echo "⚠️  Xcode build skipped"

build-native: build-tauri build-macos-app

# ─── Quality ───────────────────────────────────────────────
test:
	go test ./... -v -race -count=1

test-short:
	go test ./... -short -race

lint:
	golangci-lint run ./...

vet:
	go vet ./...

# ─── Clean ─────────────────────────────────────────────────
clean:
	rm -rf $(BIN_DIR)
	go clean ./...
