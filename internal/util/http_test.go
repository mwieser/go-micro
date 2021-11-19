package util_test

import (
	"bytes"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"testing"

	"github.com/labstack/echo/v4"
	"github.com/mwieser/go-micro/internal/api"
	"github.com/mwieser/go-micro/internal/test"
	"github.com/mwieser/go-micro/internal/util"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParseFileUplaod(t *testing.T) {
	originalDocumentPath := filepath.Join(util.GetProjectRootDir(), "test", "testdata", "example.jpg")
	body, contentType := prepareFileUpload(t, originalDocumentPath)

	e := echo.New()
	e.POST("/", func(c echo.Context) error {

		fh, file, mime, err := util.ParseFileUpload(c, "file", []string{"image/jpeg"})
		require.NoError(t, err)
		assert.True(t, mime.Is("image/jpeg"))
		assert.NotEmpty(t, fh)
		assert.NotEmpty(t, file)

		return c.NoContent(204)
	})

	s := &api.Server{
		Echo: e,
	}

	headers := http.Header{}
	headers.Set(echo.HeaderContentType, contentType)

	res := test.PerformRequestWithRawBody(t, s, "POST", "/", body, headers, nil)

	require.Equal(t, http.StatusNoContent, res.Result().StatusCode)
}

func TestParseFileUplaodUnsupported(t *testing.T) {
	originalDocumentPath := filepath.Join(util.GetProjectRootDir(), "test", "testdata", "example.jpg")
	body, contentType := prepareFileUpload(t, originalDocumentPath)

	e := echo.New()
	e.POST("/", func(c echo.Context) error {

		fh, file, mime, err := util.ParseFileUpload(c, "file", []string{"image/png"})
		assert.Nil(t, fh)
		assert.Nil(t, file)
		assert.Nil(t, mime)
		if err != nil {
			return err
		}

		return c.NoContent(204)
	})

	s := &api.Server{
		Echo: e,
	}

	headers := http.Header{}
	headers.Set(echo.HeaderContentType, contentType)

	res := test.PerformRequestWithRawBody(t, s, "POST", "/", body, headers, nil)

	require.Equal(t, http.StatusUnsupportedMediaType, res.Result().StatusCode)
}

func prepareFileUpload(t *testing.T, filePath string) (*bytes.Buffer, string) {
	t.Helper()

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)

	src, err := os.Open(filePath)
	require.NoError(t, err)
	defer src.Close()

	dst, err := writer.CreateFormFile("file", src.Name())
	require.NoError(t, err)

	_, err = io.Copy(dst, src)
	require.NoError(t, err)

	err = writer.Close()
	require.NoError(t, err)

	return &body, writer.FormDataContentType()
}
