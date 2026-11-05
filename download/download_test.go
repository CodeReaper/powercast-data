package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

type testRecord struct {
	Time apiTime `json:"timestamp"`
	Zone string  `json:"zone"`
}

func (r testRecord) UnixTimestamp() int64 { return r.Time.Unix() }
func (r testRecord) Identity() datasetKey {
	return datasetKey{Timestamp: r.UnixTimestamp(), Zone: r.Zone}
}

func TestFetchContinuesInclusivelyAcrossTimestampGroups(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls == 1 {
			if r.URL.Query().Get("limit") != "0" {
				t.Errorf("initial limit = %s", r.URL.Query().Get("limit"))
			}
			fmt.Fprint(w, `{"total":4,"records":[{"timestamp":"1970-01-01T00:00:10","zone":"DK1"},{"timestamp":"1970-01-01T00:00:20","zone":"DK1"}]}`)
			return
		}
		if r.URL.Query().Get("start") != "1970-01-01T00:00" || r.URL.Query().Get("offset") != "0" {
			t.Errorf("continuation query = %s", r.URL.RawQuery)
		}
		fmt.Fprint(w, `{"total":3,"records":[{"timestamp":"1970-01-01T00:00:20","zone":"DK1"},{"timestamp":"1970-01-01T00:00:20","zone":"DK2"},{"timestamp":"1970-01-01T00:00:30","zone":"DK1"}]}`)
	}))
	defer server.Close()

	download := newDownloadSession(t.Context())
	defer download.stop()
	got, err := fetch[testRecord](download, server.URL, "example", url.Values{"start": {"1970-01-01T00:00"}})
	if err != nil {
		t.Fatal(err)
	}
	if calls != 2 || len(got) != 4 {
		t.Fatalf("got %+v after %d calls", got, calls)
	}
	if got[0].Time.Unix() != 10 || got[1].Zone != "DK1" || got[2].Zone != "DK2" || got[3].Time.Unix() != 30 {
		t.Fatalf("records = %+v", got)
	}
}

func TestFetch429ReturnsSafePrefixWithoutWaitingPastBudget(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls == 1 {
			fmt.Fprint(w, `{"total":3,"records":[{"timestamp":"2022-07-17T21:00:00","zone":"DK1"},{"timestamp":"2022-07-17T21:05:00","zone":"DK1"}]}`)
			return
		}
		w.Header().Set("Retry-After", "300")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(t.Context(), time.Second)
	defer cancel()
	download := newDownloadSession(ctx)
	defer download.stop()
	got, err := fetch[testRecord](download, server.URL, "example", url.Values{"start": {"2022-07-17T21:00"}})
	if err != nil {
		t.Fatal(err)
	}
	if calls != 2 || len(got) != 1 {
		t.Fatalf("got %+v after %d calls", got, calls)
	}
}

func TestFetchRetries429AndCompletes(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls++
		if calls < 3 {
			w.Header().Set("Retry-After", "0")
			w.WriteHeader(http.StatusTooManyRequests)
			return
		}
		fmt.Fprint(w, `{"total":0,"records":[]}`)
	}))
	defer server.Close()
	download := newDownloadSession(t.Context())
	defer download.stop()
	got, err := fetch[testRecord](download, server.URL, "example", url.Values{})
	if err != nil || calls != 3 || len(got) != 0 {
		t.Fatalf("got %+v after %d calls, err %v", got, calls, err)
	}
}

func TestTypedBackendRecordsRejectInvalidTimestamps(t *testing.T) {
	for _, input := range []string{
		`{"HourUTC":42,"PriceArea":"DK1","SpotPriceEUR":1}`,
		`{"HourUTC":"not-time","PriceArea":"DK1","SpotPriceEUR":1}`,
	} {
		var record spotRecord
		if err := json.Unmarshal([]byte(input), &record); err == nil {
			t.Fatalf("accepted %s", input)
		}
	}
	var nullable forecastRecord
	if err := json.Unmarshal([]byte(`{"HourUTC":"2022-07-17T21:00:00","ForecastDayAhead":null}`), &nullable); err != nil || nullable.Energy != nil {
		t.Fatalf("nullable forecast = %+v, err %v", nullable, err)
	}
}

func TestSuccessfulCommandHasNoMachineReadableOutput(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, `{"total":0,"records":[]}`)
	}))
	defer server.Close()
	reader, writer, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	stdout := os.Stdout
	os.Stdout = writer
	t.Cleanup(func() {
		os.Stdout = stdout
		_ = reader.Close()
		_ = writer.Close()
	})
	err = run([]string{"--dataset", "co2-emission", "--zones", "DK1", "--output", t.TempDir(), "--endpoint", server.URL, "--from", "1658091600", "--end", "1658095200"})
	os.Stdout = stdout
	if err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	output, err := io.ReadAll(reader)
	if err != nil {
		t.Fatal(err)
	}
	if len(output) != 0 {
		t.Fatalf("successful command output = %q", output)
	}
}

