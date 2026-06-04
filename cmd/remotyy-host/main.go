package main

import (
	"flag"
	"os"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/sametyilmaztemel/remotyy/internal/config"
	"github.com/sametyilmaztemel/remotyy/internal/host"
	"github.com/sametyilmaztemel/remotyy/internal/auth"
)

func main() {
	signalURL := flag.String("signal", "ws://localhost:9000", "Signaling server URL")
	hostname := flag.String("name", "", "Host display name (default: system hostname)")
	masterPW := flag.String("master-password", "", "Master password for terminal access")
	deviceName := flag.String("device", "", "Device name for allow listing")
	flag.Parse()

	// Setup logging
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})
	zerolog.SetGlobalLevel(zerolog.InfoLevel)

	// Load env overrides if available
	if envURL := os.Getenv("REMOTYY_SIGNAL_URL"); envURL != "" {
		*signalURL = envURL
	}
	if envPW := os.Getenv("REMOTYY_MASTER_PASSWORD"); envPW != "" && *masterPW == "" {
		*masterPW = envPW
	}

	// Hash master password if provided
	var masterHash string
	if *masterPW != "" {
		hash, err := auth.HashPassword(*masterPW)
		if err != nil {
			log.Fatal().Err(err).Msg("Failed to hash master password")
		}
		masterHash = hash
		log.Info().Msg("Master password enabled — clients must authenticate")
	}

	features := []string{"terminal"}

	cfg := host.Config{
		SignalURL:     *signalURL,
		Hostname:      *hostname,
		MasterHash:    masterHash,
		Features:      features,
		DeviceName:    *deviceName,
	}

	daemon := host.NewDaemon(cfg)

	log.Info().
		Str("version", config.Version).
		Str("signal", *signalURL).
		Str("hostname", daemon.Hostname()).
		Msgf("remotyy-host starting — %s", config.Version)

	if err := daemon.Run(); err != nil {
		log.Fatal().Err(err).Msg("Host daemon failed")
	}
}
