package main

import (
	"context"
	"math"
	"net/url"
	"sort"
	"strings"
)

type forecastRecord struct {
	Hour   apiTime  `json:"HourUTC"`
	Zone   string   `json:"PriceArea"`
	Type   string   `json:"ForecastType"`
	Energy *float64 `json:"ForecastDayAhead"`
}

type renewableRecord struct {
	Timestamp int64             `json:"timestamp"`
	Sources   []renewableSource `json:"sources"`
}

func (r renewableRecord) UnixTimestamp() int64 { return r.Timestamp }

type renewableSource struct {
	Type   string  `json:"type"`
	Energy float64 `json:"energy"`
}

func (r forecastRecord) UnixTimestamp() int64 { return r.Hour.Unix() }
func (r forecastRecord) Identity() datasetKey {
	return datasetKey{Timestamp: r.UnixTimestamp(), Zone: r.Zone, Type: r.Type}
}

func downloadRenewables(ctx context.Context, conf downloadConfig) error {
	query := url.Values{
		"start":    {formatTimestamp(conf.From)},
		"end":      {formatTimestamp(conf.End)},
		"columns":  {"HourUTC,PriceArea,ForecastType,ForecastDayAhead"},
		"sort":     {"HourUTC asc,PriceArea asc,ForecastType asc"},
		"timezone": {"UTC"},
	}
	download := newDownloadSession(ctx)
	defer download.stop()
	page, err := fetch[forecastRecord](download, conf.Endpoint, "forecasts_hour", query)
	if err != nil {
		return err
	}
	allowed := make(map[string]bool, len(conf.Zones))
	for _, zone := range conf.Zones {
		allowed[strings.ToUpper(zone)] = true
	}
	groups := make(map[datasetKey]*renewableRecord)
	for _, record := range page {
		zone := strings.ToUpper(record.Zone)
		if !allowed[zone] {
			continue
		}
		stamp := record.Hour.Time
		key := datasetKey{Timestamp: stamp.Unix(), Zone: zone}
		group := groups[key]
		if group == nil {
			group = &renewableRecord{Timestamp: stamp.Unix(), Sources: []renewableSource{}}
			groups[key] = group
		}
		energy := 0.0
		if record.Energy != nil {
			energy = math.Round(*record.Energy*100) / 100
		}
		group.Sources = append(group.Sources, renewableSource{Type: strings.ToLower(record.Type), Energy: energy})
	}
	byZone := make(map[string][]renewableRecord)
	for key, record := range groups {
		sort.Slice(record.Sources, func(i, j int) bool { return record.Sources[i].Type < record.Sources[j].Type })
		byZone[key.Zone] = append(byZone[key.Zone], *record)
	}
	for zone, records := range byZone {
		if err := writeDaily(conf.Output, zone+".json", records); err != nil {
			return err
		}
	}
	return nil
}
