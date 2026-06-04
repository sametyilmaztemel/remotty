package signal

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/rs/zerolog/log"
	"github.com/sametyilmaztemel/remotyy/internal/protocol"
)

var upgrader = websocket.Upgrader{
	CheckOrigin:     func(r *http.Request) bool { return true },
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

// Peer represents a connected WebSocket peer.
type Peer struct {
	ID         string
	Role       string // "host" or "client"
	Conn       *websocket.Conn
	Hostname   string
	Platform   string
	Arch       string
	NeedsMaster bool
	Features   []string
	Room       string
	Mu         sync.Mutex
}

// Room connects a host and client for signaling.
type Room struct {
	ID      string
	Host    *Peer
	Client  *Peer
	Created time.Time
}

// Server is the signaling server.
type Server struct {
	mu          sync.RWMutex
	hosts       map[string]*Peer // hostID → Peer
	rooms       map[string]*Room // roomID → Room
	devMode     bool
	authToken   string
	peerTimeout time.Duration
}

// NewServer creates a new signaling server.
func NewServer(authToken string, devMode bool) *Server {
	return &Server{
		hosts:       make(map[string]*Peer),
		rooms:       make(map[string]*Room),
		devMode:     devMode,
		authToken:   authToken,
		peerTimeout: 30 * time.Second,
	}
}

// HandleWebSocket handles incoming WebSocket connections.
func (s *Server) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Error().Err(err).Msg("WebSocket upgrade failed")
		return
	}

	peer := &Peer{
		ID:   fmt.Sprintf("peer-%d", time.Now().UnixNano()),
		Conn: conn,
	}

	defer s.disconnect(peer)
	defer conn.Close()

	// Read first message to determine role
	var msg protocol.SignalMessage
	if err := conn.ReadJSON(&msg); err != nil {
		log.Error().Err(err).Msg("Failed to read initial message")
		return
	}

	switch msg.Type {
	case protocol.MsgRegister:
		s.handleRegister(peer, msg)
	case protocol.MsgRequestHost:
		s.handleRequestHost(peer, msg)
	default:
		s.sendError(peer, "First message must be register or request_host")
		return
	}

	// Main message loop
	s.readLoop(peer)
}

func (s *Server) readLoop(peer *Peer) {
	for {
		_, data, err := peer.Conn.ReadMessage()
		if err != nil {
			log.Debug().Str("peer", peer.ID).Err(err).Msg("Read error")
			return
		}

		var msg protocol.SignalMessage
		if err := json.Unmarshal(data, &msg); err != nil {
			log.Error().Err(err).Msg("Failed to unmarshal message")
			continue
		}

		s.routeMessage(peer, msg)
	}
}

func (s *Server) routeMessage(sender *Peer, msg protocol.SignalMessage) {
	switch msg.Type {
	case protocol.MsgOffer, protocol.MsgAnswer, protocol.MsgICE:
		s.forwardToRoom(sender, msg)
	case protocol.MsgHeartbeat:
		// Hosts send heartbeats — silently acknowledge
	default:
		log.Warn().Str("type", string(msg.Type)).Str("from", sender.ID).
			Msg("Unknown message type")
	}
}

func (s *Server) handleRegister(peer *Peer, msg protocol.SignalMessage) {
	data, _ := json.Marshal(msg.Payload)
	var reg protocol.RegisterPayload
	json.Unmarshal(data, &reg)

	peer.Role = "host"
	peer.Hostname = reg.Hostname
	peer.Platform = reg.Platform
	peer.Arch = reg.Arch
	peer.NeedsMaster = reg.NeedsMaster
	peer.Features = reg.Features

	s.mu.Lock()
	s.hosts[peer.ID] = peer
	s.mu.Unlock()

	log.Info().
		Str("host", peer.Hostname).
		Str("platform", peer.Platform).
		Str("arch", peer.Arch).
		Str("id", peer.ID).
		Msg("Host registered")

	s.send(peer, protocol.SignalMessage{
		Type:    protocol.MsgRegister,
		Payload: map[string]string{"id": peer.ID, "status": "ok"},
	})
}

