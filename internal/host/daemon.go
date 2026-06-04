// Package host implements the remotyy host daemon that runs on machines
// to be accessed remotely. It connects to the signaling server and
// manages incoming WebRTC sessions.
package host

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"runtime"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/rs/zerolog"
	"github.com/sametyilmaztemel/remotyy/internal/auth"
	"github.com/sametyilmaztemel/remotyy/internal/config"
	"github.com/sametyilmaztemel/remotyy/internal/protocol"
	"github.com/sametyilmaztemel/remotyy/internal/pty"
	"github.com/sametyilmaztemel/remotyy/internal/webrtc"
)

// Daemon runs on the host machine and manages remote access sessions.
type Daemon struct {
	cfg        config.HostConfig
	signalConn *websocket.Conn
	peerID     string
	webrtcEng  *webrtc.Engine
	ptyMgr     *pty.Manager
	sessions   map[string]*Session
	mu         sync.RWMutex
	done       chan struct{}
	log        zerolog.Logger
}

// Session tracks an active client connection.
type Session struct {
	ID        string
	ClientID  string
	RoomID    string
	WebRTC    *webrtc.Engine
	PTYSess   *pty.Session
	CreatedAt time.Time
	Authed    bool
}

// NewDaemon creates a new host daemon.
func NewDaemon(cfg config.HostConfig, log zerolog.Logger) (*Daemon, error) {
	// Hash master password if provided in plaintext
	if cfg.MasterPassword != "" && cfg.MasterHash == "" {
		hash, err := auth.HashPassword(cfg.MasterPassword)
		if err != nil {
			return nil, fmt.Errorf("hash master password: %w", err)
		}
		cfg.MasterHash = hash
	}

	if cfg.Name == "" {
		cfg.Name, _ = os.Hostname()
	}
	if cfg.Features == nil {
		cfg.Features = []string{"terminal"}
	}
	if cfg.ReconnectWait == 0 {
		cfg.ReconnectWait = 5 * time.Second
	}
	if cfg.HeartbeatInt == 0 {
		cfg.HeartbeatInt = 15 * time.Second
	}
	if cfg.MaxSessions == 0 {
		cfg.MaxSessions = 10
	}

	return &Daemon{
		cfg:      cfg,
		ptyMgr:   pty.NewManager(),
		sessions: make(map[string]*Session),
		done:     make(chan struct{}),
		log:      log.With().Str("component", "host").Logger(),
	}, nil
}

// Run starts the host daemon and blocks until context cancellation.
func (d *Daemon) Run(ctx context.Context) error {
	defer d.cleanup()

	for {
		select {
		case <-ctx.Done():
			return nil
		default:
			if err := d.connect(ctx); err != nil {
				d.log.Error().Err(err).Msg("Connection failed, reconnecting...")
				select {
				case <-ctx.Done():
					return nil
				case <-time.After(d.cfg.ReconnectWait):
				}
			}
		}
	}
}

func (d *Daemon) connect(ctx context.Context) error {
	d.log.Info().Str("url", d.cfg.SignalURL+"/ws").Msg("Connecting to signaling server")

	conn, _, err := websocket.DefaultDialer.DialContext(ctx, d.cfg.SignalURL+"/ws", nil)
	if err != nil {
		return fmt.Errorf("dial: %w", err)
	}

	d.mu.Lock()
	d.signalConn = conn
	d.mu.Unlock()

	defer conn.Close()

	// Register as host
	regMsg := protocol.NewMessage(protocol.MsgRegister, protocol.RegisterPayload{
		Name:     d.cfg.Name,
		Platform: runtime.GOOS,
		Arch:     runtime.GOARCH,
		Version:  config.Version,
		Features: d.cfg.Features,
		DeviceID: d.cfg.DeviceID,
	})

	if err := conn.WriteJSON(regMsg); err != nil {
		return fmt.Errorf("register: %w", err)
	}

	// Read registration response
	_, data, err := conn.ReadMessage()
	if err != nil {
		return fmt.Errorf("read register response: %w", err)
	}

	var resp protocol.Message
	json.Unmarshal(data, &resp)
	if resp.Type == protocol.MsgRegister {
		var payload map[string]interface{}
		json.Unmarshal(resp.Payload, &payload)
		d.peerID, _ = payload["id"].(string)
		d.log.Info().Str("peer_id", d.peerID).Msg("Registered with signaling server")

		// Call OnRegistered callback if set
		if d.cfg.OnRegistered != nil {
			d.cfg.OnRegistered(d.peerID)
		}
	}

	// Start heartbeat
	hbCtx, hbCancel := context.WithCancel(ctx)
	defer hbCancel()
	go d.heartbeatLoop(hbCtx, conn)

	// Read loop
	return d.readLoop(ctx, conn)
}

