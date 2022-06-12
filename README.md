# Powercast

Powercast aims to lower the boundary to query, view and understand energy pricing.

## Quick look

Go and check the [graph](https://codereaper.github.io/powercast-data/).

## API usage

### Consume every data point

Begin here to load all data using the API:

```sh
curl -v https://codereaper.github.io/powercast-data/api/energy-price/latest.json
```

The response will contain paths to latest available data points for each zone using the following format:

```jsonc
[
  {
    "latest": "/api/energy-price/<yyyy>/<MM>/<dd>/<zone>.json",
    "zone": "<zone>"
  },
  // ...
]
```

### Consume data points for a specific date and zone

Request the specific data by replacing data and zone information in this request:

```sh
curl -v https://codereaper.github.io/powercast-data/api/energy-price/<yyyy>/<MM>/<dd>/<zone>.json
```

The response is the cost over time using the following format:

```jsonc
[
  {
    "euro": <cost>, // of one MWh
    "timestamp": <unix timestamp>
  },
  // ...
]
```

## Future goals:

- Add custom 404 with a sitemap
- Add standalone graphs for each zone
- Add graphs for historical data
- Add forecastable data ([multi axis might be useful](https://www.chartjs.org/docs/3.2.1/samples/line/multi-axis.html)) for:
  - [CO2 emission](https://www.energidataservice.dk/tso-electricity/co2emisprog)
  - [Renewables](https://www.energidataservice.dk/tso-electricity/forecasts_hour)
- Add ability to easily run all unit tests locally
