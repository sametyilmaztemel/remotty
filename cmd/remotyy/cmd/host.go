package cmd

import (
	"context"
	"os"
	gosignal "os/signal"
	"syscall"

	"github.com/rs/zerolog/log"
	"github.com/sametyilmaztemel/remotyy/internal/config"
	"github.com/sametyilmaztemel/remotyy/internal/host"
	"github.com/spf13/cobra"
)

var hostCmd = &cobra.Command{
	Use:   "host",
	Short: "Start the host daemon",
	Long: `Start the remotyy host daemon on this machine.
Connects to signaling server and waits for client connections.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg := globalCfg.Host

		if env := os.Getenv("REMOTYY_SIGNAL_URL"); env != "" {
			cfg.SignalURL = env
		}
		if env := os.Getenv("REMOTYY_MASTER_PASSWORD"); env != "" && cfg.MasterPassword == "" {
			cfg.MasterPassword = env
		}

		daemon, err := host.NewDaemon(cfg, log.Logger)
		if err != nil {
			log.Fatal().Err(err).Msg("Failed to create host daemon")
			return err
		}

		ctx, stop := gosignal.NotifyContext(context.Background(),
			syscall.SIGINT, syscall.SIGTERM)
		defer stop()

		log.Info().
			Str("version", config.Version).
			Str("name", cfg.Name).
			Str("signal", cfg.SignalURL).
			Strs("features", cfg.Features).
			Bool("has_master_pw", cfg.MasterPassword != "" || cfg.MasterHash != "").
			Msg("Host daemon starting")

		return daemon.Run(ctx)
	},
}

func init() {
	rootCmd.AddCommand(hostCmd)
	hostCmd.Flags().StringP("signal", "s", "ws://localhost:9000", "Signaling server URL")
	hostCmd.Flags().StringP("name", "n", "", "Host display name")
	hostCmd.Flags().StringP("master-password", "m", "", "Master password")
}
