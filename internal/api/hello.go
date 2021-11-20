package api

import (
	"context"

	"github.com/mwieser/go-micro/api/grpc/hello"
	"github.com/rs/zerolog/log"
)

func (s *Server) SayHello(ctx context.Context, in *hello.HelloRequest) (*hello.HelloReply, error) {
	log.Debug().Str("name", in.GetName()).Msg("received")
	return &hello.HelloReply{Message: "Hello " + in.GetName()}, nil
}