func TestRenewablesAndCO2MatchPublishedOutput(t *testing.T) {
	tests := []struct{ dataset, fixture, output string }{
		{"renewables", "forecasts_hour", "data-write-generated-renewables-output/2022/07/17/DK1.json"},
		{"co2-emission", "co2emisprog", "data-write-generated-co2-emission-output/2022/07/17/DK1.json"},
	}
	for _, test := range tests {
		t.Run(test.dataset, func(t *testing.T) {
			fixture, err := os.ReadFile(filepath.Join("..", "test/fixtures/endpoint-response", test.fixture))
			if err != nil {
				t.Fatal(err)
			}
			if test.dataset == "renewables" {
				var data datasetResponse[forecastRecord]
				if err := json.Unmarshal(fixture, &data); err != nil {
					t.Fatal(err)
				}
				data.Total = len(data.Records)
				fixture, err = json.Marshal(data)
			} else {
				var data datasetResponse[co2ResponseRecord]
				if err := json.Unmarshal(fixture, &data); err != nil {
					t.Fatal(err)
				}
				data.Total = len(data.Records)
				fixture, err = json.Marshal(data)
			}
			if err != nil {
				t.Fatal(err)
			}
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write(fixture) }))
			defer server.Close()
			root := t.TempDir()
			conf := downloadConfig{Endpoint: server.URL, Output: root, Zones: []string{"DK1"}, From: 1658091600, End: 1658361600}
			if test.dataset == "renewables" {
				err = downloadRenewables(t.Context(), conf)
			} else {
				err = downloadCO2(t.Context(), conf)
			}
			if err != nil {
				t.Fatal(err)
			}
			actual, err := os.ReadFile(filepath.Join(root, "2022/07/17/DK1.json"))
			if err != nil {
				t.Fatal(err)
			}
			expected, err := os.ReadFile(filepath.Join("..", "test/fixtures", test.output))
			if err != nil {
				t.Fatal(err)
			}
			if test.dataset == "renewables" {
				var got, want []renewableRecord
				if err := json.Unmarshal(actual, &got); err != nil {
					t.Fatal(err)
				}
				if err := json.Unmarshal(expected, &want); err != nil {
					t.Fatal(err)
				}
				if !reflect.DeepEqual(got, want) {
					t.Fatalf("output mismatch\nactual: %+v\nexpected: %+v", got, want)
				}
			} else {
				var got, want []co2Record
				if err := json.Unmarshal(actual, &got); err != nil {
					t.Fatal(err)
				}
				if err := json.Unmarshal(expected, &want); err != nil {
					t.Fatal(err)
				}
				if !reflect.DeepEqual(got, want) {
					t.Fatalf("output mismatch\nactual: %+v\nexpected: %+v", got, want)
				}
			}
		})
	}
}

func TestRenewablesGroupForecastTypesByTimestampAndZone(t *testing.T) {
	data := datasetResponse[forecastRecord]{
		Total: 3,
		Records: []forecastRecord{
			{Hour: apiTime{Time: mustParseAPITime(t, "2022-07-17T21:00:00")}, Zone: "DK1", Type: "Solar", Energy: floatPointer(12)},
			{Hour: apiTime{Time: mustParseAPITime(t, "2022-07-17T21:00:00")}, Zone: "DK1", Type: "Wind", Energy: floatPointer(34)},
			{Hour: apiTime{Time: mustParseAPITime(t, "2022-07-17T21:00:00")}, Zone: "DK2", Type: "Wind", Energy: floatPointer(56)},
		},
	}
	body, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(body)
	}))
	defer server.Close()
	root := t.TempDir()
	conf := downloadConfig{Endpoint: server.URL, Output: root, Zones: []string{"DK1", "DK2"}, From: 1658091600, End: 1658361600}
	if err := downloadRenewables(t.Context(), conf); err != nil {
		t.Fatal(err)
	}

	for zone, want := range map[string][]renewableSource{
		"DK1": {{Type: "solar", Energy: 12}, {Type: "wind", Energy: 34}},
		"DK2": {{Type: "wind", Energy: 56}},
	} {
		content, err := os.ReadFile(filepath.Join(root, "2022/07/17", zone+".json"))
		if err != nil {
			t.Fatal(err)
		}
		var records []renewableRecord
		if err := json.Unmarshal(content, &records); err != nil {
			t.Fatal(err)
		}
		if len(records) != 1 || !reflect.DeepEqual(records[0].Sources, want) {
			t.Errorf("%s records = %+v, want one record with sources %+v", zone, records, want)
		}
	}
}

func mustParseAPITime(t *testing.T, value string) time.Time {
	t.Helper()
	parsed, err := time.Parse("2006-01-02T15:04:05", value)
	if err != nil {
		t.Fatal(err)
	}
	return parsed.UTC()
}

func floatPointer(value float64) *float64 { return &value }
