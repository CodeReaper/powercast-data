# Powercast

Powercast aims to lower the boundary to query, view and understand energy pricing.

## Data sources

The energy prices, renewable energy production and CO2 emission forecast data is looked up in [Energi Data Service](https://www.energidataservice.dk/).

## Quick look

Go and check the graphs:
 - [Energy Price](https://codereaper.github.io/powercast-data/energy-price)
 - [CO2 Emission](https://codereaper.github.io/powercast-data/emission-co2)
 - [Renewable Energy Production](https://codereaper.github.io/powercast-data/renewables)

## API usage

### Energy Price

#### Consume every data point

Begin here to load all data using the API:

```sh
curl -v https://codereaper.github.io/powercast-data/api/energy-price/index.json
```

The response will contain paths to latest and oldest available data points for each zone using the following format:

```jsonc
[
  {
    "latest": "/api/energy-price/<yyyy>/<MM>/<dd>/<zone>.json",
    "oldest": "/api/energy-price/<yyyy>/<MM>/<dd>/<zone>.json",
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

### Renewables

#### Consume every data point

Begin here to load all data using the API:

```sh
curl -v https://codereaper.github.io/powercast-data/api/renewables/index.json
```

The response will contain paths to latest and oldest available data points for each zone using the following format:

```jsonc
[
  {
    "latest": "/api/renewables/<yyyy>/<MM>/<dd>/<zone>.json",
    "oldest": "/api/renewables/<yyyy>/<MM>/<dd>/<zone>.json",
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

The response is the grouped energy amount over time using the following format:

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

### CO2 Emission

#### Consume every data point

Begin here to load all data using the API:

```sh
curl -v https://codereaper.github.io/powercast-data/api/emission/co2/index.json
```

The response will contain paths to latest and oldest available data points for each zone using the following format:

```jsonc
[
  {
    "latest": "/api/emission/co2/<yyyy>/<MM>/<dd>/<zone>.json",
    "oldest": "/api/emission/co2/<yyyy>/<MM>/<dd>/<zone>.json",
    "zone": "<zone>"
  },
  // ...
]
```

#### Consume data points for a specific date and zone

Request the specific data by replacing data and zone information in this request:

```sh
curl -v https://codereaper.github.io/powercast-data/api/emission/co2/<yyyy>/<MM>/<dd>/<zone>.json
```

The response is the emission over time using the following format:

```jsonc
[
  {
    "timestamp": <unix timestamp>,
    "co2": <amount>, // in g/kWh
  },
  // ...
]
```
