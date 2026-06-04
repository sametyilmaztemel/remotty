package host

import (
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"sync"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
	pionw "github.com/pion/webrtc/v4"
	"github.com/rs/zerolog/log"
	"github.com/sametyilmaztemel/remotyy/internal/protocol"
	"github.com/sametyilmaztemel/remotyy/internal/pty"
	"github.com/sametyilmaztemel/remotyy/internal/webrtc"
)

// Daemon represents the remotyy host daemon.
type Daemon struct {
	config     Config
	signalConn *websocket.Conn
	peerID     string
	webrtc     *webrtc.Engine
	ptyMgr     *pty.Manager
	mu         sync.Mutex
	done       chan struct{}
}

// Config for the host daemon.
type Config struct {
	SignalURL     string
	Hostname      string
	MasterHash    string // bcrypt hash of master password
	Features      []string
	DeviceName    string
	AllowList     []string // allowed device IDs
	ReconnectWait time.Duration
}

// NewDaemon creates a new host daemon.
func NewDaemon(cfg Config) *Daemon {
	if cfg.ReconnectWait == 0 {
		cfg.ReconnectWait = 5 * time.Second
	}
	if len(cfg.Features) == 0 {
		cfg.Features = []string{"terminal"}
	}
	hostname := cfg.Hostname
	if hostname == "" {
		hostname, _ = os.Hostname()
	}

	return &Daemon{
		config: Config{
			SignalURL:     cfg.SignalURL,
			Hostname:      hostname,
			MasterHash:    cfg.MasterHash,
			Features:      cfg.Features,
			DeviceName:    cfg.DeviceName,
			AllowList:     cfg.AllowList,
			ReconnectWait: cfg.ReconnectWait,
		},
		done:  make(chan struct{}),
		ptyMgr: pty.NewManager(),
	}
}

// Hostname returns the configured hostname.
func (d *Daemon) Hostname() string {
	return d.config.Hostname
}

// Run starts the host daemon and blocks until signal.
func (d *Daemon) Run() error {
	log.Info().
		Str("signal_url", d.config.SignalURL).
		Str("hostname", d.config.Hostname).
		Strs("features", d.config.Features).
		Msg("remotyy host starting")

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	// Connect to signaling server with auto-reconnect
	go d.connectLoop()

	<-sigCh
	log.Info().Msg("Shutting down...")
	close(d.done)
	if d.signalConn != nil {
		d.signalConn.Close()
	}
	return nil
}

func (d *Daemon) connectLoop() {
	for {
		select {
		case <-d.done:
			return
		default:
			if err := d.connect(); err != nil {
				log.Error().Err(err).Msg("Connection failed, retrying...")
				time.Sleep(d.config.ReconnectWait)
			}
		}
	}
}

func (d *Daemon) connect() error {
	conn, _, err := websocket.DefaultDialer.Dial(d.config.SignalURL+"/ws", nil)
	if err != nil {
		return fmt.Errorf("dial signal server: %w", err)
	}
	d.mu.Lock()
	d.signalConn = conn
	d.mu.Unlock()

	log.Info().Msg("Connected to signaling server")

	// Register as host
	needsMaster := d.config.MasterHash != ""
	reg := protocol.SignalMessage{
		Type: protocol.MsgRegister,
		Payload: protocol.RegisterPayload{
			Hostname:    d.config.Hostname,
			Platform:    runtime.GOOS,
			Arch:        runtime.GOARCH,
			Version:     "0.1.0",
			NeedsMaster: needsMaster,
			Features:    d.config.Features,
		},
	}
	if err := conn.WriteJSON(reg); err != nil {
		return fmt.Errorf("register: %w", err)
	}

	// Read registration response
	var resp protocol.SignalMessage
	if err := conn.ReadJSON(&resp); err != nil {
		return fmt.Errorf("read register response: %w", err)
	}
	if resp.Type == protocol.MsgRegister {
		if p, ok := resp.Payload.(map[string]interface{}); ok {
			d.peerID, _ = p["id"].(string)
			log.Info().Str("peer_id", d.peerID).Msg("Registered with signal server")
		}
	}

	// Start heartbeat
	go d.heartbeatLoop(conn)

	// Read loop
	d.readLoop(conn)
	return nil
}

func (d *Daemon) heartbeatLoop(conn *websocket.Conn) {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-d.done:
			return
		case <-ticker.C:
			msg := protocol.SignalMessage{Type: protocol.MsgHeartbeat}
			if err := conn.WriteJSON(msg); err != nil {
				log.Error().Err(err).Msg("Heartbeat failed")
				return
			}
		}
	}
}

