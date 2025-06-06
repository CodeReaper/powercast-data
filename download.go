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
		conf Configuration
		err  error
	)

	flag.StringVar(&conf.Zone, "zone", "", "Price Area like DK1")
	flag.StringVar(&conf.Output, "output", "", "Directory to place output into")
	flag.StringVar(&conf.Endpoint, "endpoint", "https://api.energidataservice.dk/", "Endpoint to fetch from")
	flag.Int64Var(&conf.V2Date, "v2date", 1759183200, "Date when day-a-head prices take effect") // 2025-09-30T00:00:00+02:00
	flag.Int64Var(&conf.From, "from", 0, "Unix timestamp of period start")
	flag.Int64Var(&conf.End, "end", 0, "Unix timestamp of period end")
	flag.IntVar(&conf.Limit, "limit", 100, "Limit to use per page in results")
	flag.IntVar(&conf.SleepInterval, "sleep-interval", 1000, "Milliseconds to sleep when API is throttling")

	flag.Parse()
	err = conf.Validate()
	if err != nil {
		log.Fatal(err)
	}

	err = run(conf)
	if err != nil {
		log.Fatal(err)
	}
}

func run(f Configuration) error {
	var (
		partitions []Configuration
		records    []Record
		err        error
	)

	partitions, err = f.Partitions()
	if err != nil {
		return err
	}

	for _, p := range partitions {
		records, err = fetchRecords(p.Endpoint, p.Zone, p.From, p.End, p.Limit, p.SleepInterval, p.apiVersion)
		if err != nil {
			return err
		}

		err = saveRecords(p.Zone, records, p.Output, p.apiVersion)
		if err != nil {
			return err
		}
	}

	return nil
}

func saveRecords(zone string, records []Record, output string, version ApiVersion) error {
	var (
		date, file string
		err        error
		ok         bool
		outputs    = make(map[string][]Record)
		record     Record
		updated    []Record
	)

	for _, record = range records { // FIXME: add v2 handling and v1 calculations
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

func fetchRecords(endpoint string, zone string, from int64, end int64, limit int, sleep int, version ApiVersion) ([]Record, error) {
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
		req, err = buildRequest(endpoint, zone, from, end, limit, version)
		if err != nil {
			return records, err
		}

		bytes, err = performRequest(req, sleep)
		if err != nil {
			return records, err
		}

		switch version {
		case ApiV1:
			items, err = parseBodyV1(bytes)
			if err != nil {
				return records, err
			}
		case ApiV2:
			items, err = parseBodyV2(bytes)
			if err != nil {
				return records, err
			}
		default:
			return records, errParsing
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

func buildRequest(endpoint string, zone string, from int64, end int64, limit int, version ApiVersion) (string, error) {
	var (
		params = url.Values{}
		uri    *url.URL
		err    error
	)

	uri, err = url.Parse(endpoint)
	if err != nil {
		return "", errors.Join(errParseEndpoint, err)
	}

	switch version {
	case ApiV1:
		uri.Path += "dataset/elspotprices"
		params.Add("columns", "HourUTC,PriceArea,SpotPriceEUR")
		params.Add("sort", "HourUTC asc")
	case ApiV2:
		uri.Path += "dataset/DayAheadPrices"
		params.Add("columns", "TimeUTC,PriceArea,DayAheadPriceEUR")
		params.Add("sort", "TimeUTC desc")
	}

	params.Add("end", time.Unix(end, 0).Format("2006-01-02T15:04"))
	params.Add("filter", fmt.Sprintf(`{"PriceArea":"%s"}`, zone))
	params.Add("limit", strconv.Itoa(limit))
	params.Add("start", time.Unix(from, 0).Format("2006-01-02T15:04"))
	params.Add("timezone", "UTC")

	uri.RawQuery = params.Encode()

	return uri.String(), nil
}

func performRequest(req string, sleep int) ([]byte, error) {
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
		time.Sleep(time.Duration(sleep) * time.Millisecond)
	}

	return bytes, nil
}

func parseBodyV1(body []byte) ([]Record, error) {
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

func parseBodyV2(body []byte) ([]Record, error) {
	var (
		records = make([]Record, 0)
		err     error
		item    DayAHeadRecord
		stamp   time.Time
		items   DayAHeadRecords
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

type ApiVersion int

const (
	ApiV1 ApiVersion = iota
	ApiV2
)

type Configuration struct {
	Zone, Output, Endpoint string
	From, End, V2Date      int64
	Limit, SleepInterval   int
	apiVersion             ApiVersion
}

func (f *Configuration) Validate() error {
	if len(f.Zone) == 0 || len(f.Output) == 0 || f.From == 0 || f.End == 0 {
		return fmt.Errorf("missing flag, provided flags: %s", os.Args[1:])
	}

	return nil
}

func (c *Configuration) Partitions() ([]Configuration, error) {
	var (
		parts = make([]Configuration, 0)
		from  = c.From
		end   = c.End
		tmp   int64
	)

	for from < end {
		copy := *c

		if from < c.V2Date {
			copy.apiVersion = ApiV1
			tmp = min(c.End, c.V2Date)
		} else {
			copy.apiVersion = ApiV2
			tmp = c.End
		}

		copy.From = from
		copy.End = tmp

		parts = append(parts, copy)

		from = tmp
	}

	sort.Slice(parts, func(i, j int) bool {
		return parts[i].End < parts[j].End
	})

	return parts, nil
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

type DayAHeadRecords struct {
	Records []DayAHeadRecord `json:"records"`
}

type DayAHeadRecord struct {
	Euro      float32 `json:"DayAheadPriceEUR"`
	Timestamp string  `json:"TimeUTC"`
}
