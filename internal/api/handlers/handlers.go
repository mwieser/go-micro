// Code generated by go run -tags scripts scripts/handlers/gen_handlers.go; DO NOT EDIT.
package handlers

import (
	"github.com/labstack/echo/v4"
	"github.com/mwieser/go-micro/internal/api"
	"github.com/mwieser/go-micro/internal/api/handlers/common"
)

func AttachAllRoutes(s *api.Server) {
	// attach our routes
	s.Router.Routes = []*echo.Route{
		common.GetHealthyRoute(s),
		common.GetReadyRoute(s),
		common.GetSwaggerRoute(s),
		common.GetVersionRoute(s),
	}
}
