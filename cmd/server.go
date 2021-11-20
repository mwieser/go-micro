package cmd

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/mwieser/go-micro/api/grpc/hello"
	"github.com/mwieser/go-micro/internal/api"
	"github.com/mwieser/go-micro/internal/api/router"
	"github.com/mwieser/go-micro/internal/config"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

const (
	probeFlag   string = "probe"
	migrateFlag string = "migrate"
	seedFlag    string = "seed"
)

// serverCmd represents the server command
var serverCmd = &cobra.Command{
	Use:   "server",
	Short: "Starts the server",
	Long: `Starts the stateless RESTful JSON server

Requires configuration through ENV and
and a fully migrated PostgreSQL database.`,
	Run: func(cmd *cobra.Command, args []string) {

		probeReadiness, err := cmd.Flags().GetBool(probeFlag)
		if err != nil {
			fmt.Printf("Error while parsing flags: %v\n", err)
			os.Exit(1)
		}

		if probeReadiness {
			runReadiness(true)
		}

		runServer()
	},
}

func init() {
	serverCmd.Flags().BoolP(probeFlag, "p", false, "Probe readiness before startup.")
	serverCmd.Flags().BoolP(migrateFlag, "m", false, "Apply migrations before startup.")
	serverCmd.Flags().BoolP(seedFlag, "s", false, "Seed fixtures into database before startup.")
	rootCmd.AddCommand(serverCmd)
}

func runServer() {
	config := config.DefaultServiceConfigFromEnv()

	zerolog.TimeFieldFormat = time.RFC3339Nano
	zerolog.SetGlobalLevel(config.Logger.Level)
	if config.Logger.PrettyPrintConsole {
		log.Logger = log.Output(zerolog.NewConsoleWriter(func(w *zerolog.ConsoleWriter) {
			w.TimeFormat = "15:04:05"
		}))
	}

	s := api.NewServer(config)

	router.Init(s)

	go func() {
		if err := s.StartHTTP(); err != nil {
			if err == http.ErrServerClosed {
				log.Info().Msg("Server closed")
			} else {
				log.Fatal().Err(err).Msg("Failed to start server")
			}
		}
	}()

	go func() {
		lis, err := net.Listen("tcp", fmt.Sprintf("localhost:%d", config.GRPC.Port))
		if err != nil {
			log.Fatal().Err(err).Int("port", config.GRPC.Port).Msg("failed to listen to port")
		}

		grpcServer := grpc.NewServer()
		hello.RegisterGreeterServer(grpcServer, s)

		log.Debug().Int("port", config.GRPC.Port).Msg("Listening to port for gRPC requests")
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatal().Err(err).Msg("Failed to serve")
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := s.Shutdown(ctx); err != nil && err != http.ErrServerClosed {
		log.Fatal().Err(err).Msg("Failed to gracefully shut down server")
	}
}
