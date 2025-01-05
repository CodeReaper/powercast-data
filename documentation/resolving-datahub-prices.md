# Resolving DataHub Prices

_DataHub contains only prices for Denmark and this document is scoped only for Denmark for that reason._

## Prerequisites

### A list of network areas

The currently best known source for this is [this map](https://ens.dk/sites/ens.dk/files/Statistik/elnetgraenser_2023_04.pdf). There must be a better source...

### Software

- `make`
- `docker`

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

You can view the names of the companies and theirs GLN numbers by running:

```sh
make view-glns
```

The output should view the following example:

```jsonc
// ...
  {
    "gln": "5790000000000",
    "name": "Zero Power A/S"
  },
// ...
```

### Look up available `ChargeTypeCode`

We can list available `ChargeTypeCode` with some description using the following commands:

```sh
make id=5790000000000 find-charge
make id=5790000000000 find-charge-verbose # for additional data
```

_Note that must replace 5790000000000 with the actual GLN number_.

The expected output will vary a lot, but here is an example:

```text
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

The verbose output will include date ranges for the codes, like so:
```text
"8040 / Nettarif indfødning B høj / 2015-10-01T00:00:00 / 2015-10-03T00:00:00"
"8070 / Nettarif indfødning A høj / 2025-02-01T00:00:00 / null"
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
make id=5790000000000 code=4000 view-prices |less
```

_Note you can exit less by typing 'q'_.

_Note that must replace 5790000000000 with the actual GLN number and 4000 with the potential `ChargeTypeCode`_.

Some network company will post their prices for each day and for some time into the future, so it may be necessary to look quite far into the result of the command to match the price list.
