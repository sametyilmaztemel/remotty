// Package webrtc provides a high-level WebRTC engine for remotyy.
package webrtc

import (
	"encoding/json"
	"fmt"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/pion/interceptor"
	pion "github.com/pion/webrtc/v4"
	"github.com/rs/zerolog/log"
	"github.com/sametyilmaztemel/remotyy/internal/protocol"
)

// Engine manages a WebRTC peer connection with data channels.
type Engine struct {
	pc           *pion.PeerConnection
	config       EngineConfig
	mu           sync.Mutex
	dataChannels map[string]*pion.DataChannel
	closed       bool
}

// EngineConfig for WebRTC setup.
type EngineConfig struct {
	SignalConn     *websocket.Conn
	RoomID         string
	ICEServers     []string
	OnDataChannel  func(dc *DataChannel, label string)
	OnICEState     func(state pion.ICEConnectionState)
}

// DataChannel wraps pion's DataChannel with convenience methods.
type DataChannel struct {
	*pion.DataChannel
	mu        sync.Mutex
	onMessage func([]byte)
}

// SendJSON sends a protocol.Message as JSON over the data channel.
func (dc *DataChannel) SendJSON(msg protocol.Message) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}
	return dc.Send(data)
}

// Send sends raw bytes.
func (dc *DataChannel) Send(data []byte) error {
	dc.mu.Lock()
	defer dc.mu.Unlock()
	return dc.DataChannel.Send(data)
}

// OnMessage registers a callback for data channel messages.
// The callback receives raw bytes.
func (dc *DataChannel) OnMessage(fn func([]byte)) {
	dc.onMessage = fn
	dc.DataChannel.OnMessage(func(msg pion.DataChannelMessage) {
		if fn != nil {
			fn(msg.Data)
		}
	})
}

// NewEngine creates a WebRTC engine with the given configuration.
func NewEngine(fn func(*EngineConfig)) (*Engine, error) {
	cfg := &EngineConfig{
		ICEServers: []string{"stun:stun.l.google.com:19302"},
	}
	fn(cfg)

	// ICE servers
	iceServers := make([]pion.ICEServer, len(cfg.ICEServers))
	for i, s := range cfg.ICEServers {
		iceServers[i] = pion.ICEServer{URLs: []string{s}}
	}

	// Create media engine with interceptor
	m := &pion.MediaEngine{}
	if err := m.RegisterDefaultCodecs(); err != nil {
		return nil, fmt.Errorf("register codecs: %w", err)
	}

	i := &interceptor.Registry{}
	if err := pion.RegisterDefaultInterceptors(m, i); err != nil {
		return nil, fmt.Errorf("register interceptors: %w", err)
	}

	api := pion.NewAPI(
		pion.WithMediaEngine(m),
		pion.WithInterceptorRegistry(i),
	)

	config := pion.Configuration{
		ICEServers:   iceServers,
		ICETransportPolicy: pion.ICETransportPolicyAll,
	}

	pc, err := api.NewPeerConnection(config)
	if err != nil {
		return nil, fmt.Errorf("create peer connection: %w", err)
	}

	e := &Engine{
		pc:           pc,
		config:       *cfg,
		dataChannels: make(map[string]*pion.DataChannel),
	}

	// ICE state handler
	pc.OnICEConnectionStateChange(func(state pion.ICEConnectionState) {
		log.Debug().Str("state", state.String()).Msg("ICE state changed")
		if cfg.OnICEState != nil {
			cfg.OnICEState(state)
		}
		if state == pion.ICEConnectionStateFailed ||
			state == pion.ICEConnectionStateDisconnected {
			e.Close()
		}
	})

	// Data channel handler
	pc.OnDataChannel(func(dc *pion.DataChannel) {
		e.mu.Lock()
		e.dataChannels[dc.Label()] = dc
		e.mu.Unlock()

		wrapped := &DataChannel{DataChannel: dc}

		dc.OnOpen(func() {
			log.Debug().Str("label", dc.Label()).Msg("Data channel opened")
			if cfg.OnDataChannel != nil {
				cfg.OnDataChannel(wrapped, dc.Label())
			}
		})

		dc.OnClose(func() {
			log.Debug().Str("label", dc.Label()).Msg("Data channel closed")
		})
	})

	// ICE candidate handler
	pc.OnICECandidate(func(candidate *pion.ICECandidate) {
		if candidate == nil || e.closed {
			return
		}
		msg := protocol.NewMessage(protocol.MsgICECandidate, candidate.ToJSON())
		msg.Room = e.config.RoomID
		if err := cfg.SignalConn.WriteJSON(msg); err != nil {
			log.Warn().Err(err).Msg("Failed to send ICE candidate")
		}
	})

	return e, nil
}

