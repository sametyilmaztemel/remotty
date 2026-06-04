package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	gosignal "os/signal"
	"syscall"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/sametyilmaztemel/remotyy/internal/config"
	"github.com/sametyilmaztemel/remotyy/internal/signal"
)

func main() {
	port := flag.Int("port", 9000, "Signaling server port")
	host := flag.String("host", "0.0.0.0", "Bind address")
	dev := flag.Bool("dev", false, "Developer mode (no auth)")
	flag.Parse()

	// Setup logging
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	if *dev {
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
		log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})
	} else {
		zerolog.SetGlobalLevel(zerolog.InfoLevel)
	}

	token := os.Getenv("REMOTYY_AUTH_TOKEN")
	if token == "" && !*dev {
		log.Warn().Msg("REMOTYY_AUTH_TOKEN not set — signaling server is open")
	}

	server := signal.NewServer(token, *dev)

	mux := server.HTTPHandler()
	addr := fmt.Sprintf("%s:%d", *host, *port)

	httpServer := &http.Server{
		Addr:    addr,
		Handler: withCORS(mux),
	}

	// Graceful shutdown
	sigCh := make(chan os.Signal, 1)
	gosignal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		log.Info().Msg("Shutting down signaling server...")
		httpServer.Close()
	}()

	log.Info().
		Str("version", config.Version).
		Str("addr", addr).
		Bool("dev", *dev).
		Msg("remotyy-signal starting")

	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal().Err(err).Msg("Server failed")
	}
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}
