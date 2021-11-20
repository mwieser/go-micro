package api

import (
	"context"
	"errors"

	"github.com/labstack/echo/v4"
	"github.com/mwieser/go-micro/api/grpc/hello"
	"github.com/mwieser/go-micro/internal/config"
	"github.com/rs/zerolog/log"

	// Import postgres driver for database/sql package
	_ "github.com/lib/pq"
)

type Router struct {
	Routes     []*echo.Route
	Root       *echo.Group
	Management *echo.Group
}

type Server struct {
	hello.UnimplementedGreeterServer
	Config config.Server
	Echo   *echo.Echo
	Router *Router
}

func NewServer(config config.Server) *Server {
	s := &Server{
		Config: config,
		Echo:   nil,
		Router: nil,
	}

	return s
}

func (s *Server) Ready() bool {
	return s.Echo != nil &&
		s.Router != nil
}

func (s *Server) StartHTTP() error {
	if !s.Ready() {
		return errors.New("server is not ready")
	}

	return s.Echo.Start(s.Config.Echo.ListenAddress)
}

func (s *Server) Shutdown(ctx context.Context) error {
	log.Warn().Msg("Shutting down server")

	log.Debug().Msg("Shutting down echo server")

	return s.Echo.Shutdown(ctx)
}
