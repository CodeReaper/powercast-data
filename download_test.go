package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestExpectedData(t *testing.T) {
	svr := SetupServerWith(t, "testdata/dataset-elspotprices.raw")
	defer svr.Close()

	records, err := fetchRecords(svr.URL, "", 0, 1, 1)
	assert.Nil(t, err)

	assert.Equal(t, 5, len(records))
}

func TestExpectedOutput(t *testing.T) {
	expected, err := os.ReadFile("testdata/dataset-elspotprices-expected.raw")
	assert.Nil(t, err)

	svr := SetupServerWith(t, "testdata/dataset-elspotprices.raw")
	defer svr.Close()

	records, err := fetchRecords(svr.URL, "", 0, 1, 1)
	assert.Nil(t, err)

	output, err := os.MkdirTemp("", "test")
	assert.Nil(t, err)

	err = saveRecords("DK1", records, output)
	assert.Nil(t, err)

	bytes, err := os.ReadFile(filepath.Join(output, "2022/07/18/DK1.json"))
	assert.Nil(t, err)

	assert.Equal(t, expected, bytes)
}

func SetupServerWith(t *testing.T, file string) *httptest.Server {
	expected, err := os.ReadFile(file)
	assert.Nil(t, err)

	svr := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, string(expected))
	}))

	return svr
}
