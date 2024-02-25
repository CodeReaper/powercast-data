# Resolving Datahub Prices

_Datahub contains only prices for Denmark and this document is scoped only for Denmark for that reason._

## Prerequisites

### A list of network areas

The currently best known source for this is [this map](https://ens.dk/sites/ens.dk/files/Statistik/elnetgraenser_2023_04.pdf). There must be a better source...

### The tool `jq`

[`jq`](https://jqlang.github.io/jq/) is json manipulation tool - you will find all tools are present in the [`devcontainer`](https://containers.dev) for this repo.

### A local copy of price data

We will prepare two files using these two commands:

```sh
curl -v "https://api.energidataservice.dk/dataset/DatahubPricelist/download?format=json&limit=0" > list.json
```

```sh
jq 'group_by(.GLN_Number) | map({gln: .[0].GLN_Number, name:.[0].ChargeOwner}) | unique' < list.json > gln-names.json
```

## Searching data

To add the fictive network company "Zero Power" the following steps must be taken:

- Find actual prices
- Look up GLN
- Look up available `ChargeTypeCode`
- Find class `C` `ChargeTypeCode`
- Match price lists

### Find actual prices

The company name ("Zero Power") must be used to search online for an actual price list. We will need this list to verify that the `ChargeTypeCode` is in fact the correct one.

### Look up GLN

The prepared file `gls-names.json` should contain the name of the company and its GLN number, for instance:

```jsonc
// ...
  {
    "gln": "5790000000000",
    "name": "Zero Power A/S"
  },
// ...
```

### Look up available `ChargeTypeCode`

We can list available `ChargeTypeCode` with some description using the following command:

```sh
jq -r '.[] | select(.GLN_Number == "5790000000000") |select(.ChargeType == "D03") | {uniq: "\(.ChargeTypeCode) / \(.Note)"}' < list.json | grep '^ '| sort -u
```

Or attempt to list relevant `ChargeTypeCode` based on dates using the following command:

```sh
jq -r '[.[] | select(.GLN_Number == "5790000000000") |select(.ChargeType == "D03")] | map(.from = (.ValidFrom + "Z"|fromdateiso8601) | .ValidTo = if (.ValidTo|type) == "object" then null else .ValidTo end) | group_by(.ChargeTypeCode) | map(max_by(.from))[] | {item: "\(.ChargeTypeCode) / \(.Note) / \(.ValidFrom) / \(.ValidTo)"}' < list.json| grep '^ '|cut -d\: -f2- | sort -u
```

_Note that must replace 5790000000000 with the actual GLN number_.

The expected output will vary a lot, but here is an example:

```
  "uniq": "4000 / Nettarif C skabelon"
  "uniq": "4000 / Nettarif C"
  "uniq": "4000 / Nettarif C-Flex"
  "uniq": "4000 / Transportbetaling lokalt"
  "uniq": "4010 / Nettarif C time"
  "uniq": "4010 / Transportbetaling M-C"
  "uniq": "4020 / Nettarif B Lav time"
  "uniq": "4020 / Nettarif B lav time"
  "uniq": "4020 / Nettarif B-Lav time"
  "uniq": "4020 / Transportbetaling M-BL"
  "uniq": "4020 / Transportbetaling M-BL2"
  "uniq": "4030 / Transportbetaling M-BL1"
  "uniq": "4040 / Nettarif B Høj"
  "uniq": "4040 / Nettarif B høj"
  "uniq": "4040 / Transportbetaling M-BH"
  "uniq": "4050 / Net rådighedstarif B høj"
  "uniq": "4050 / Rådighedstarif"
  "uniq": "4052 / Regional rådighedstarif"
  "uniq": "4060 / Nettarif C (fritaget for energisparebidrag)"
  "uniq": "4060 / Nettarif C Skabelon"
  "uniq": "4060 / Nettarif C Skabelone"
  "uniq": "4060 / Nettarif C"
  "uniq": "4062 / Nettarif B-lav"
  "uniq": "4062 / Transportbetaling B-lav"
  "uniq": "4064 / Nettarif B Høj"
  "uniq": "4064 / Nettarif B-høj"
  "uniq": "4064 / Transportbetaling B-høj"
  "uniq": "4070 / Nettarif A-Høj"
  "uniq": "4070 / Nettarif A-Lav"
  "uniq": "8000 / Nettarif indfødning C"
  "uniq": "8020 / Nettarif indfødning B lav"
  "uniq": "8040 / Nettarif indfødning B høj"
  "uniq": "8070 / Nettarif indfødning A høj"
```

### Find class `C` `ChargeTypeCode`

One thing to note is that the `ChargeTypeCode` can be the same for multiple "notes".

In the example above, the potential class `C` `ChargeTypeCode` are:
- `4000`
- `4010`
- `4060`

### Match price lists

At this point we have:
- A price list
- A GLN number
- A list of potential `ChargeTypeCode`

With these items we can execute a command to view the prices:
```sh
jq -r '[.[] | select(.GLN_Number == "5790000000000") |select(.ChargeType == "D03")| select(.ChargeTypeCode == "4000")]' < list.json|less
```

_Note you can exit less by typing 'q'_.

_Note that must replace 5790000000000 with the actual GLN number and 4000 with the potential `ChargeTypeCode`_.

Some network company will post their prices for each day and for some time into the future, so it may be necessary to look quite far into the result of the command to match the price list.
