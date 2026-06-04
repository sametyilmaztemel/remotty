# Build

Creating a single Go binary from scratch.

```
go build -o remotyy-host ./cmd/remotyy-host
go build -o remotyy-signal ./cmd/remotyy-signal
go build -o remotyy ./cmd/remotyy
```

Cross-compile for ARM:

```
GOOS=linux GOARCH=arm64 go build -o remotyy-host-linux-arm64 ./cmd/remotyy-host
GOOS=linux GOARCH=arm64 go build -o remotyy-signal-linux-arm64 ./cmd/remotyy-signal
```

## Dependencies

- Go 1.22+
- Node.js 18+ (for web client)
- libvips (optional, for image processing)

## Web Client

```bash
cd web
npm install
npm run build    # production build
npm run dev      # dev server with HMR
```

## Testing

```bash
make test         # all tests
make test-short   # quick tests only
make lint         # golangci-lint
```
