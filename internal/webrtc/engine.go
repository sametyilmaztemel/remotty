package webrtc

import (
	"encoding/json"
	"fmt"
	"sync"

	"github.com/gorilla/websocket"
	pion "github.com/pion/webrtc/v4"
	"github.com/rs/zerolog/log"
	"github.com/sametyilmaztemel/remotyy/internal/protocol"
)

// Engine manages a WebRTC peer connection.
type Engine struct {
	pc           *pion.PeerConnection
	config       EngineConfig
	mu           sync.Mutex
	dataChannels map[string]*pion.DataChannel
}

// EngineConfig for WebRTC engine setup.
type EngineConfig struct {
	SignalConn    *websocket.Conn
	RoomID        string
	ICEServers    []string
	OnDataChannel func(dc *pion.DataChannel, label string)
}

// DataChannelMessage wraps pion's DataChannelMessage.
type DataChannelMessage = pion.DataChannelMessage

// NewEngine creates a new WebRTC engine.
func NewEngine(fn func(*EngineConfig)) (*Engine, error) {
	cfg := &EngineConfig{
		ICEServers: []string{
			"stun:stun.l.google.com:19302",
			"stun:stun1.l.google.com:19302",
		},
	}
	fn(cfg)

	config := pion.Configuration{
		ICEServers: []pion.ICEServer{
			{URLs: []string{"stun:stun.l.google.com:19302"}},
			{URLs: []string{"stun:stun1.l.google.com:19302"}},
		},
	}

	settings := pion.SettingEngine{}
	settings.SetICETimeouts(10, 5, 3)

	api := pion.NewAPI(pion.WithSettingEngine(settings))
	pc, err := api.NewPeerConnection(config)
	if err != nil {
		return nil, fmt.Errorf("create peer connection: %w", err)
	}

	e := &Engine{
		pc:           pc,
		config:       *cfg,
		dataChannels: make(map[string]*pion.DataChannel),
	}

	pc.OnICEConnectionStateChange(func(state pion.ICEConnectionState) {
		log.Info().Str("state", state.String()).Msg("ICE state changed")
	})

	pc.OnDataChannel(func(dc *pion.DataChannel) {
		e.dataChannels[dc.Label()] = dc
		dc.OnMessage(func(msg pion.DataChannelMessage) {
			if e.config.OnDataChannel != nil {
				e.config.OnDataChannel(dc, dc.Label())
			}
		})
	})

	pc.OnICECandidate(func(candidate *pion.ICECandidate) {
		if candidate == nil {
			return
		}
		candJSON := candidate.ToJSON()
		msg := protocol.SignalMessage{
			Type:    protocol.MsgICE,
			Payload: candJSON,
			Room:    e.config.RoomID,
		}
		if err := e.config.SignalConn.WriteJSON(msg); err != nil {
			log.Error().Err(err).Msg("Failed to send ICE candidate")
		}
	})

	return e, nil
}

// CreateOffer initiates a WebRTC connection as the offerer.
func (e *Engine) CreateOffer() (map[string]interface{}, error) {
	offer, err := e.pc.CreateOffer(nil)
	if err != nil {
		return nil, fmt.Errorf("create offer: %w", err)
	}
	if err := e.pc.SetLocalDescription(offer); err != nil {
		return nil, fmt.Errorf("set local description: %w", err)
	}
	return map[string]interface{}{
		"type": offer.Type.String(),
		"sdp":  offer.SDP,
	}, nil
}

// HandleOffer processes an incoming offer.
func (e *Engine) HandleOffer(msg protocol.SignalMessage) error {
	data, _ := json.Marshal(msg.Payload)
	var parsed struct {
		Type string `json:"type"`
		SDP  string `json:"sdp"`
	}
	json.Unmarshal(data, &parsed)

	desc := pion.SessionDescription{
		Type: pion.SDPTypeOffer,
		SDP:  parsed.SDP,
	}

	if err := e.pc.SetRemoteDescription(desc); err != nil {
		return fmt.Errorf("set remote description: %w", err)
	}

	answer, err := e.pc.CreateAnswer(nil)
	if err != nil {
		return fmt.Errorf("create answer: %w", err)
	}
	if err := e.pc.SetLocalDescription(answer); err != nil {
		return fmt.Errorf("set local description: %w", err)
	}

	answerMsg := protocol.SignalMessage{
		Type: protocol.MsgAnswer,
		Payload: map[string]interface{}{
			"type": answer.Type.String(),
			"sdp":  answer.SDP,
		},
		Room: e.config.RoomID,
	}
	return e.config.SignalConn.WriteJSON(answerMsg)
}

// HandleAnswer processes an incoming answer.
func (e *Engine) HandleAnswer(msg protocol.SignalMessage) error {
	data, _ := json.Marshal(msg.Payload)
	var parsed struct {
		Type string `json:"type"`
		SDP  string `json:"sdp"`
	}
	json.Unmarshal(data, &parsed)

	desc := pion.SessionDescription{
		Type: pion.SDPTypeAnswer,
		SDP:  parsed.SDP,
	}
	return e.pc.SetRemoteDescription(desc)
}

// HandleICE processes an ICE candidate.
func (e *Engine) HandleICE(msg protocol.SignalMessage) error {
	data, _ := json.Marshal(msg.Payload)
	var candidate pion.ICECandidateInit
	if err := json.Unmarshal(data, &candidate); err != nil {
		return err
	}
	return e.pc.AddICECandidate(candidate)
}

// CreateDataChannel creates a new data channel.
func (e *Engine) CreateDataChannel(label string) *pion.DataChannel {
	dc, err := e.pc.CreateDataChannel(label, nil)
	if err != nil {
		log.Error().Err(err).Str("label", label).Msg("Failed to create data channel")
		return nil
	}
	e.dataChannels[label] = dc
	return dc
}

// Close terminates the peer connection.
func (e *Engine) Close() error {
	return e.pc.Close()
}
