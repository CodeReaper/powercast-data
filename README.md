# powercast-data

## API usage

### Consume every data point

Begin here to load all data using the API:

```sh
curl -v https://codereaper.github.io/powercast-data/api/energy-price/latest.json
```

The response will contain paths to latest available data points for each zone using the following format:

```json
[
  {
    "latest": "/api/energy-price/<yyyy>/<MM>/<dd>/<zone>.json",
    "zone": "<zone>"
  },
  ...
]
```

### Consume data points for a specific date and zone

Request the specific data by replacing data and zone information in this request:

```sh
curl -v https://codereaper.github.io/powercast-data/api/energy-price/<yyyy>/<MM>/<dd>/<zone>.json
```

The response is the cost over time using the following format:

```json
[
  {
    "euro": <cost>, // of one MWh
    "timestamp": <unix timestamp>
  },
  ...
]
```

## Quick look

Go and check the [https://codereaper.github.io/powercast-data/](graph).

## TODOs:

- Add more zones
- Add standalone graphs for each zone
- Add graphs for historical data
- Add forecastable data for:
  - CO2 emission
  - Renewables
- Add ability to easily run all unit tests locally
