# Powercast

Powercast aims to lower the boundary to query, view and understand energy pricing.

## Quick look

Go and check the graphs:
 - [Energy Price](https://codereaper.github.io/powercast-data/energy-price)
 - [CO2 Emission](https://codereaper.github.io/powercast-data/emission-co2)
 - [Renewable Energy Production](https://codereaper.github.io/powercast-data/renewables)

## Data sources

### [Energi Data Service](https://www.energidataservice.dk/)

The following datasets are used to look up data.

- [Energy prices](https://www.energidataservice.dk/tso-electricity/Elspotprices)
- [Energy charge prices](https://www.energidataservice.dk/tso-electricity/DatahubPricelist)
- [CO2 emission forecast data](https://www.energidataservice.dk/tso-electricity/CO2EmisProg)
- [Renewable energy production](https://www.energidataservice.dk/tso-electricity/forecasts_hour)

### [Energinet tariffs](https://energinet.dk/el/elmarkedet/tariffer/aktuelle-tariffer/)

The network- and system-tariff in Denmark are defined by law and published by Energinet yearly.

### [Danish ministry of taxation](https://www.skm.dk/skattetal/satser/satser-og-beloebsgraenser-i-lovgivningen/elafgiftsloven/)

The electricity charge is defined by law.

### Fixed values

#### Euro exchange rates

-  Danish krone is pegged to a rate of [7.46](https://www.investopedia.com/terms/d/dkk.asp) krones per Euro.

#### VAT

- Danish VAT is always [25%](https://www.retsinformation.dk/eli/lta/2019/1021#P33)

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

### Energy Charges

#### Consume data points for a specific zone

_Note that only DK zones are available_

All data for a zone is available on a single endpoint:

```sh
curl -v https://codereaper.github.io/powercast-data/api/energy-charges/<zone>.json
```

The response will contain conversion rates, taxes, tariffs and other charges:

```jsonc
{
  "vat": [
    {
      "from": <unix timestamp>,
      "to": <optional unix timestamp>,
      "vat": <percent>, // given as a fraction between 0 and 1
    }
  ],
  "exchange": [
    {
      "from": <unix timestamp>,
      "to": <optional unix timestamp>,
      "rate": <amount>, // of local currency per Euro
    }
  ],
  "grid": [
    {
      "from": <unix timestamp>,
      "to": <unix timestamp>,
      "electricityCharge": <local currency>,
      "transmissionTariff": <local currency>,
      "systemTariff": <local currency>
    },
  ],
  "network": {
    "id": <id>,
    "name": <name>,
    "tariffs": [
      {
        "from": <unix timestamp>,
        "to": <optional unix timestamp>,
        "tariffs": [<local currency>, ...] // 24 entries with hourly tariff
      }
    ]
  }
}
```