func (d *Daemon) heartbeatLoop(ctx context.Context, conn *websocket.Conn) {
	ticker := time.NewTicker(d.cfg.HeartbeatInt)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := conn.WriteJSON(protocol.NewMessage(protocol.MsgHeartbeat, nil)); err != nil {
				d.log.Warn().Err(err).Msg("Heartbeat failed")
				return
			}
		}
	}
}

func (d *Daemon) readLoop(ctx context.Context, conn *websocket.Conn) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		default:
			_, data, err := conn.ReadMessage()
			if err != nil {
				return fmt.Errorf("read: %w", err)
			}

			var msg protocol.Message
			if err := json.Unmarshal(data, &msg); err != nil {
				d.log.Warn().Err(err).Msg("Invalid message")
				continue
			}

			d.handleMessage(msg)
		}
	}
}

func (d *Daemon) handleMessage(msg protocol.Message) {
	switch msg.Type {
	case protocol.MsgConnect:
		d.handleConnectRequest(msg)
	case protocol.MsgPeerLeft:
		d.handlePeerDisconnect(msg)
	case protocol.MsgError:
		d.handleError(msg)
	}
}

func (d *Daemon) handleConnectRequest(msg protocol.Message) {
	var payload struct {
		Room     string `json:"room"`
		ClientID string `json:"client_id"`
	}
	json.Unmarshal(msg.Payload, &payload)

	d.log.Info().Str("client", payload.ClientID).Str("room", payload.Room).
		Msg("Incoming client connection")

	// Check allow list
	if len(d.cfg.AllowList) > 0 {
		allowed := false
		for _, id := range d.cfg.AllowList {
			if id == payload.ClientID || id == "*" {
				allowed = true
				break
			}
		}
		if !allowed {
			d.log.Warn().Str("client", payload.ClientID).Msg("Client not in allow list")
			return
		}
	}

	// Create WebRTC engine for this session
	engine, err := webrtc.NewEngine(func(cfg *webrtc.EngineConfig) {
		cfg.SignalConn = d.signalConn
		cfg.RoomID = payload.Room
		cfg.OnDataChannel = d.onDataChannel(payload.Room)
		cfg.ICEServers = []string{"stun:stun.l.google.com:19302"}
	})
	if err != nil {
		d.log.Error().Err(err).Msg("Failed to create WebRTC engine")
		return
	}

	session := &Session{
		ID:        payload.Room,
		ClientID:  payload.ClientID,
		RoomID:    payload.Room,
		WebRTC:    engine,
		CreatedAt: time.Now(),
	}

	d.mu.Lock()
	d.sessions[payload.Room] = session
	d.mu.Unlock()

	// Create and send WebRTC offer
	offer, err := engine.CreateOffer()
	if err != nil {
		d.log.Error().Err(err).Msg("Failed to create WebRTC offer")
		return
	}

	offerMsg := protocol.NewMessage(protocol.MsgOffer, offer)
	offerMsg.Room = payload.Room
	d.signalConn.WriteJSON(offerMsg)
}

func (d *Daemon) onDataChannel(roomID string) func(*webrtc.DataChannel, string) {
	return func(dc *webrtc.DataChannel, label string) {
		d.log.Info().Str("label", label).Str("room", roomID).
			Msg("Data channel opened")

		session := d.getSession(roomID)
		if session == nil {
			return
		}

		switch label {
		case "auth":
			d.handleAuthChannel(session, dc)
		case "terminal":
			d.handleTerminalChannel(session, dc)
		case "screen":
			d.handleScreenChannel(session, dc)
		case "file":
			d.handleFileChannel(session, dc)
		case "clipboard":
			d.handleClipboardChannel(dc)
		}
	}
}

