package protocol

// MessageType defines the type of signaling message.
type MessageType string

const (
	// Host → Signal
	MsgRegister    MessageType = "register"
	MsgHeartbeat   MessageType = "heartbeat"

	// Client → Signal
	MsgRequestHost MessageType = "request_host"

	// Signal → Host/Client
	MsgOffer       MessageType = "offer"
	MsgAnswer      MessageType = "answer"
	MsgICE         MessageType = "ice_candidate"
	MsgApproved    MessageType = "approved"
	MsgRejected    MessageType = "rejected"
	MsgError       MessageType = "error"

	// Data channel messages (post-WebRTC)
	MsgResize      MessageType = "resize"       // terminal resize
	MsgInput       MessageType = "input"        // stdin
	MsgOutput      MessageType = "output"       // stdout
	MsgAuth        MessageType = "auth"         // master password
	MsgAuthOK      MessageType = "auth_ok"
	MsgAuthFail    MessageType = "auth_fail"
	MsgPing        MessageType = "ping"
	MsgPong        MessageType = "pong"
)

// SignalMessage is the envelope for all signaling traffic.
type SignalMessage struct {
	Type    MessageType `json:"type"`
	Payload interface{} `json:"payload,omitempty"`
	From    string      `json:"from,omitempty"`
	To      string      `json:"to,omitempty"`
	Room    string      `json:"room,omitempty"`
}

// RegisterPayload is sent by the host on connect.
type RegisterPayload struct {
	Hostname    string   `json:"hostname"`
	Platform    string   `json:"platform"`     // darwin, linux
	Arch        string   `json:"arch"`         // arm64, amd64
	Version     string   `json:"version"`
	NeedsMaster bool     `json:"needs_master"` // is master password required?
	Features    []string `json:"features"`     // "terminal", "screen"
}

// HostInfo describes a registered host for the client.
type HostInfo struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Platform    string   `json:"platform"`
	Arch        string   `json:"arch"`
	Version     string   `json:"version"`
	Online      bool     `json:"online"`
	NeedsMaster bool     `json:"needs_master"`
	Features    []string `json:"features"`
}

// AuthPayload is sent by the client to authenticate with master password.
type AuthPayload struct {
	Password string `json:"password"`
}

// ResizePayload for terminal window size changes.
type ResizePayload struct {
	Rows uint16 `json:"rows"`
	Cols uint16 `json:"cols"`
}
