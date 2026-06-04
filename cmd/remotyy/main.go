package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/gorilla/websocket"
	"github.com/rs/zerolog"
	"github.com/sametyilmaztemel/remotyy/internal/protocol"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	zerolog.SetGlobalLevel(zerolog.WarnLevel)

	switch os.Args[1] {
	case "ls", "list":
		listHosts(os.Args[2:])
	case "connect", "ssh":
		connectToHost(os.Args[2:])
	default:
		printUsage()
	}
}

func printUsage() {
	fmt.Println(`remotyy — Remote terminal access via WebRTC

Usage:
  remotyy ls [--signal ws://host:port]    List available hosts
  remotyy connect <host-id> [--signal ws://host:port] [--password pw]
  
Examples:
  remotyy ls --signal ws://localhost:9000
  remotyy connect host-abc123 --signal ws://localhost:9000`)
}

func listHosts(args []string) {
	signalURL := "ws://localhost:9000"
	for i, a := range args {
		if a == "--signal" && i+1 < len(args) {
			signalURL = args[i+1]
		}
	}

	conn, _, err := websocket.DefaultDialer.Dial(signalURL+"/ws", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error connecting to %s: %v\n", signalURL, err)
		os.Exit(1)
	}
	defer conn.Close()

	// Ask for hosts
	conn.WriteJSON(protocol.SignalMessage{
		Type:    protocol.MsgRequestHost,
		Payload: map[string]string{},
	})

	var resp protocol.SignalMessage
	conn.ReadJSON(&resp)

	if resp.Type == protocol.MsgRequestHost {
		data, _ := json.Marshal(resp.Payload)
		var result map[string]interface{}
		json.Unmarshal(data, &result)

		if hosts, ok := result["hosts"].([]interface{}); ok {
			if len(hosts) == 0 {
				fmt.Println("No hosts online.")
				return
			}
			fmt.Printf("%-24s %-12s %-8s %-10s\n", "ID", "NAME", "PLATFORM", "FEATURES")
			fmt.Println("──────────────────────────────────────────────────────────────")
			for _, h := range hosts {
				if host, ok := h.(map[string]interface{}); ok {
					id, _ := host["id"].(string)
					name, _ := host["name"].(string)
					platform, _ := host["platform"].(string)
					arch, _ := host["arch"].(string)
					features, _ := host["features"].([]interface{})
					featStr := ""
					for _, f := range features {
						featStr += fmt.Sprintf("%v ", f)
					}
					fmt.Printf("%-24s %-12s %s/%-5s %-10s\n",
						id[:min(len(id), 24)],
						name[:min(len(name), 12)],
						platform, arch, featStr)
				}
			}
		}
	}
	conn.Close()
}

func connectToHost(args []string) {
	if len(args) < 1 || args[0] == "" {
		fmt.Println("Usage: remotyy connect <host-id> [--signal ws://host:port]")
		os.Exit(1)
	}

	hostID := args[0]
	signalURL := "ws://localhost:9000"

	for i, a := range args {
		switch a {
		case "--signal":
			if i+1 < len(args) {
				signalURL = args[i+1]
			}
		}
	}

	fmt.Printf("Connecting to host %s via %s...\n", hostID, signalURL)

	// This is a placeholder — the full interactive terminal
	// will be implemented with xterm.js or a TUI.
	// For now, it establishes the WebRTC connection and
	// creates an interactive terminal session.
	fmt.Println("Interactive terminal mode coming soon.")
	fmt.Println("For now, use the web interface at web/ directory.")
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