func (d *Daemon) handleAuthChannel(session *Session, dc *webrtc.DataChannel) {
	dc.OnMessage(func(data []byte) {
		var msg protocol.Message
		if err := json.Unmarshal(data, &msg); err != nil {
			return
		}

		if msg.Type == protocol.MsgAuth {
			var authPayload protocol.AuthPayload
			json.Unmarshal(msg.Payload, &authPayload)

			valid := d.cfg.MasterHash == "" ||
				auth.CheckPassword(authPayload.Password, d.cfg.MasterHash)

			if valid {
				session.Authed = true
				dc.SendJSON(protocol.NewMessage(protocol.MsgAuthOK, nil))
				d.log.Info().Str("client", session.ClientID).Msg("Client authenticated")
			} else {
				dc.SendJSON(protocol.NewMessage(protocol.MsgAuthFail, nil))
				d.log.Warn().Str("client", session.ClientID).Msg("Authentication failed")
			}
		}
	})
}

func (d *Daemon) handleTerminalChannel(session *Session, dc *webrtc.DataChannel) {
	if !session.Authed {
		dc.SendJSON(protocol.NewMessage(protocol.MsgError, "Not authenticated"))
		return
	}

	// Spawn PTY
	shell, err := d.ptyMgr.Spawn(24, 80)
	if err != nil {
		d.log.Error().Err(err).Msg("Failed to spawn PTY")
		dc.SendJSON(protocol.NewMessage(protocol.MsgError, "Failed to start shell"))
		return
	}
	session.PTYSess = shell

	// Pipe PTY output → DataChannel
	go func() {
		buf := make([]byte, 32768)
		for {
			n, err := shell.Read(buf)
			if err != nil {
				break
			}
			if n > 0 {
				dc.Send(buf[:n])
			}
		}
	}()

	// Pipe DataChannel input → PTY
	dc.OnMessage(func(data []byte) {
		if !session.Authed {
			return
		}

		var msg protocol.Message
		if err := json.Unmarshal(data, &msg); err != nil {
			// Raw input (fast path)
			shell.Write(data)
			return
		}

		switch msg.Type {
		case protocol.MsgInput:
			var input string
			json.Unmarshal(msg.Payload, &input)
			shell.Write([]byte(input))
		case protocol.MsgResize:
			var resize protocol.ResizePayload
			json.Unmarshal(msg.Payload, &resize)
			shell.Resize(resize.Rows, resize.Cols)
		}
	})
}

func (d *Daemon) handleScreenChannel(session *Session, dc *webrtc.DataChannel) {
	// Screen sharing — handled via WebRTC video track
	// Control messages via data channel
}

func (d *Daemon) handleFileChannel(session *Session, dc *webrtc.DataChannel) {
	// File transfer — handled via data channel
}

func (d *Daemon) handleClipboardChannel(dc *webrtc.DataChannel) {
	dc.OnMessage(func(data []byte) {
		var msg protocol.Message
		json.Unmarshal(data, &msg)
		if msg.Type == protocol.MsgClipboard {
			var clip protocol.ClipboardPayload
			json.Unmarshal(msg.Payload, &clip)
			// Sync clipboard
		}
	})
}

func (d *Daemon) handlePeerDisconnect(msg protocol.Message) {
	var payload struct {
		PeerID string `json:"peer_id"`
	}
	json.Unmarshal(msg.Payload, &payload)

	d.mu.Lock()
	for id, sess := range d.sessions {
		if sess.ClientID == payload.PeerID {
			if sess.PTYSess != nil {
				sess.PTYSess.Close()
			}
			if sess.WebRTC != nil {
				sess.WebRTC.Close()
			}
			delete(d.sessions, id)
		}
	}
	d.mu.Unlock()

	d.log.Info().Str("peer", payload.PeerID).Msg("Client disconnected")
}

func (d *Daemon) handleError(msg protocol.Message) {
	var err protocol.ErrorPayload
	json.Unmarshal(msg.Payload, &err)
	d.log.Warn().Str("error", err.Message).Msg("Received error from signal server")
}

func (d *Daemon) getSession(roomID string) *Session {
	d.mu.RLock()
	defer d.mu.RUnlock()
	return d.sessions[roomID]
}

func (d *Daemon) cleanup() {
	d.log.Info().Msg("Cleaning up host daemon")

	d.mu.Lock()
	defer d.mu.Unlock()

	for id, sess := range d.sessions {
		if sess.PTYSess != nil {
			sess.PTYSess.Close()
		}
		if sess.WebRTC != nil {
			sess.WebRTC.Close()
		}
		delete(d.sessions, id)
	}

	if d.signalConn != nil {
		d.signalConn.Close()
	}
}
