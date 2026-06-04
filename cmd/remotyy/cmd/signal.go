package cmd

import (
	"context"
	"os"
	gosignal "os/signal"
	"syscall"

	"github.com/rs/zerolog/log"
	"github.com/sametyilmaztemel/remotyy/internal/config"
	"github.com/sametyilmaztemel/remotyy/internal/signal"
	"github.com/spf13/cobra"
)

var signalCmd = &cobra.Command{
	Use:   "signal",
	Short: "Start the signaling server",
	Long: `Start the WebSocket signaling server for WebRTC negotiation.
The signaling server is a blind relay — it coordinates connections
but never sees terminal or screen data.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg := globalCfg.Signal

		if authToken := os.Getenv("REMOTYY_AUTH_TOKEN"); authToken != "" {
			cfg.AuthToken = authToken
		}

		server := signal.NewServer(cfg, logger)

		ctx, stop := gosignal.NotifyContext(context.Background(),
			syscall.SIGINT, syscall.SIGTERM)
		defer stop()

		log.Info().
			Str("version", config.Version).
			Str("addr", cfg.Addr()).
			Bool("tls", cfg.TLS.Enabled).
			Bool("dev_mode", cfg.DevMode).
			Msg("Signaling server starting")

		return server.Start(ctx)
	},
}

func init() {
	rootCmd.AddCommand(signalCmd)
	signalCmd.Flags().IntP("port", "p", 9000, "Signaling server port")
	signalCmd.Flags().StringP("host", "H", "0.0.0.0", "Bind address")
	signalCmd.Flags().Bool("dev", false, "Developer mode")
	signalCmd.Flags().Bool("tls", false, "Enable TLS")
	signalCmd.Flags().String("tls-cert", "", "TLS cert file")
	signalCmd.Flags().String("tls-key", "", "TLS key file")
}
