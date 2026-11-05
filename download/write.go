package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"time"
)

// writeDaily merges records into root/YYYY/MM/DD/name using UTC dates.
// Each file contains one record per timestamp in ascending order; existing
// records take precedence over incoming records. An error does not roll back
// files already written.
func writeDaily[T timestamped](root, name string, records []T) error {
	byDate := make(map[string][]T)
	for _, record := range records {
		date := time.Unix(record.UnixTimestamp(), 0).UTC().Format("2006/01/02")
		byDate[date] = append(byDate[date], record)
	}
	for date, incoming := range byDate {
		path := filepath.Join(root, date, name)
		var existing []T
		data, err := os.ReadFile(path)
		if err == nil {
			if err := json.Unmarshal(data, &existing); err != nil {
				return fmt.Errorf("decoding existing %s: %w", path, err)
			}
		} else if !os.IsNotExist(err) {
			return fmt.Errorf("reading %s: %w", path, err)
		}
		merged := make(map[int64]T, len(incoming)+len(existing))
		for _, record := range incoming {
			merged[record.UnixTimestamp()] = record
		}
		for _, record := range existing {
			merged[record.UnixTimestamp()] = record
		}
		times := make([]int64, 0, len(merged))
		for value := range merged {
			times = append(times, value)
		}
		slices.Sort(times)
		output := make([]T, 0, len(times))
		for _, value := range times {
			output = append(output, merged[value])
		}
		if err := writeFile(path, output); err != nil {
			return err
		}
	}
	return nil
}

// writeFile writes indented JSON with a trailing newline, creating parent
// directories as needed. Encoding errors leave the destination untouched.
// Replacement is not atomic: a write failure may leave the file truncated.
func writeFile[T any](path string, value T) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return fmt.Errorf("encoding %s: %w", path, err)
	}
	data = append(data, '\n')
	if err := os.MkdirAll(filepath.Dir(path), 0770); err != nil {
		return fmt.Errorf("creating output directory for %s: %w", path, err)
	}
	if err := os.WriteFile(path, data, 0644); err != nil {
		return fmt.Errorf("writing %s: %w", path, err)
	}
	return nil
}
