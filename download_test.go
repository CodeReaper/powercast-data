package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestThatKnownDataProducesExpectedRecords(t *testing.T) {
	svr := setupServerWith(t, "testdata/dataset-elspotprices.json.raw")
	defer svr.Close()

	records, err := fetchRecords(svr.URL, "", 0, 1, 1, 1000, ApiV1)
	assert.Nil(t, err)

	assert.Equal(t, 5, len(records))
}

func TestThatKnownDataProducesExpectedOutputFilesAndRecords(t *testing.T) {
	expected, err := os.ReadFile("testdata/expected-elspotprices.json.raw")
	assert.Nil(t, err)

	svr := setupServerWith(t, "testdata/dataset-elspotprices.json.raw")
	defer svr.Close()

	output, err := os.MkdirTemp("", "test")
	assert.Nil(t, err)

	records, err := fetchRecords(svr.URL, "", 0, 1, 1, 1000, ApiV1)
	assert.Nil(t, err)

	err = saveRecords("DK1", records, output, ApiV1)
	assert.Nil(t, err)

	bytes, err := os.ReadFile(filepath.Join(output, "2022/07/18/DK1.json"))
	assert.Nil(t, err)

	assert.Equal(t, expected, bytes)
}

func TestThatKnownDataProducesExpectedOutputFiles(t *testing.T) {
	expected, err := os.ReadFile("testdata/expected-elspotprices.json.raw")
	assert.Nil(t, err)

	svr := setupServerWith(t, "testdata/dataset-elspotprices.json.raw")
	defer svr.Close()

	output, err := os.MkdirTemp("", "test")
	assert.Nil(t, err)

	conf := Configuration{Endpoint: svr.URL, Zone: "DK1", End: 1, Limit: 1, Output: output}
	err = run(conf)
	assert.Nil(t, err)

	bytes, err := os.ReadFile(filepath.Join(output, "2022/07/18/DK1.json"))
	assert.Nil(t, err)

	assert.Equal(t, expected, bytes)
}

func TestThatExistingOutputFileValuesAreUpdatedCorrectly(t *testing.T) {
	expected, err := os.ReadFile("testdata/expected-elspotprices.json.raw")
	assert.Nil(t, err)

	svr := setupServerWith(t, "testdata/dataset-elspotprices-zeroed.json.raw")
	defer svr.Close()

	output, err := os.MkdirTemp("", "test")
	assert.Nil(t, err)

	err = os.MkdirAll(filepath.Join(output, "2022/07/18/"), 0770)
	assert.Nil(t, err)
	os.WriteFile(filepath.Join(output, "2022/07/18/DK1.json"), expected, 0770)
	assert.Nil(t, err)

	conf := Configuration{Endpoint: svr.URL, Zone: "DK1", End: 1, Limit: 1, Output: output}
	err = run(conf)
	assert.Nil(t, err)

	bytes, err := os.ReadFile(filepath.Join(output, "2022/07/18/DK1.json"))
	assert.Nil(t, err)

	assert.Equal(t, expected, bytes)
}

func TestThatExistingOutputFilesAreUpdatedCorrectly(t *testing.T) {
	expected, err := os.ReadFile("testdata/expected-elspotprices.json.raw")
	assert.Nil(t, err)

	half, err := os.ReadFile("testdata/expected-elspotprices-half.json.raw")
	assert.Nil(t, err)

	svr := setupServerWith(t, "testdata/dataset-elspotprices.json.raw")
	defer svr.Close()

	output, err := os.MkdirTemp("", "test")
	assert.Nil(t, err)

	err = os.MkdirAll(filepath.Join(output, "2022/07/18/"), 0770)
	assert.Nil(t, err)
	os.WriteFile(filepath.Join(output, "2022/07/18/DK1.json"), half, 0770)
	assert.Nil(t, err)

	conf := Configuration{Endpoint: svr.URL, Zone: "DK1", End: 1, Limit: 1, Output: output}
	err = run(conf)
	assert.Nil(t, err)

	bytes, err := os.ReadFile(filepath.Join(output, "2022/07/18/DK1.json"))
	assert.Nil(t, err)

	assert.Equal(t, expected, bytes)
}

func TestThatNoDataProducesExpectedRecords(t *testing.T) {
	svr := setupServerWith(t, "")
	defer svr.Close()

	records, err := fetchRecords(svr.URL, "", 0, 1, 1, 1000, ApiV1)
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

	records, err := fetchRecords(svr.URL, "", 0, 1, 1, 1000, ApiV1)
	assert.NotNil(t, err)

	assert.Equal(t, 0, len(records))
}

func TestThatApiHeaderLeadsToSleeping(t *testing.T) {
	svr := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Add("remainingcalls", "5")
		fmt.Fprint(w, "")
	}))
	defer svr.Close()

	start := time.Now()
	_, err := performRequest(svr.URL, 100)
	assert.Nil(t, err)

	elapsed := time.Since(start).Milliseconds()
	if elapsed < 100 {
		assert.Fail(t, "Did not do required sleep")
	}
}

func TestThatPartitionsAreMadeDividedCorrectly(t *testing.T) {
	conf := Configuration{
		From:   946684800, // 2000-01-01
		V2Date: 946771200, // 2000-01-02
		End:    946857600, // 2000-01-03
	}

	partitions, err := conf.Partitions()

	assert.Nil(t, err)
	if assert.Equal(t, 2, len(partitions)) {
		partA := partitions[0]
		partB := partitions[1]

		assert.Equal(t, conf.From, partA.From)
		assert.Equal(t, conf.V2Date, partA.End)
		assert.Equal(t, ApiV1, partA.apiVersion)

		assert.Equal(t, conf.V2Date, partB.From)
		assert.Equal(t, conf.End, partB.End)
		assert.Equal(t, ApiV2, partB.apiVersion)
	}
}

func setupServerWith(t *testing.T, file string) *httptest.Server {
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
