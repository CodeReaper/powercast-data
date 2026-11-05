package main

import (
	"context"
	"net/url"
	"strings"
)

type co2Record struct {
	Timestamp int64    `json:"timestamp"`
	CO2       *float64 `json:"co2"`
}

func (r co2Record) UnixTimestamp() int64 { return r.Timestamp }

type co2ResponseRecord struct {
	Minute   apiTime  `json:"Minutes5UTC"`
	Zone     string   `json:"PriceArea"`
	Emission *float64 `json:"CO2Emission"`
}

func (r co2ResponseRecord) UnixTimestamp() int64 { return r.Minute.Unix() }
func (r co2ResponseRecord) Identity() datasetKey {
	return datasetKey{Timestamp: r.UnixTimestamp(), Zone: r.Zone}
}

func downloadCO2(ctx context.Context, conf downloadConfig) error {
	query := url.Values{
		"start":    {formatTimestamp(conf.From)},
		"end":      {formatTimestamp(conf.End)},
		"columns":  {"Minutes5UTC,PriceArea,CO2Emission"},
		"sort":     {"Minutes5UTC asc,PriceArea asc"},
		"timezone": {"UTC"},
	}
	download := newDownloadSession(ctx)
	defer download.stop()
	page, err := fetch[co2ResponseRecord](download, conf.Endpoint, "co2emisprog", query)
	if err != nil {
		return err
	}
	allowed := make(map[string]bool, len(conf.Zones))
	for _, zone := range conf.Zones {
		allowed[strings.ToUpper(zone)] = true
	}
	byZone := make(map[string][]co2Record)
	for _, record := range page {
		zone := strings.ToUpper(record.Zone)
		if !allowed[zone] {
			continue
		}
		byZone[zone] = append(byZone[zone], co2Record{Timestamp: record.Minute.Unix(), CO2: record.Emission})
	}
	for zone, records := range byZone {
		if err := writeDaily(conf.Output, zone+".json", records); err != nil {
			return err
		}
	}
	return nil
}
