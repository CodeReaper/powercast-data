package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"time"
)

const endpoint = `https://api.energidataservice.dk/`

var (
	errConvert       = errors.New("failed to convert data")
	errDecode        = errors.New("failed to decode data")
	errEncode        = errors.New("failed to encode data")
	errFetching      = errors.New("failed to fetch data")
	errParseEndpoint = errors.New("failed to parse endpoint uri")
	errParsing       = errors.New("failed to parse data")
	errReading       = errors.New("failed to read data")
	errWrite         = errors.New("failed to write data")
)

func main() {
	var (
		zone, output string
		from, end    int64
		limit        int
		records      []Record
		err          error
	)

	flag.StringVar(&zone, "zone", "", "Price Area like DK1")
	flag.StringVar(&output, "output", "", "Directory to place output into")
	flag.Int64Var(&from, "from", 0, "Unix timestamp of period start")
	flag.Int64Var(&end, "end", 0, "Unix timestamp of period end")
	flag.IntVar(&limit, "limit", 100, "Limit to use per page in results")

	flag.Parse()
	if len(zone) == 0 || len(output) == 0 || from == 0 || end == 0 {
		log.Fatalf("Missing flag, provided flags: %s", os.Args[1:])
	}

	records, err = fetchRecords(endpoint, zone, from, end, limit)
	if err != nil {
		log.Fatal(err)
	}

	err = saveRecords(zone, records, output)
	if err != nil {
		log.Fatal(err)
	}
}

func saveRecords(zone string, records []Record, output string) error {
	var (
		date, file string
		err        error
		ok         bool
		outputs    = make(map[string][]Record)
		record     Record
		updated    []Record
	)

	for _, record = range records {
		date = time.Unix(record.Timestamp, 0).Format("2006/01/02")
		file = filepath.Join(output, date, fmt.Sprintf("%s.json", zone))
		if _, ok = outputs[file]; !ok {
			outputs[file] = make([]Record, 0)
		}
		outputs[file] = append(outputs[file], record)
	}

	for file = range outputs {
		updated, err = updateOutput(file, outputs[file])
		if err != nil {
			return err
		}

		err = saveOutput(file, updated)
		if err != nil {
			return err
		}
	}

	return nil
}

func saveOutput(file string, records []Record) error {
	var (
		err   error
		bytes []byte
	)

	sort.Slice(records, func(i, j int) bool {
		return records[i].Timestamp > records[j].Timestamp
	})

	err = os.MkdirAll(filepath.Dir(file), 0770)
	if err != nil {
		return nil
	}

	bytes, err = json.MarshalIndent(records, "", "  ")
	if err != nil {
		return errors.Join(errEncode, err)
	}
	bytes = append(bytes, 0x0a)

	err = os.WriteFile(file, bytes, 0550)
	if err != nil {
		return errors.Join(errWrite, err)
	}

	return nil
}

func updateOutput(file string, records []Record) ([]Record, error) {
	var (
		tmp     = make([]Record, 0)
		updated = make([]Record, 0)
		data    = make(map[int64]Record)
		item    Record
		err     error
		bytes   []byte
	)

	for _, item = range records {
		data[item.Timestamp] = item
	}

	bytes, err = os.ReadFile(file)
	if err != nil {
		return records, nil
	}

	err = json.Unmarshal(bytes, &tmp)
	if err != nil {
		return updated, errors.Join(errDecode, err)
	}

	for _, item = range tmp {
		data[item.Timestamp] = item
	}

	for _, item = range data {
		updated = append(updated, item)
	}

	return updated, nil
}

func fetchRecords(endpoint string, zone string, from int64, end int64, limit int) ([]Record, error) {
	var (
		data    = make(map[int64]Record)
		records = make([]Record, 0)
		req     string
		bytes   []byte
		err     error
		items   []Record
		item    Record
		size    int
		key     int64
	)

	for from < end {
		req, err = buildRequest(endpoint, zone, from, end, limit)
		if err != nil {
			return records, err
		}

		bytes, err = performRequest(req)
		if err != nil {
			return records, err
		}

		items, err = parseBody(bytes)
		if err != nil {
			return records, err
		}

		size = len(data)
		for _, item = range items {
			data[item.Timestamp] = item
		}

		if len(data) == size {
			break
		}

		for key = range data {
			if key > from {
				from = key
			}
		}
	}

	for _, item = range data {
		records = append(records, item)
	}

	return records, nil
}

func buildRequest(endpoint string, zone string, from int64, end int64, limit int) (string, error) {
	var (
		s      string
		params = url.Values{}
		uri    *url.URL
		err    error
	)

	uri, err = url.Parse(endpoint)
	if err != nil {
		return s, errors.Join(errParseEndpoint, err)
	}

	// uri.Path += "dataset/DayAheadPrices"
	uri.Path += "dataset/elspotprices"

	// params.Add("columns", "TimeUTC,PriceArea,DayAheadPriceEUR")
	params.Add("columns", "HourUTC,PriceArea,SpotPriceEUR")
	params.Add("end", time.Unix(end, 0).Format("2006-01-02T15:04"))
	// params.Add("filter", url.QueryEscape(fmt.Sprintf(`{"PriceArea":"%s"}`, zone)))
	params.Add("filter", fmt.Sprintf(`{"PriceArea":"%s"}`, zone))
	params.Add("limit", strconv.Itoa(limit))
	// params.Add("sort", "TimeUTC desc")
	params.Add("sort", "HourUTC asc")
	params.Add("start", time.Unix(from, 0).Format("2006-01-02T15:04"))
	params.Add("timezone", "UTC")

	uri.RawQuery = params.Encode()

	return uri.String(), nil
}

func performRequest(req string) ([]byte, error) {
	var (
		bytes     = make([]byte, 0)
		res       *http.Response
		remainder int
		err       error
	)

	os.Stderr.WriteString(fmt.Sprintf("Fetching: %s\n", req))
	res, err = http.Get(req)
	if err != nil {
		return bytes, errors.Join(errFetching, err)
	}

	bytes, err = io.ReadAll(res.Body)
	res.Body.Close()
	if res.StatusCode > 299 {
		return bytes, fmt.Errorf("response failed with status code: %d and body length: %d", res.StatusCode, len(bytes))
	}
	if err != nil {
		return bytes, errors.Join(errReading, err)
	}

	remainder, _ = strconv.Atoi(res.Header.Get("remainingcalls"))
	if remainder > 0 && remainder < 20 {
		time.Sleep(1 * time.Second)
	}

	return bytes, nil
}

func parseBody(body []byte) ([]Record, error) {
	var (
		records = make([]Record, 0)
		err     error
		item    SpotRecord
		stamp   time.Time
		items   SpotRecords
	)

	if err = json.Unmarshal(body, &items); err != nil {
		return records, errors.Join(errParsing, err)
	}

	for _, item = range items.Records {
		stamp, err = time.Parse("2006-01-02T15:04:05", item.Timestamp)
		if err != nil {
			return records, errors.Join(errConvert, err)
		}
		records = append(records, Record{Euro: item.Euro, Timestamp: stamp.Unix()})
	}

	return records, nil
}

type Record struct {
	Euro      float32 `json:"euro"`
	Timestamp int64   `json:"timestamp"`
}

type SpotRecords struct {
	Records []SpotRecord `json:"records"`
}

type SpotRecord struct {
	Euro      float32 `json:"SpotPriceEUR"`
	Timestamp string  `json:"HourUTC"`
}

// go run download.go --zone DK1 --from 1685577600 --end 1685588400 --output /tmp/ --limit 2
