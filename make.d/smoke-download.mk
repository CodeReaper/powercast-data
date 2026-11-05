SMOKE_END := $(shell echo $$(( $$(date +%s) / 86400 * 86400 )))
SMOKE_FROM := $(shell echo $$(($(SMOKE_END) - 86400)))

.PHONY: smoke-download smoke-prepare smoke-energy-price smoke-renewables smoke-co2-emission smoke-quarter-hours

smoke-download: smoke-energy-price smoke-renewables smoke-co2-emission smoke-quarter-hours
	@echo "Smoke test passed. Output: build/smoke"

smoke-prepare:
	command -v jq >/dev/null
	rm -rf build/smoke
	mkdir -p build/smoke
	go build -o build/smoke/download ./download

smoke-energy-price smoke-renewables smoke-co2-emission: smoke-%: smoke-prepare
	build/smoke/download --dataset $* --zones DK1,DK2 --from $(SMOKE_FROM) --end $(SMOKE_END) --output build/smoke/$*
	jq -e 'type == "array" and length > 0' build/smoke/$*/*/*/*/DK1.json >/dev/null
	jq -e 'type == "array" and length > 0' build/smoke/$*/*/*/*/DK2.json >/dev/null

smoke-quarter-hours: smoke-energy-price
	jq -e 'type == "array" and length > 0' build/smoke/energy-price/v2/*/*/*/DK1/index.json >/dev/null
	jq -e 'type == "array" and length > 0' build/smoke/energy-price/v2/*/*/*/DK2/index.json >/dev/null