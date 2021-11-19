package common_test

import (
	"net/http"
	"testing"

	"github.com/mwieser/go-micro/internal/api"
	"github.com/mwieser/go-micro/internal/test"
	"github.com/stretchr/testify/require"
)

func TestGetReadyReadiness(t *testing.T) {
	test.WithTestServer(t, func(s *api.Server) {
		res := test.PerformRequest(t, s, "GET", "/-/ready", nil, nil)
		require.Equal(t, http.StatusOK, res.Result().StatusCode)
		require.Equal(t, res.Body.String(), "Ready.")
	})
}
