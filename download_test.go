package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestThatKnownDataProducesExpectedRecords(t *testing.T) {
	svr := SetupServerWith(t, "testdata/dataset-elspotprices.raw")
	defer svr.Close()

	records, err := fetchRecords(svr.URL, "", 0, 1, 1)
	assert.Nil(t, err)

	assert.Equal(t, 5, len(records))
}

func TestThatKnownDataProducesExpectedOutputFilesAndRecords(t *testing.T) {
	expected, err := os.ReadFile("testdata/dataset-elspotprices-expected.raw")
	assert.Nil(t, err)

	svr := SetupServerWith(t, "testdata/dataset-elspotprices.raw")
	defer svr.Close()

	output, err := os.MkdirTemp("", "test")
	assert.Nil(t, err)

	records, err := fetchRecords(svr.URL, "", 0, 1, 1)
	assert.Nil(t, err)

	err = saveRecords("DK1", records, output)
	assert.Nil(t, err)

	bytes, err := os.ReadFile(filepath.Join(output, "2022/07/18/DK1.json"))
	assert.Nil(t, err)

	assert.Equal(t, expected, bytes)
}

func TestThatKnownDataProducesExpectedOutputFiles(t *testing.T) {
	expected, err := os.ReadFile("testdata/dataset-elspotprices-expected.raw")
	assert.Nil(t, err)

	svr := SetupServerWith(t, "testdata/dataset-elspotprices.raw")
	defer svr.Close()

	output, err := os.MkdirTemp("", "test")
	assert.Nil(t, err)

	err = run(svr.URL, "DK1", 0, 1, 1, output)
	assert.Nil(t, err)

	bytes, err := os.ReadFile(filepath.Join(output, "2022/07/18/DK1.json"))
	assert.Nil(t, err)

	assert.Equal(t, expected, bytes)
}

func TestThatNoDataProducesExpectedRecords(t *testing.T) {
	svr := SetupServerWith(t, "")
	defer svr.Close()

	records, err := fetchRecords(svr.URL, "", 0, 1, 1)
	assert.Nil(t, err)

	assert.Equal(t, 0, len(records))
}

func TestThatFailingHttpRequestsDoesNotProduceRecords(t *testing.T) {
	spots := SpotRecords{Records: []SpotRecord{{Euro: 0.0, Timestamp: "2022-07-18T20:00:00"}}}
	unexpected, err := json.Marshal(spots)
	assert.Nil(t, err)

	svr := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(400)
		fmt.Fprint(w, string(unexpected))
	}))
	defer svr.Close()

	records, err := fetchRecords(svr.URL, "", 0, 1, 1)
	assert.NotNil(t, err)

	assert.Equal(t, 0, len(records))
}

func SetupServerWith(t *testing.T, file string) *httptest.Server {
	expected := `{"records":[]}`
	if len(file) != 0 {
		bytes, err := os.ReadFile(file)
		expected = string(bytes)
		assert.Nil(t, err)
	}

	svr := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, expected)
	}))

	return svr
}

// FIXME: add these tests

// # Test that write outputs uniquely with energy price data
// set -e
// mkdir /tmp/t/test
// mkdir /tmp/t/test2
// jq -r '. | map(.euro = 0)' test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json > /tmp/t/changed
// sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/t/test DK1
// sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/t/test2 DK1
// sh src/data-write.sh /tmp/t/changed /tmp/t/test2 DK1
// diff -rq /tmp/t/test /tmp/t/test2 || { echo "Unexpected difference:"; diff -r /tmp/t/test /tmp/t/test2; exit 1; }
// rm -rf /tmp/t/test*
// rm /tmp/t/changed

// # Test that write handles updating files correctly
// set -e
// mkdir /tmp/t/test
// mkdir /tmp/t/test2
// jq -r '[ .[] | select(.timestamp < 1654084800)]' test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json > /tmp/t/half
// sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/t/test DK1
// sh src/data-write.sh /tmp/t/half /tmp/t/test2 DK1
// sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/t/test2 DK1
// diff -rq /tmp/t/test /tmp/t/test2 || { echo "Unexpected difference:"; diff -r /tmp/t/test /tmp/t/test2; exit 1; }
// rm -rf /tmp/t/test*
// rm /tmp/t/half
