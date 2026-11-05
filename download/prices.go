package main

import (
	"context"
	"net/url"
	"path/filepath"
	"sort"
	"time"
)

type downloadConfig struct {
	Endpoint string
	Output   string
	Zones    []string
	From     int64
	End      int64
	V2Date   int64
}

type PriceRecord struct {
	Euro      float32 `json:"euro"`
	Timestamp int64   `json:"timestamp"`
	Zone      string  `json:"zone,omitempty"`
}

func (r PriceRecord) UnixTimestamp() int64 { return r.Timestamp }

type spotRecord struct {
	Hour  apiTime `json:"HourUTC"`
	Zone  string  `json:"PriceArea"`
	Price float32 `json:"SpotPriceEUR"`
}

func (r spotRecord) UnixTimestamp() int64 { return r.Hour.Unix() }
func (r spotRecord) Identity() datasetKey {
	return datasetKey{Timestamp: r.UnixTimestamp(), Zone: r.Zone}
}

type dayAheadRecord struct {
	Time  apiTime `json:"TimeUTC"`
	Zone  string  `json:"PriceArea"`
	Price float32 `json:"DayAheadPriceEUR"`
}

func (r dayAheadRecord) UnixTimestamp() int64 { return r.Time.Unix() }
func (r dayAheadRecord) Identity() datasetKey {
	return datasetKey{Timestamp: r.UnixTimestamp(), Zone: r.Zone}
}

func downloadPrices(ctx context.Context, conf downloadConfig) error {
	download := newDownloadSession(ctx)
	defer download.stop()
	for _, part := range pricePartitions(conf) {
		var records []PriceRecord
		var err error
		if part.versionTwo {
			records, err = fetchDayAhead(download, conf, part)
		} else {
			records, err = fetchSpot(download, conf, part)
		}
		if err != nil {
			return err
		}
		if err := writePrices(conf.Output, conf.Zones, records, part.versionTwo); err != nil {
			return err
		}
		if download.ctx.Err() != nil {
			break
		}
	}
	return nil
}

type pricePartition struct {
	from       int64
	end        int64
	versionTwo bool
}

// pricePartitions divides [conf.From, conf.End) between legacy prices before
// V2Date and version-two prices from V2Date onward. Partitions are returned
// oldest first and do not overlap.
func pricePartitions(conf downloadConfig) []pricePartition {
	parts := make([]pricePartition, 0, 2)
	if conf.From < conf.V2Date {
		end := min(conf.End, conf.V2Date)
		parts = append(parts, pricePartition{from: conf.From, end: end})
	}
	if conf.End > conf.V2Date {
		parts = append(parts, pricePartition{from: max(conf.From, conf.V2Date), end: conf.End, versionTwo: true})
	}
	return parts
}

func fetchSpot(download *downloadSession, conf downloadConfig, part pricePartition) ([]PriceRecord, error) {
	query := priceQuery(part, "HourUTC,PriceArea,SpotPriceEUR", "HourUTC")
	result, err := fetch[spotRecord](download, conf.Endpoint, "elspotprices", query)

	if err != nil {
		return nil, err
	}
	prices := make([]PriceRecord, 0, len(result))
	for _, record := range result {
		prices = append(prices, PriceRecord{Timestamp: record.Hour.Unix(), Euro: record.Price, Zone: record.Zone})
	}
	return prices, nil
}

func fetchDayAhead(download *downloadSession, conf downloadConfig, part pricePartition) ([]PriceRecord, error) {
	query := priceQuery(part, "TimeUTC,PriceArea,DayAheadPriceEUR", "TimeUTC")
	result, err := fetch[dayAheadRecord](download, conf.Endpoint, "DayAheadPrices", query)
	if err != nil {
		return nil, err
	}
	prices := make([]PriceRecord, 0, len(result))
	for _, record := range result {
		prices = append(prices, PriceRecord{Timestamp: record.Time.Unix(), Euro: record.Price, Zone: record.Zone})
	}
	return prices, nil
}

