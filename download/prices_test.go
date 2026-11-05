package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"testing"
	"time"

	"github.com/go-openapi/testify/v2/assert"
)

func TestDownloadPricesProducesLegacyHourlyOutput(t *testing.T) {
	data, err := os.ReadFile("testdata/dataset-elspotprices.json.raw")
	if err != nil {
		t.Fatal(err)
	}
	var records datasetResponse[spotRecord]
	if err := json.Unmarshal(data, &records); err != nil {
		t.Fatal(err)
	}
	records.Total = len(records.Records)
	data, err = json.Marshal(records)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("limit") != "0" {
			t.Errorf("limit = %s", r.URL.Query().Get("limit"))
		}
		_, _ = w.Write(data)
	}))
	defer server.Close()
	root := t.TempDir()
	err = downloadPrices(t.Context(), downloadConfig{Endpoint: server.URL, Output: root, Zones: []string{"DK1"}, From: 1658163600, End: 1658181600, V2Date: 2000000000})
	if err != nil {
		t.Fatal(err)
	}
	actual, err := os.ReadFile(filepath.Join(root, "2022/07/18/DK1.json"))
	if err != nil {
		t.Fatal(err)
	}
	expected, err := os.ReadFile("testdata/expected-elspotprices.json.raw")
	if err != nil {
		t.Fatal(err)
	}
	var got, want []PriceRecord
	if err := json.Unmarshal(actual, &got); err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(expected, &want); err != nil {
		t.Fatal(err)
	}
	slices.Reverse(want)
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("actual %+v\nexpected ascending %+v", got, want)
	}
	if len(got) > 1 && got[0].Timestamp >= got[len(got)-1].Timestamp {
		t.Fatalf("price output is not ascending: %+v", got)
	}
}

func TestDayAheadKeepsFinalQuarterButOmitsIncompleteHour(t *testing.T) {
	data, err := os.ReadFile("testdata/dataset-dayaheadprices.json.raw")
	if err != nil {
		t.Fatal(err)
	}
	var body datasetResponse[dayAheadRecord]
	if err := json.Unmarshal(data, &body); err != nil {
		t.Fatal(err)
	}
	body.Total = len(body.Records)
	data, err = json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write(data) }))
	defer server.Close()
	root := t.TempDir()
	err = downloadPrices(t.Context(), downloadConfig{
		Endpoint: server.URL,
		Output:   root,
		Zones:    []string{"DK1"},
		From:     1658163600,
		End:      1658181600,
		V2Date:   1,
	})
	if err != nil {
		t.Fatal(err)
	}
	var quarters, hours []PriceRecord
	quarterPath := filepath.Join(root, "v2/2022/07/18/DK1/index.json")
	data, err = os.ReadFile(quarterPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(data, &quarters); err != nil {
		t.Fatal(err)
	}
	hourPath := filepath.Join(root, "2022/07/18/DK1.json")
	data, err = os.ReadFile(hourPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(data, &hours); err != nil {
		t.Fatal(err)
	}
	lastQuarter := false
	for _, record := range quarters {
		lastQuarter = lastQuarter || record.Timestamp == 1658178000
	}
	if !lastQuarter {
		t.Fatalf("final quarter-hour was not preserved: %+v", quarters)
	}
	lastCompleteHour := false
	for _, record := range hours {
		if record.Timestamp == 1658178000 {
			t.Fatalf("incomplete 21:00 hour was written: %+v", hours)
		}
		lastCompleteHour = lastCompleteHour || record.Timestamp == 1658174400
	}
	if !lastCompleteHour {
		t.Fatalf("last complete hour missing: %+v", hours)
	}
}

func TestPartialPriceHourIsWithheldWithoutDroppingCompletedHour(t *testing.T) {
	records := []PriceRecord{
		{Timestamp: 0, Euro: 10},
		{Timestamp: 900, Euro: 20},
		{Timestamp: 1800, Euro: 30},
		{Timestamp: 2700, Euro: 40},
		{Timestamp: 3600, Euro: 50},
	}
	got := quartersInCompleteHours(records)
	if len(got) != 4 || got[0].Timestamp != 0 || got[3].Timestamp != 2700 {
		t.Fatalf("completed records = %+v", got)
	}
	hours := averagePrices(got, time.Hour)
	if len(hours) != 1 || hours[0].Euro != 25 {
		t.Fatalf("hourly records = %+v", hours)
	}
	duplicates := []PriceRecord{
		{Timestamp: 0}, {Timestamp: 0}, {Timestamp: 900}, {Timestamp: 1800},
	}
	if got := quartersInCompleteHours(duplicates); len(got) != 0 {
		t.Fatalf("duplicate quarter-hour completed an incomplete hour: %+v", got)
	}
}

func TestPartialPriceHourUsesLastObservedTimestampAfterTimestampTrim(t *testing.T) {
	records := []PriceRecord{
		{Timestamp: 0, Euro: 10}, {Timestamp: 900, Euro: 10}, {Timestamp: 1800, Euro: 10}, {Timestamp: 2700, Euro: 10},
		{Timestamp: 3600, Euro: 20}, {Timestamp: 3600, Euro: 21},
	}
	safe := completePrefix(records)
	got := quartersInCompleteHours(safe)
	if len(got) != 4 || got[0].Timestamp != 0 {
		t.Fatalf("completed records after timestamp trim = %+v", got)
	}
}

func TestIncompleteOldPricePartitionStopsBeforeDayAheadPrices(t *testing.T) {
	var dayAheadRequests int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/dataset/DayAheadPrices" {
			dayAheadRequests++
			return
		}
		if r.URL.Query().Get("limit") == "0" {
			fmt.Fprint(w, `{"total":3,"records":[{"HourUTC":"2022-07-18T09:00:00","PriceArea":"DK1","SpotPriceEUR":12},{"HourUTC":"2022-07-18T10:00:00","PriceArea":"DK1","SpotPriceEUR":24}]}`)
			return
		}
		w.Header().Set("Retry-After", "300")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer server.Close()
	root := t.TempDir()

	ctx, cancel := context.WithTimeout(t.Context(), time.Second)
	defer cancel()

	err := downloadPrices(ctx, downloadConfig{
		Endpoint: server.URL,
		Output:   root,
		Zones:    []string{"DK1"},
		From:     1658134800,
		End:      1658180000,
		V2Date:   1658140000,
	})
	if err != nil {
		t.Fatal(err)
	}
	if dayAheadRequests != 0 {
		t.Fatalf("made %d DayAheadPrices requests after incomplete older partition", dayAheadRequests)
	}
	data, err := os.ReadFile(filepath.Join(root, "2022/07/18/DK1.json"))
	if err != nil {
		t.Fatal(err)
	}
	var got []PriceRecord
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 || got[0].Timestamp != 1658134800 {
		t.Fatalf("safe hourly prefix = %+v", got)
	}
}

