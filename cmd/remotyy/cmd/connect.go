package cmd

import (
	"context"
	"fmt"
	"os"
	gosignal "os/signal"
	"syscall"

	"github.com/rs/zerolog/log"
	"github.com/sametyilmaztemel/remotyy/internal/client"
	"github.com/spf13/cobra"
)

var connectCmd = &cobra.Command{
	Use:   "connect [host-id]",
	Short: "Connect to a remote host",
	Long: `Connect to a remotyy host for remote terminal access.
If no host ID is given, lists available hosts.`,
	Args: cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg := globalCfg.Client

		if env := os.Getenv("REMOTYY_SIGNAL_URL"); env != "" {
			cfg.SignalURL = env
		}
		if env := os.Getenv("REMOTYY_MASTER_PASSWORD"); env != "" && cfg.MasterPassword == "" {
			cfg.MasterPassword = env
		}

		if len(args) > 0 {
			cfg.HostID = args[0]
		}

		c, err := client.NewClient(cfg, log.Logger)
		if err != nil {
			return err
		}

		// List mode
		if cfg.HostID == "" {
			hosts, err := c.ListHosts()
			if err != nil {
				return fmt.Errorf("list hosts: %w", err)
			}
			if len(hosts) == 0 {
				fmt.Println("No hosts available. Start a host with: remotyy host")
				return nil
			}
			fmt.Println("\nAvailable hosts:")
			for _, h := range hosts {
				fmt.Printf("  %s — %s/%s [%s]\n",
					h.Name, h.Platform, h.Arch, joinStrings(h.Features, ", "))
			}
			return nil
		}

		ctx, stop := gosignal.NotifyContext(context.Background(),
			syscall.SIGINT, syscall.SIGTERM)
		defer stop()

		return c.ConnectInteractive(ctx)
	},
}

func init() {
	rootCmd.AddCommand(connectCmd)
	connectCmd.Flags().StringP("signal", "s", "ws://localhost:9000", "Signaling server URL")
	connectCmd.Flags().StringP("password", "p", "", "Master password")
}

func joinStrings(s []string, sep string) string {
	result := ""
	for i, v := range s {
		if i > 0 {
			result += sep
		}
		result += v
	}
	return result
}
