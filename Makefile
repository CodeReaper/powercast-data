.PHONY: all test clean

export DOCKER_CLI_HINTS=false

COMPOSE_RUN = docker compose run --rm --quiet-pull

tests = $(shell grep -E '^test-.*:' Makefile | sed 's/:$$//')

all: deps $(tests) unit-tests ## Runs all tests

deps: ## Prepares all docker images
	docker compose pull -q --include-deps
	docker compose build -q

test-dependabot:
	$(COMPOSE_RUN) runner check-jsonschema --builtin-schema dependabot .github/dependabot.yml

test-docker:
	$(COMPOSE_RUN) dockerlint docker/builder.Dockerfile
	$(COMPOSE_RUN) dockerlint docker/runner.Dockerfile
	docker compose config -q

test-editorcheck:
	$(COMPOSE_RUN) runner ec -exclude '^\.git/|^build/|^build\.backup/|.DS_Store'

test-github:
	$(COMPOSE_RUN) runner make _test-github SCHEMA=github-workflows DIRECTORY=workflows
	$(COMPOSE_RUN) runner make _test-github SCHEMA=github-actions DIRECTORY=actions
_test-github:
	@find .github/$(DIRECTORY) -type f \( -iname \*.yaml -o -iname \*.yml \) -print0 | xargs -0 -I {} echo 'echo Checking: {}; check-jsonschema --builtin-schema $(SCHEMA) {}' | sort | sh -e

test-json:
	$(COMPOSE_RUN) runner make _test-json
_test-json:
	@find .vscode configuration test/fixtures testdata -type f -iname '*.json*' -print0 | xargs -0 -I {} echo 'echo Checking: {}; jq empty < {}' | sort | sh -e

test-makefile:
	$(COMPOSE_RUN) makelint

test-markdown:
	$(COMPOSE_RUN) markdownlint --disable MD013 MD031 MD032 -- README.md documentation/*.md

test-openapi:
	$(COMPOSE_RUN) redocly lint --skip-rule operation-4xx-response --format=github-actions resources/openapi.yaml

test-shellcheck:
	$(COMPOSE_RUN) runner shellcheck src/*.sh test/*.sh test/mocks/*/*

CI = $(shell env | grep ^CI=)
TOOL_VERSION = $(shell grep '^golang ' .tool-versions | sed 's/golang //')
MOD_VERSION = $(shell grep '^go ' go.mod | sed 's/go //')
test-go:
	go fmt
	go mod tidy
ifeq ($(strip $(CI)),)
	@git diff --quiet --exit-code || echo 'Warning: Workplace is dirty'
else
	@git diff --quiet --exit-code || (echo 'Error: Workplace is dirty'; exit 1)
endif
	go test -timeout 10s -p 1 -coverprofile=build/coverage.out ./...
	go tool cover -html=build/coverage.out -o build/coverage.html
ifneq ($(TOOL_VERSION),$(MOD_VERSION))
	@echo 'Mismatched go versions'
	@exit 1
endif
	@exit 0

unit-tests:
	$(COMPOSE_RUN) runner make _unit-tests
_unit-tests:
	@-mkdir -p /tmp/t
	@find test -name \*.sh -maxdepth 1 -print0 | xargs -0 -I {} echo 'echo Running {}; sh -e {}' | sort | sh -e

swagger: ## Runs a local swagger
	docker compose up swagger

build:
	$(COMPOSE_RUN) builder make _build

_build:
	curl --fail --output build/datahub-prices.json "https://api.energidataservice.dk/dataset/DatahubPricelist/download?format=json&limit=0"
	jq 'group_by(.GLN_Number) | map({gln: .[0].GLN_Number, name:.[0].ChargeOwner}) | unique' < build/datahub-prices.json > build/gln-names.json

find-charge: build | guard-id ## Looks up charge type codes for a given id
	$(COMPOSE_RUN) runner make id=$(id) _find-charge

_find-charge:
	jq -r --arg id "$(id)" '.[] | select(.GLN_Number == $$id) |select(.ChargeType == "D03") | {uniq: "\(.ChargeTypeCode) / \(.Note)"}' < build/datahub-prices.json | grep '^ '| sort -u

find-charge-verbose: build | guard-id ## Looks up charge type codes for a given id, but with more data
	$(COMPOSE_RUN) runner make id=$(id) _find-charge-verbose

_find-charge-verbose:
	jq -r --arg id "$(id)" '[.[] | select(.GLN_Number == $$id) |select(.ChargeType == "D03")] | map(.from = (.ValidFrom + "Z"|fromdateiso8601) | .ValidTo = if .ValidTo == null or (.ValidTo|type) == "object" then null else .ValidTo end) | group_by(.ChargeTypeCode) | map(max_by(.from))[] | {item: "\(.ChargeTypeCode) / \(.Note) / \(.ValidFrom) / \(.ValidTo)"}' < build/datahub-prices.json| grep '^ '|cut -d\: -f2- | sort -u

view-glns: build ## View company names and their GLN numbers
	$(COMPOSE_RUN) runner cat build/gln-names.json

view-prices: build | guard-id guard-code ## View prices for a given id and code
	$(COMPOSE_RUN) runner make id=$(id) code=$(code) _view-prices

_view-prices:
	jq -r --arg id "$(id)" --arg code "$(code)" '[.[] | select(.GLN_Number == $$id) |select(.ChargeType == "D03")| select(.ChargeTypeCode == $$code)]' < build/datahub-prices.json

guard-%:
	@if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* not set"; \
		exit 1; \
	fi

help: ## Display this help
	@$(COMPOSE_RUN) runner make _help
_help:
	@(echo '---|---'; grep -F '##' Makefile | grep -vF 'grep -vF' | sed -e 's/:.*## */:|/') | column -t -s '|' -N Target,Description

shell: ## Enters a shell on the runner
	@$(COMPOSE_RUN) runner sh

clean: ## Clears data and docker to trigger re-pulling and re-build images
	@$(COMPOSE_RUN) builder make _clean
	docker compose down --rmi all --remove-orphans

_clean:
	@-rm -rf build.backup
	mv build build.backup