func (d *Daemon) readLoop(conn *websocket.Conn) {
	defer func() {
		log.Warn().Msg("Signal connection lost")
		d.mu.Lock()
		d.signalConn = nil
		if d.webrtc != nil {
			d.webrtc.Close()
			d.webrtc = nil
		}
		d.mu.Unlock()
	}()

	for {
		_, data, err := conn.ReadMessage()
		if err != nil {
			log.Error().Err(err).Msg("Read error")
			return
		}

		var msg protocol.SignalMessage
		if err := json.Unmarshal(data, &msg); err != nil {
			continue
		}

		switch msg.Type {
		case protocol.MsgRequestHost:
			// Client wants to connect — set up WebRTC
			go d.handleIncomingClient(conn, msg)

		case protocol.MsgOffer:
			if d.webrtc != nil {
				d.webrtc.HandleOffer(msg)
			}

		case protocol.MsgAnswer:
			if d.webrtc != nil {
				d.webrtc.HandleAnswer(msg)
			}

		case protocol.MsgICE:
			if d.webrtc != nil {
				d.webrtc.HandleICE(msg)
			}

		case protocol.MsgError:
			log.Warn().Interface("payload", msg.Payload).Msg("Signal error")
		}
	}
}

func (d *Daemon) handleIncomingClient(conn *websocket.Conn, msg protocol.SignalMessage) {
	log.Info().Interface("payload", msg.Payload).Msg("Incoming client connection request")

	// Get client ID from message
	clientID := ""
	if m, ok := msg.Payload.(map[string]interface{}); ok {
		clientID, _ = m["client_id"].(string)
	}

	// Check allow list if configured
	if len(d.config.AllowList) > 0 {
		allowed := false
		for _, id := range d.config.AllowList {
			if id == clientID || id == "*" {
				allowed = true
				break
			}
		}
		if !allowed {
			log.Warn().Str("client", clientID).Msg("Client not in allow list")
			return
		}
	}

	// Initialize WebRTC engine
	engine, err := webrtc.NewEngine(func(cfg *webrtc.EngineConfig) {
		cfg.SignalConn = conn
		cfg.RoomID = msg.Room
		cfg.OnDataChannel = d.onDataChannel
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create WebRTC engine")
		return
	}

	d.mu.Lock()
	d.webrtc = engine
	d.mu.Unlock()

	// Create and send offer
	offer, err := engine.CreateOffer()
	if err != nil {
		log.Error().Err(err).Msg("Failed to create offer")
		return
	}

	conn.WriteJSON(protocol.SignalMessage{
		Type:    protocol.MsgOffer,
		Payload: offer,
		Room:    msg.Room,
	})
}

func (d *Daemon) onDataChannel(dc *pionw.DataChannel, label string) {
	log.Info().Str("label", label).Msg("Data channel opened")

	switch label {
	case "auth":
		d.handleAuthChannel(dc)
	case "terminal":
		d.handleTerminalChannel(dc)
	}
}

func (d *Daemon) handleAuthChannel(dc *pionw.DataChannel) {
	dc.OnMessage(func(msg pionw.DataChannelMessage) {
		var auth protocol.SignalMessage
		if err := json.Unmarshal(msg.Data, &auth); err != nil {
			return
		}

		if auth.Type == protocol.MsgAuth {
			var payload protocol.AuthPayload
			data, _ := json.Marshal(auth.Payload)
			json.Unmarshal(data, &payload)

			// Verify master password
			// (bcrypt check happens here)
			valid := d.config.MasterHash == "" || verifyPassword(payload.Password, d.config.MasterHash)

			resp := protocol.SignalMessage{
				Type: protocol.MsgAuthOK,
			}
			if !valid {
				resp.Type = protocol.MsgAuthFail
			}
			data, _ = json.Marshal(resp)
			dc.Send(data)
		}
	})
}

func (d *Daemon) handleTerminalChannel(dc *pionw.DataChannel) {
	// Spawn shell via PTY
	shell := d.ptyMgr.Spawn()

	dc.OnMessage(func(msg pionw.DataChannelMessage) {
		var sigMsg protocol.SignalMessage
		if err := json.Unmarshal(msg.Data, &sigMsg); err != nil {
			// Raw input
			shell.Write(msg.Data)
			return
		}

		switch sigMsg.Type {
		case protocol.MsgInput:
			data, _ := json.Marshal(sigMsg.Payload)
			shell.Write(data)
		case protocol.MsgResize:
			var resize protocol.ResizePayload
			data, _ := json.Marshal(sigMsg.Payload)
			json.Unmarshal(data, &resize)
			shell.Resize(resize.Rows, resize.Cols)
		}
	})

	// Pipe PTY output back to data channel
	go func() {
		buf := make([]byte, 4096)
		for {
			n, err := shell.Read(buf)
			if err != nil {
				return
			}
			dc.Send(buf[:n])
		}
	}()
}

func verifyPassword(password, hash string) bool {
	// bcrypt.CompareHashAndPassword
	return true // placeholder — implement with golang.org/x/crypto
}
