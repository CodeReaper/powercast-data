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
curl -v https://codereaper.github.io/powercast-data/api/energy-price/
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
curl -v https://codereaper.github.io/powercast-data/api/renewables/
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
curl -v https://codereaper.github.io/powercast-data/api/emission/co2/
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

_Note that only DK zones are available_
_Note that local currency for DK zones means Øre per kWh_

#### Grid Tariffs

All data for a zone is available on a single endpoint:

```sh
curl -v https://codereaper.github.io/powercast-data/api/energy-charges/grid/
```

The response is the charges and tariffs over time using the following format:

```jsonc
[
  {
    "from": <unix timestamp>,
    "to": <unix timestamp>,
    "electricityCharge": <local currency>,
    "transmissionTariff": <local currency>,
    "systemTariff": <local currency>,
    "zone": <zone>
  },
  // ...
]
```

#### Available Networks

All available networks are available on a single endpoint:

```sh
curl -v https://codereaper.github.io/powercast-data/api/energy-charges/network/
```

The response will contain a list of attributes for each network:

```jsonc
[
  {
    "id": <id>,
    "name": <name>,
    "zone": <zone>
  },
  // ...
]
```

#### Network Tariffs

All data for a specific network is available on a single endpoint:

```sh
curl -v https://codereaper.github.io/powercast-data/api/energy-charges/network/<id>/
```

The response is the tariffs over time using the following format:

```jsonc
[
  {
    "from": <unix timestamp>,
    "to": <optional unix timestamp>,
    "tariffs": [<local currency>, ...] // 24 entries with hourly tariff
  },
  // ...
]
```

### Incidents

The endpoints that serve data which is automatically updated from an upstream data source also has an endpoint to retrieve ongoing and past incidents.

The endpoints in question in are:

```sh
curl -v https://codereaper.github.io/powercast-data/api/incidents/emission/co2/<zone>.json
curl -v https://codereaper.github.io/powercast-data/api/incidents/energy-price/<zone>.json
curl -v https://codereaper.github.io/powercast-data/api/incidents/renewables/<zone>.json
```

The response for the incidents are using the following format:

```jsonc
[
  {
    "from": <unix timestamp>,
    "to": <optional unix timestamp>,
    "type": <string> // Specific enumeration value see table below
  },
  // ...
]
```

> [!TIP]
> There will only be one ongoing incident with a specific `type` until it becomes a past incident.

> [!NOTE]
> Incidents started being recorded as of 2024 mid April.

#### Types

The list of used types are enumerated here:

| Type  | Description |
| ----- | ----------- |
| delay | Data expected to be updated according to schedule remains unchanged |