func TestPricePartitionsSplitAtVersionDate(t *testing.T) {
	parts := pricePartitions(downloadConfig{From: 10, End: 30, V2Date: 20})
	if len(parts) != 2 || parts[0].from != 10 || parts[0].end != 20 || parts[0].versionTwo || parts[1].from != 20 || parts[1].end != 30 || !parts[1].versionTwo {
		t.Fatalf("partitions = %+v", parts)
	}
}

func TestExistingValuesWinTimestampCollisions(t *testing.T) {
	root := t.TempDir()
	path := filepath.Join(root, "2022/07/17/DK1.json")
	if err := writeFile(path, []PriceRecord{{Euro: 12, Timestamp: 1658091600}}); err != nil {
		t.Fatal(err)
	}
	if err := writeDaily(root, "DK1.json", []PriceRecord{{Euro: 99, Timestamp: 1658091600}}); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var got []PriceRecord
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 || got[0].Euro != 12 {
		t.Fatalf("merged values = %+v", got)
	}
}

func Test429WaitUsesResponseHint(t *testing.T) {
	if got, err := retryDelay("2"); got != 2*time.Second || err != nil {
		t.Fatalf("Retry-After delay = %s, err = %s", got, err)
	}
	date := time.Now().Add(30 * time.Second).UTC().Format(http.TimeFormat)
	if got, err := retryDelay(date); got < 29*time.Second || got > 30*time.Second || err != nil {
		t.Fatalf("Retry-After date delay = %s, err = %s", got, err)
	}
	_, err := retryDelay("")
	assert.NotNil(t, err)
}

func TestFetchStopsAfterInitialRequestAndThreeRetries(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls++
		w.Header().Set("Retry-After", "0")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer server.Close()
	download := newDownloadSession(t.Context())
	defer download.stop()
	records, err := fetch[spotRecord](download, server.URL, "elspotprices", nil)
	if err != nil || len(records) != 0 || calls != maxRetries+1 {
		t.Fatalf("records %v, calls %d, err %v", records, calls, err)
	}
}

func TestMissingRetryAfterIsNotRecoveredFromBody(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls++
		w.WriteHeader(http.StatusTooManyRequests)
		fmt.Fprint(w, `{"message":"Try again in 0 seconds"}`)
	}))
	defer server.Close()
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()
	download := newDownloadSession(ctx)
	defer download.stop()
	records, err := fetch[spotRecord](download, server.URL, "elspotprices", nil)
	if err == nil || len(records) != 0 || calls != 1 {
		t.Fatalf("records %v, calls %d, err %v", records, calls, err)
	}
}

func TestFetchStopsWhenBudgetExpiresDuringBodyRead(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(t.Context(), 20*time.Millisecond)
	defer cancel()
	download := newDownloadSession(ctx)
	defer download.stop()
	records, err := fetch[spotRecord](download, server.URL, "elspotprices", nil)
	if err != nil || len(records) != 0 {
		t.Fatalf("records %v, err %v", records, err)
	}
}

func TestRequestTimeoutIsAnErrorWhileBudgetRemains(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		<-r.Context().Done()
	}))
	defer server.Close()
	download := newDownloadSession(t.Context())
	defer download.stop()
	download.client.Timeout = 20 * time.Millisecond
	_, err := fetch[spotRecord](download, server.URL, "elspotprices", nil)
	if err == nil {
		t.Fatal("expected the per-request timeout to be an error")
	}
}

func TestNon429HTTPFailureIsAnError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "bad")
	}))
	defer server.Close()
	download := newDownloadSession(t.Context())
	defer download.stop()
	_, err := fetch[spotRecord](download, server.URL, "elspotprices", nil)
	if err == nil {
		t.Fatal("expected HTTP error")
	}
}

func TestInvalidJSONIsAnError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, "not json")
	}))
	defer server.Close()
	download := newDownloadSession(t.Context())
	defer download.stop()
	_, err := fetch[spotRecord](download, server.URL, "elspotprices", nil)
	if err == nil {
		t.Fatal("expected a JSON decoding error")
	}
}