func (s *Server) handleRequestHost(peer *Peer, msg protocol.SignalMessage) {
	peer.Role = "client"
	hostID := ""
	if m, ok := msg.Payload.(map[string]interface{}); ok {
		hostID, _ = m["host_id"].(string)
	}

	log.Info().Str("client", peer.ID).Str("requested_host", hostID).
		Msg("Client requesting host")

	s.mu.RLock()
	// If specific host requested, find it; otherwise return first available
	var target *Peer
	if hostID != "" {
		if h, ok := s.hosts[hostID]; ok {
			target = h
		}
	} else {
		for _, h := range s.hosts {
			if h.Room == "" { // host not already in a room
				target = h
				break
			}
		}
	}
	hosts := make([]protocol.HostInfo, 0, len(s.hosts))
	for id, h := range s.hosts {
		if h.Room == "" {
			hosts = append(hosts, protocol.HostInfo{
				ID:          id,
				Name:        h.Hostname,
				Platform:    h.Platform,
				Arch:        h.Arch,
				Online:      true,
				NeedsMaster: h.NeedsMaster,
				Features:    h.Features,
			})
		}
	}
	s.mu.RUnlock()

	if target == nil {
		// Send available hosts list
		s.send(peer, protocol.SignalMessage{
			Type:    protocol.MsgRequestHost,
			Payload: map[string]interface{}{"hosts": hosts},
		})
		return
	}

	// Create room
	roomID := fmt.Sprintf("room-%s-%s", target.ID, peer.ID)
	room := &Room{
		ID:      roomID,
		Host:    target,
		Client:  peer,
		Created: time.Now(),
	}

	s.mu.Lock()
	target.Room = roomID
	peer.Room = roomID
	s.rooms[roomID] = room
	s.mu.Unlock()

	log.Info().Str("room", roomID).Msg("Room created — client connected to host")

	// Notify host about incoming client
	s.send(target, protocol.SignalMessage{
		Type:    protocol.MsgRequestHost,
		Payload: map[string]string{"client_id": peer.ID},
		Room:    roomID,
	})

	// Notify client about approved connection
	s.send(peer, protocol.SignalMessage{
		Type:    protocol.MsgApproved,
		Payload: map[string]string{"room": roomID, "host_id": target.ID},
	})
}

func (s *Server) forwardToRoom(sender *Peer, msg protocol.SignalMessage) {
	s.mu.RLock()
	room, ok := s.rooms[sender.Room]
	s.mu.RUnlock()
	if !ok || room == nil {
		log.Warn().Str("peer", sender.ID).Msg("Sender not in a room")
		return
	}

	// Forward to the other peer in the room
	var target *Peer
	if sender.ID == room.Host.ID {
		target = room.Client
	} else {
		target = room.Host
	}

	if target == nil {
		return
	}

	s.send(target, msg)
}

func (s *Server) disconnect(peer *Peer) {
	s.mu.Lock()
	delete(s.hosts, peer.ID)

	// Clean up room if any
	if room, ok := s.rooms[peer.Room]; ok {
		delete(s.rooms, peer.Room)
		// Notify other peer
		var other *Peer
		if peer.ID == room.Host.ID {
			other = room.Client
		} else {
			other = room.Host
		}
		if other != nil {
			other.Room = ""
			s.send(other, protocol.SignalMessage{
				Type:    protocol.MsgError,
				Payload: map[string]string{"message": "peer_disconnected"},
			})
		}
	}
	s.mu.Unlock()

	log.Info().Str("peer", peer.ID).Str("role", peer.Role).Msg("Disconnected")
}

// ListHosts returns all currently registered hosts.
func (s *Server) ListHosts() []protocol.HostInfo {
	s.mu.RLock()
	defer s.mu.RUnlock()

	hosts := make([]protocol.HostInfo, 0, len(s.hosts))
	for id, h := range s.hosts {
		hosts = append(hosts, protocol.HostInfo{
			ID:          id,
			Name:        h.Hostname,
			Platform:    h.Platform,
			Arch:        h.Arch,
			Online:      h.Room == "",
			NeedsMaster: h.NeedsMaster,
			Features:    h.Features,
		})
	}
	return hosts
}

// HTTPHandler returns an HTTP handler for the REST API (optional).
func (s *Server) HTTPHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		s.mu.RLock()
		hostCount := len(s.hosts)
		roomCount := len(s.rooms)
		s.mu.RUnlock()
		w.Write([]byte(fmt.Sprintf(
			`{"status":"ok","hosts":%d,"rooms":%d}`+"\n", hostCount, roomCount)))
	})
	mux.HandleFunc("/hosts", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(s.ListHosts())
	})
	mux.HandleFunc("/ws", s.HandleWebSocket)
	return mux
}

func (s *Server) send(peer *Peer, msg protocol.SignalMessage) {
	peer.Mu.Lock()
	defer peer.Mu.Unlock()
	if err := peer.Conn.WriteJSON(msg); err != nil {
		log.Error().Err(err).Str("peer", peer.ID).Msg("Write failed")
	}
}

func (s *Server) sendError(peer *Peer, message string) {
	s.send(peer, protocol.SignalMessage{
		Type:    protocol.MsgError,
		Payload: map[string]string{"message": message},
	})
}
