package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func run(args []string) error {
	var (
		dataset  = "energy-price"
		zones    string
		output   string
		endpoint = "https://api.energidataservice.dk/"
		from     int64
		end      int64
		v2date   int64 = 1758326400
	)
	flags := flag.NewFlagSet("download", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	flags.StringVar(&dataset, "dataset", dataset, "Dataset: energy-price, renewables, or co2-emission")
	flags.StringVar(&zones, "zones", zones, "Comma-separated zones")
	flags.StringVar(&output, "output", output, "Output directory")
	flags.StringVar(&endpoint, "endpoint", endpoint, "API endpoint")
	flags.Int64Var(&from, "from", from, "Inclusive start timestamp")
	flags.Int64Var(&end, "end", end, "Exclusive end timestamp")
	flags.Int64Var(&v2date, "v2date", v2date, "DayAheadPrices start timestamp")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if zones == "" || output == "" || from <= 0 || end <= from {
		return fmt.Errorf("zones, output, and a valid from/end range are required")
	}

	conf := downloadConfig{
		Endpoint: endpoint,
		Output:   output,
		Zones:    strings.Split(zones, ","),
		From:     from,
		End:      end,
		V2Date:   v2date,
	}
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Second)
	defer cancel()

	switch dataset {
	case "energy-price":
		return downloadPrices(ctx, conf)
	case "renewables":
		return downloadRenewables(ctx, conf)
	case "co2-emission":
		return downloadCO2(ctx, conf)
	default:
		return fmt.Errorf("unknown dataset %q", dataset)
	}
}
