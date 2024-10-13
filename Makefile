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
	$(COMPOSE_RUN) dockerlint Dockerfile
	docker compose config -q

test-editorcheck:
	$(COMPOSE_RUN) runner ec

test-github:
	$(COMPOSE_RUN) runner make _test-github SCHEMA=github-workflows DIRECTORY=workflows
	$(COMPOSE_RUN) runner make _test-github SCHEMA=github-actions DIRECTORY=actions
_test-github:
	@find .github/$(DIRECTORY) -type f \( -iname \*.yaml -o -iname \*.yml \) -print0 | xargs -0 -I {} echo 'echo Checking: {}; check-jsonschema --builtin-schema $(SCHEMA) {}' | sort | sh -e

test-json:
	$(COMPOSE_RUN) runner make _test-json
_test-json:
	@find .vscode configuration test/fixtures -type f -iname '*.json' -print0 | xargs -0 -I {} echo 'echo Checking: {}; jq empty < {}' | sort | sh -e

test-makefile:
	$(COMPOSE_RUN) makelint

test-markdown:
	$(COMPOSE_RUN) markdownlint --disable MD013 MD031 MD032 -- README.md documentation/*.md

test-openapi:
	$(COMPOSE_RUN) redocly lint --skip-rule operation-4xx-response --format=github-actions resources/openapi.yaml

test-shellcheck:
	$(COMPOSE_RUN) runner shellcheck src/*.sh test/*.sh test/mocks/*/*

unit-tests:
	$(COMPOSE_RUN) runner make _unit-tests
_unit-tests:
	@-mkdir -p /tmp/t
	@find test -name \*.sh -maxdepth 1 -print0 | xargs -0 -I {} echo 'echo Running {}; sh -e {}' | sort | sh -e

swagger: ## Runs a local swagger
	docker compose up swagger

help: ## Display this help
	@$(COMPOSE_RUN) runner make _help
_help:
	@(echo '---|---'; grep -F '##' Makefile | grep -vF 'grep -vF' | sed -e 's/:.*## */:|/') | column -t -s '|' -N Target,Description

shell: ## Enters a shell on the runner
	@$(COMPOSE_RUN) runner sh

clean: ## Clears docker to trigger re-pulling and re-build images
	docker compose down --rmi all --remove-orphans