// priceQuery builds a UTC price query for part, ordered by the supplied
// timestamp field and then price area, both ascending. Time bounds are
// truncated to minute precision.
func priceQuery(part pricePartition, columns, timestamp string) url.Values {
	return url.Values{
		"start":    {formatTimestamp(part.from)},
		"end":      {formatTimestamp(part.end)},
		"columns":  {columns},
		"sort":     {timestamp + " asc,PriceArea asc"},
		"timezone": {"UTC"},
	}
}

func formatTimestamp(value int64) string {
	return time.Unix(value, 0).UTC().Format("2006-01-02T15:04")
}

// writePrices merges hourly prices for the requested zones into daily files.
// Version two also writes quarter-hour prices under root/v2; only complete
// hours contribute to its hourly averages. Quarter-hours from incomplete hours
// are still written.
func writePrices(root string, zones []string, records []PriceRecord, versionTwo bool) error {
	allowed := make(map[string]bool, len(zones))
	for _, zone := range zones {
		allowed[zone] = true
	}
	byZone := make(map[string][]PriceRecord)
	for _, record := range records {
		if allowed[record.Zone] {
			byZone[record.Zone] = append(byZone[record.Zone], PriceRecord{Timestamp: record.Timestamp, Euro: record.Euro})
		}
	}
	for zone, prices := range byZone {
		if versionTwo {
			quarterHours := averagePrices(prices, 15*time.Minute)
			if err := writeDaily(root+"/v2", filepath.Join(zone, "index.json"), quarterHours); err != nil {
				return err
			}
			completeHours := quartersInCompleteHours(prices)
			hours := averagePrices(completeHours, time.Hour)
			if err := writeDaily(root, zone+".json", hours); err != nil {
				return err
			}
			continue
		}
		hours := averagePrices(prices, time.Hour)
		if err := writeDaily(root, zone+".json", hours); err != nil {
			return err
		}
	}
	return nil
}

// quartersInCompleteHours keeps records from hours containing exactly the
// distinct UTC positions :00, :15, :30, and :45. Records must belong to one zone.
// It preserves input order and duplicates; it neither averages nor deduplicates.
func quartersInCompleteHours(records []PriceRecord) []PriceRecord {
	quarters := make(map[int64]map[int64]bool)
	for _, record := range records {
		hour := time.Unix(record.Timestamp, 0).UTC().Truncate(time.Hour).Unix()
		if quarters[hour] == nil {
			quarters[hour] = make(map[int64]bool)
		}
		quarters[hour][record.Timestamp-hour] = true
	}
	complete := make([]PriceRecord, 0, len(records))
	for _, record := range records {
		hour := time.Unix(record.Timestamp, 0).UTC().Truncate(time.Hour).Unix()
		positions := quarters[hour]
		if len(positions) == 4 && positions[0] && positions[900] && positions[1800] && positions[2700] {
			complete = append(complete, record)
		}
	}
	return complete
}

// averagePrices averages all records in each UTC-aligned interval and returns
// the bucket starts in descending order, without zone information.
// Records must belong to one zone, and interval must be positive.
// Duplicates count toward the mean; incomplete intervals are not excluded.
func averagePrices(records []PriceRecord, interval time.Duration) []PriceRecord {
	averages := make(map[int64][]float32)
	for _, record := range records {
		timestamp := time.Unix(record.Timestamp, 0).UTC().Truncate(interval).Unix()
		averages[timestamp] = append(averages[timestamp], record.Euro)
	}
	result := make([]PriceRecord, 0, len(averages))
	for timestamp, prices := range averages {
		var total float32
		for _, price := range prices {
			total += price
		}
		result = append(result, PriceRecord{Timestamp: timestamp, Euro: total / float32(len(prices))})
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Timestamp > result[j].Timestamp })
	return result
}
