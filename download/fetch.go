package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	requestTimeout = time.Minute
	pageLimit      = 100000
	maxRetries     = 3
)

type datasetResponse[T any] struct {
	Total   int `json:"total"`
	Records []T `json:"records"`
}

type apiTime struct{ time.Time }

func (stamp *apiTime) UnmarshalJSON(data []byte) error {
	var value string
	if err := json.Unmarshal(data, &value); err != nil {
		return err
	}
	parsed, err := time.Parse("2006-01-02T15:04:05", value)
	if err != nil {
		parsed, err = time.Parse(time.RFC3339, value)
		if err != nil {
			return err
		}
	}
	stamp.Time = parsed.UTC()
	return nil
}

type datasetKey struct {
	Timestamp int64
	Zone      string
	Type      string
}

type datasetRecord interface {
	UnixTimestamp() int64
	Identity() datasetKey
}

type timestamped interface{ UnixTimestamp() int64 }

type downloadSession struct {
	ctx    context.Context
	stop   context.CancelFunc
	client *http.Client
}

func newDownloadSession(parent context.Context) *downloadSession {
	ctx, cancel := context.WithCancel(parent)
	return &downloadSession{
		ctx:    ctx,
		stop:   cancel,
		client: &http.Client{Timeout: requestTimeout},
	}
}

// fetch downloads records and deduplicates them by identity. The query must
// request ascending timestamps with deterministic ordering among tied records.
// Throttling, cancellation, or incomplete responses may return partial results
// without an error. The trailing timestamp group is then omitted because more
// records for that timestamp may remain unread. Request and decoding errors
// return no records.
func fetch[T datasetRecord](d *downloadSession, endpoint, dataset string, query url.Values) ([]T, error) {
	cursor := query.Get("start")
	limit, offset := 0, 0
	continuing := false

	var records []T
	seen := make(map[datasetKey]bool)
	for {
		request := cloneValues(query)
		request.Set("limit", strconv.Itoa(limit))
		request.Set("offset", strconv.Itoa(offset))
		if continuing {
			request.Set("start", cursor)
		}
		body, err := d.get(endpoint, dataset, request)
		if err != nil {
			return nil, err
		}
		if body == nil {
			return completePrefix(records), nil
		}

		var page datasetResponse[T]
		if err := json.Unmarshal(body, &page); err != nil {
			return nil, fmt.Errorf("decoding %s response: %w", dataset, err)
		}
		for _, record := range page.Records {
			if !seen[record.Identity()] {
				seen[record.Identity()] = true
				records = append(records, record)
			}
		}

		if len(page.Records) == 0 {
			if offset >= page.Total {
				return records, nil
			}
			return completePrefix(records), nil
		}
		if offset+len(page.Records) >= page.Total {
			return records, nil
		}

		if !continuing {
			last := page.Records[len(page.Records)-1].UnixTimestamp()
			cursor = time.Unix(last, 0).UTC().Format("2006-01-02T15:04")
			limit = pageLimit
			continuing = true
			continue
		}
		offset += len(page.Records)
	}
}

// get returns the raw response body, retrying HTTP 429 within the session budget.
// Retry-After controls the delay, with a five-minute fallback.
// Cancellation, budget exhaustion, or exhausted retries return (nil, nil);
// terminal throttling also stops the shared session. A successful empty response
// has a non-nil body. Other request and response failures return errors while
// the session remains active.
func (d *downloadSession) get(endpoint, dataset string, query url.Values) ([]byte, error) {
	u, err := url.Parse(endpoint)
	if err != nil {
		return nil, fmt.Errorf("parsing endpoint: %w", err)
	}
	u.Path = strings.TrimSuffix(u.Path, "/") + "/dataset/" + dataset
	u.RawQuery = query.Encode()

	for retry := 0; ; retry++ {
		if d.ctx.Err() != nil {
			return nil, nil
		}
		request, err := http.NewRequestWithContext(d.ctx, http.MethodGet, u.String(), nil)
		if err != nil {
			return nil, fmt.Errorf("creating %s request: %w", dataset, err)
		}
		fmt.Fprintf(os.Stderr, "Fetching %s: %s\n", dataset, u.String())
		res, err := d.client.Do(request)
		if err != nil {
			if d.ctx.Err() != nil {
				return nil, nil
			}
			return nil, fmt.Errorf("requesting %s: %w", dataset, err)
		}

		if res.StatusCode == http.StatusTooManyRequests {
			drainAndClose(res.Body)
			if retry == maxRetries {
				d.stop()
				return nil, nil
			}
			delay, err := retryDelay(res.Header.Get("Retry-After"))
			if err != nil {
				return nil, err
			}
			if deadline, ok := d.ctx.Deadline(); ok && time.Until(deadline) <= delay {
				fmt.Fprintf(os.Stderr, "%s: retry would exceed download budget; stopping download (wait %s)\n", dataset, delay)
				d.stop()
				return nil, nil
			}
			fmt.Fprintf(os.Stderr, "%s: HTTP 429; waiting %s before retry\n", dataset, delay)
			timer := time.NewTimer(delay)
			select {
			case <-d.ctx.Done():
				timer.Stop()
				return nil, nil
			case <-timer.C:
			}
			continue
		}

		if res.StatusCode < 200 || res.StatusCode >= 300 {
			body, readErr := io.ReadAll(res.Body)
			closeErr := res.Body.Close()
			if d.ctx.Err() != nil {
				return nil, nil
			}
			if readErr != nil {
				return nil, fmt.Errorf("reading %s error response: %w", dataset, readErr)
			}
			if closeErr != nil {
				return nil, fmt.Errorf("closing %s response: %w", dataset, closeErr)
			}
			return nil, fmt.Errorf("%s returned HTTP %d: %s", dataset, res.StatusCode, truncate(string(body), 512))
		}

		body, readErr := io.ReadAll(res.Body)
		closeErr := res.Body.Close()
		if d.ctx.Err() != nil {
			return nil, nil
		}
		if readErr != nil {
			return nil, fmt.Errorf("reading %s response: %w", dataset, readErr)
		}
		if closeErr != nil {
			return nil, fmt.Errorf("closing %s response: %w", dataset, closeErr)
		}
		if body == nil {
			body = []byte{}
		}
		return body, nil
	}
}

func retryDelay(header string) (time.Duration, error) {
	if seconds, err := strconv.Atoi(strings.TrimSpace(header)); err == nil && seconds >= 0 {
		return time.Duration(seconds) * time.Second, nil
	}
	if when, err := http.ParseTime(header); err == nil {
		if delay := time.Until(when); delay > 0 {
			return delay, nil
		}
	}
	return 0, fmt.Errorf("invalid header for retry delay: %s", header)
}

func drainAndClose(body io.ReadCloser) {
	_, _ = io.Copy(io.Discard, body)
	_ = body.Close()
}

func cloneValues(values url.Values) url.Values {
	cloned := make(url.Values, len(values))
	for key, value := range values {
		cloned[key] = append([]string(nil), value...)
	}
	return cloned
}

// completePrefix drops the trailing timestamp group, which may be incomplete
// when a download stops. Records must be ordered by ascending timestamp.
// The returned slice shares the input's backing array; earlier groups are
// assumed complete, not checked.
func completePrefix[T timestamped](records []T) []T {
	if len(records) == 0 {
		return records
	}
	last := records[len(records)-1].UnixTimestamp()
	end := len(records)
	for end > 0 && records[end-1].UnixTimestamp() == last {
		end--
	}
	return records[:end]
}

func truncate(text string, max int) string {
	if len(text) > max {
		return text[:max]
	}
	return text
}
