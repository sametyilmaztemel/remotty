// Package config provides centralized configuration for all remotyy components.
// Supports loading from YAML file, environment variables, and CLI flags.
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/rs/zerolog"
	"github.com/spf13/viper"
)

// Defaults
const (
	DefaultSignalPort    = 9000
	DefaultSignalHost    = "0.0.0.0"
	DefaultWebPort       = 3000
	DefaultSTUNServer    = "stun:stun.l.google.com:19302"
	DefaultReconnectWait = 5 * time.Second
	DefaultHeartbeatInt  = 15 * time.Second
	DefaultSessionTimeout = 30 * time.Minute
	DefaultMaxSessions   = 10
	DefaultLogLevel      = "info"
)

// Config is the top-level configuration.
type Config struct {
	Global   GlobalConfig   `mapstructure:"global"`
	Signal   SignalConfig   `mapstructure:"signal"`
	Host     HostConfig     `mapstructure:"host"`
	Client   ClientConfig   `mapstructure:"client"`
	WebRTC   WebRTCConfig   `mapstructure:"webrtc"`
	Logging  LoggingConfig  `mapstructure:"logging"`
	Screen   ScreenConfig   `mapstructure:"screen"`
}

// GlobalConfig contains global settings.
type GlobalConfig struct {
	DataDir    string `mapstructure:"data_dir"`
	ConfigFile string `mapstructure:"config_file"`
}

// SignalConfig for the signaling server.
type SignalConfig struct {
	Host            string        `mapstructure:"host"`
	Port            int           `mapstructure:"port"`
	TLS             TLSConfig     `mapstructure:"tls"`
	AuthToken       string        `mapstructure:"auth_token"`
	RateLimit       int           `mapstructure:"rate_limit"`
	AllowedOrigins  []string      `mapstructure:"allowed_origins"`
	DevMode         bool          `mapstructure:"dev_mode"`
	WebDir          string        `mapstructure:"web_dir"`
}

// TLSConfig for encrypted connections.
type TLSConfig struct {
	Enabled  bool   `mapstructure:"enabled"`
	CertFile string `mapstructure:"cert_file"`
	KeyFile  string `mapstructure:"key_file"`
}

// HostConfig for the host daemon.
type HostConfig struct {
	SignalURL      string        `mapstructure:"signal_url"`
	Name           string        `mapstructure:"name"`
	MasterPassword string        `mapstructure:"master_password"`
	MasterHash     string        `mapstructure:"master_hash"`
	AllowList      []string      `mapstructure:"allow_list"`
	Features       []string      `mapstructure:"features"`
	ReconnectWait  time.Duration `mapstructure:"reconnect_wait"`
	HeartbeatInt   time.Duration `mapstructure:"heartbeat_interval"`
	SessionTimeout time.Duration `mapstructure:"session_timeout"`
	MaxSessions    int           `mapstructure:"max_sessions"`
	RequireAuth    bool          `mapstructure:"require_auth"`
	DeviceID       string        `mapstructure:"device_id"`
	ShowQR         bool          `mapstructure:"show_qr"`
	OnRegistered   func(peerID string)
}

// ClientConfig for the client.
type ClientConfig struct {
	SignalURL      string `mapstructure:"signal_url"`
	HostID         string `mapstructure:"host_id"`
	MasterPassword string `mapstructure:"master_password"`
	Insecure       bool   `mapstructure:"insecure"`
}

// WebRTCConfig for ICE and peer connections.
type WebRTCConfig struct {
	ICEServers    []string `mapstructure:"ice_servers"`
	MDNS          bool     `mapstructure:"mdns"`
	ICETimeout    int      `mapstructure:"ice_timeout"`
	MaxMessageSize int     `mapstructure:"max_message_size"`
}

// LoggingConfig for output control.
type LoggingConfig struct {
	Level  string `mapstructure:"level"`
	Format string `mapstructure:"format"` // json, console
	File   string `mapstructure:"file"`
}

// ScreenConfig for screen sharing.
type ScreenConfig struct {
	Enabled      bool    `mapstructure:"enabled"`
	FPS          int     `mapstructure:"fps"`
	Quality      int     `mapstructure:"quality"`
	MaxDimension int     `mapstructure:"max_dimension"`
	CaptureCursor bool   `mapstructure:"capture_cursor"`
}