// CreateOffer creates and sets a local SDP offer.
func (e *Engine) CreateOffer() (map[string]interface{}, error) {
	offer, err := e.pc.CreateOffer(nil)
	if err != nil {
		return nil, fmt.Errorf("create offer: %w", err)
	}

	if err := e.pc.SetLocalDescription(offer); err != nil {
		return nil, fmt.Errorf("set local description: %w", err)
	}

	log.Debug().Msg("Created WebRTC offer")
	return map[string]interface{}{
		"type": offer.Type.String(),
		"sdp":  offer.SDP,
	}, nil
}

// HandleOffer processes a remote offer and sends an answer.
func (e *Engine) HandleOffer(msg protocol.Message) error {
	var offer struct {
		Type string `json:"type"`
		SDP  string `json:"sdp"`
	}
	if err := json.Unmarshal(msg.Payload, &offer); err != nil {
		return fmt.Errorf("parse offer: %w", err)
	}

	if err := e.pc.SetRemoteDescription(pion.SessionDescription{
		Type: pion.SDPTypeOffer,
		SDP:  offer.SDP,
	}); err != nil {
		return fmt.Errorf("set remote description: %w", err)
	}

	answer, err := e.pc.CreateAnswer(nil)
	if err != nil {
		return fmt.Errorf("create answer: %w", err)
	}

	if err := e.pc.SetLocalDescription(answer); err != nil {
		return fmt.Errorf("set local description: %w", err)
	}

	answerMsg := protocol.NewMessage(protocol.MsgAnswer, map[string]interface{}{
		"type": answer.Type.String(),
		"sdp":  answer.SDP,
	})
	answerMsg.Room = e.config.RoomID

	log.Debug().Msg("Created WebRTC answer")
	return e.config.SignalConn.WriteJSON(answerMsg)
}

// HandleAnswer processes a remote SDP answer.
func (e *Engine) HandleAnswer(msg protocol.Message) error {
	var answer struct {
		Type string `json:"type"`
		SDP  string `json:"sdp"`
	}
	if err := json.Unmarshal(msg.Payload, &answer); err != nil {
		return fmt.Errorf("parse answer: %w", err)
	}

	return e.pc.SetRemoteDescription(pion.SessionDescription{
		Type: pion.SDPTypeAnswer,
		SDP:  answer.SDP,
	})
}

// HandleICE processes an ICE candidate.
func (e *Engine) HandleICE(msg protocol.Message) error {
	var candidate pion.ICECandidateInit
	if err := json.Unmarshal(msg.Payload, &candidate); err != nil {
		return err
	}
	return e.pc.AddICECandidate(candidate)
}

// CreateDataChannel creates a new data channel.
func (e *Engine) CreateDataChannel(label string) *DataChannel {
	dc, err := e.pc.CreateDataChannel(label, &pion.DataChannelInit{
		Ordered:        boolPtr(true),
		MaxRetransmits: nil, // retry until success
	})
	if err != nil {
		log.Error().Err(err).Str("label", label).Msg("Failed to create data channel")
		return nil
	}

	e.mu.Lock()
	e.dataChannels[label] = dc
	e.mu.Unlock()

	return &DataChannel{DataChannel: dc}
}

// AddVideoTrack adds a video track for screen sharing.
func (e *Engine) AddVideoTrack() (*pion.TrackLocalStaticSample, error) {
	track, err := pion.NewTrackLocalStaticSample(
		pion.RTPCodecCapability{MimeType: pion.MimeTypeVP8},
		"screen",
		"screen-id",
	)
	if err != nil {
		return nil, fmt.Errorf("create video track: %w", err)
	}

	_, err = e.pc.AddTrack(track)
	if err != nil {
		return nil, fmt.Errorf("add video track: %w", err)
	}

	log.Debug().Msg("Video track added for screen sharing")
	return track, nil
}

// Close terminates the peer connection.
func (e *Engine) Close() error {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.closed {
		return nil
	}
	e.closed = true
	return e.pc.Close()
}

// ConnectionState returns the current ICE connection state.
func (e *Engine) ConnectionState() pion.ICEConnectionState {
	return e.pc.ICEConnectionState()
}

func boolPtr(b bool) *bool {
	return &b
}
