# Powercast

Powercast aims to lower the boundary to query, view and understand energy pricing.

## Data sources

The energy prices, renewable energy production and CO2 emission forecast data is looked up in [Energi Data Service](https://www.energidataservice.dk/).

## Quick look

Go and check the [graph](https://codereaper.github.io/powercast-data/).

## API usage

## Energy Price

#### Consume every data point

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

#### Consume data points for a specific date and zone

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

## Renewables

#### Consume every data point

Begin here to load all data using the API:

```sh
curl -v https://codereaper.github.io/powercast-data/api/renewables/latest.json
```

The response will contain paths to latest available data points for each zone using the following format:

```jsonc
[
  {
    "latest": "/api/renewables/<yyyy>/<MM>/<dd>/<zone>.json",
    "zone": "<zone>"
  },
  // ...
]
```

#### Consume data points for a specific date and zone

Request the specific data by replacing data and zone information in this request:

```sh
curl -v https://codereaper.github.io/powercast-data/api/renewables/<yyyy>/<MM>/<dd>/<zone>.json
```

The response is the cost over time using the following format:

```jsonc
[
  {
    "timestamp": <unix timestamp>,
    "sources": [
      {
        "type": <generation-type>,
        "energy": <MWh>
      },
      // ...
    ],
  },
  // ...
]
```

## Future goals:

- Add custom 404 with a sitemap
- Add historical graphs
- Add graphs/graph-combinations ([multi axis might be useful](https://www.chartjs.org/docs/3.2.1/samples/line/multi-axis.html)) for:
  - Energy prices
  - Renewables
  - Emissions