// Load reads configuration from file, env, and defaults.
func Load(configPath string) (*Config, error) {
	v := viper.New()

	// Defaults
	v.SetDefault("global.data_dir", defaultDataDir())
	v.SetDefault("signal.host", DefaultSignalHost)
	v.SetDefault("signal.port", DefaultSignalPort)
	v.SetDefault("signal.rate_limit", 60)
	v.SetDefault("signal.dev_mode", false)
	v.SetDefault("host.reconnect_wait", DefaultReconnectWait)
	v.SetDefault("host.heartbeat_interval", DefaultHeartbeatInt)
	v.SetDefault("host.session_timeout", DefaultSessionTimeout)
	v.SetDefault("host.max_sessions", 0) // 0 = unlimited
	v.SetDefault("host.features", []string{"terminal"})
	v.SetDefault("webrtc.ice_servers", []string{DefaultSTUNServer})
	v.SetDefault("webrtc.mdns", true)
	v.SetDefault("webrtc.ice_timeout", 10)
	v.SetDefault("webrtc.max_message_size", 65536)
	v.SetDefault("logging.level", DefaultLogLevel)
	v.SetDefault("logging.format", "console")
	v.SetDefault("screen.enabled", false)
	v.SetDefault("screen.fps", 15)
	v.SetDefault("screen.quality", 60)
	v.SetDefault("screen.max_dimension", 1920)
	v.SetDefault("screen.capture_cursor", false)

	// Env bindings
	envBindings := map[string]string{
		"signal.auth_token":    "REMOTYY_AUTH_TOKEN",
		"host.signal_url":     "REMOTYY_SIGNAL_URL",
		"host.master_password":"REMOTYY_MASTER_PASSWORD",
		"host.name":           "REMOTYY_HOST_NAME",
		"host.device_id":      "REMOTYY_DEVICE_ID",
		"client.signal_url":   "REMOTYY_SIGNAL_URL",
		"client.master_password":"REMOTYY_MASTER_PASSWORD",
		"signal.tls.cert_file":"REMOTYY_TLS_CERT",
		"signal.tls.key_file": "REMOTYY_TLS_KEY",
		"logging.level":       "REMOTYY_LOG_LEVEL",
		"logging.file":        "REMOTYY_LOG_FILE",
	}
	for key, env := range envBindings {
		v.MustBindEnv(key, env)
	}

	// Config file
	if configPath != "" {
		v.SetConfigFile(configPath)
	} else {
		v.SetConfigName("remotyy")
		v.SetConfigType("yaml")
		v.AddConfigPath(".")
		v.AddConfigPath("$HOME/.remotyy")
		v.AddConfigPath("/etc/remotyy")
	}

	// Read config
	if err := v.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("read config: %w", err)
		}
	}

	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("unmarshal config: %w", err)
	}

	// Post-processing
	if cfg.Host.Name == "" {
		cfg.Host.Name, _ = os.Hostname()
	}

	return &cfg, nil
}

// SignalAddr returns the full signal server address.
func (s *SignalConfig) Addr() string {
	return fmt.Sprintf("%s:%d", s.Host, s.Port)
}

// WSSAddr returns the WebSocket URL.
func (s *SignalConfig) WSSAddr() string {
	scheme := "ws"
	if s.TLS.Enabled {
		scheme = "wss"
	}
	return fmt.Sprintf("%s://%s:%d", scheme, s.Host, s.Port)
}

// ParseLevel converts log level string to zerolog.Level.
func (l *LoggingConfig) ParseLevel() zerolog.Level {
	switch strings.ToLower(l.Level) {
	case "debug":
		return zerolog.DebugLevel
	case "info":
		return zerolog.InfoLevel
	case "warn":
		return zerolog.WarnLevel
	case "error":
		return zerolog.ErrorLevel
	default:
		return zerolog.InfoLevel
	}
}

func defaultDataDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "/tmp/remotyy"
	}
	return filepath.Join(home, ".remotyy")
}

// Validate checks the config for common issues.
func (c *Config) Validate() error {
	var errs []string

	// Signal server
	if c.Signal.Port < 0 || c.Signal.Port > 65535 {
		errs = append(errs, "signal.port must be 0-65535")
	}
	if c.Signal.TLS.Enabled {
		if c.Signal.TLS.CertFile == "" {
			errs = append(errs, "signal.tls.cert_file is required when TLS enabled")
		}
		if c.Signal.TLS.KeyFile == "" {
			errs = append(errs, "signal.tls.key_file is required when TLS enabled")
		}
	}

	// Host daemon
	if c.Host.ReconnectWait < 0 {
		errs = append(errs, "host.reconnect_wait must be >= 0")
	}
	if c.Host.HeartbeatInt < 0 {
		errs = append(errs, "host.heartbeat_interval must be >= 0")
	}
	if c.Host.SessionTimeout < 0 {
		errs = append(errs, "host.session_timeout must be >= 0")
	}
	if c.Host.MaxSessions < 0 {
		errs = append(errs, "host.max_sessions must be >= 0")
	}

	// WebRTC
	if c.WebRTC.ICETimeout < 0 {
		errs = append(errs, "webrtc.ice_timeout must be >= 0")
	}
	if c.WebRTC.MaxMessageSize < 0 {
		errs = append(errs, "webrtc.max_message_size must be >= 0")
	}

	// Screen
	if c.Screen.FPS < 0 || c.Screen.FPS > 120 {
		errs = append(errs, "screen.fps must be 0-120")
	}
	if c.Screen.Quality < 0 || c.Screen.Quality > 100 {
		errs = append(errs, "screen.quality must be 0-100")
	}
	if c.Screen.MaxDimension < 0 {
		errs = append(errs, "screen.max_dimension must be >= 0")
	}

	// Logging
	switch strings.ToLower(c.Logging.Level) {
	case "debug", "info", "warn", "error", "trace", "fatal", "disabled", "":
		// valid
	default:
		errs = append(errs, fmt.Sprintf("logging.level invalid: %q", c.Logging.Level))
	}

	// Security warnings (not errors, just logged)
	if c.Signal.AuthToken == "" && !c.Signal.DevMode {
		// Will be logged by caller
	}
	if c.Host.MasterPassword == "" && c.Host.MasterHash == "" && c.Host.RequireAuth {
		errs = append(errs, "host.require_auth is true but no master_password/master_hash set")
	}

	if len(errs) > 0 {
		return fmt.Errorf("config validation failed:\n  - %s", strings.Join(errs, "\n  - "))
	}
	return nil
}

// Version info set at build time.
var (
	Version = "dev"
	Commit  = "unknown"
	Date    = "unknown"
)
