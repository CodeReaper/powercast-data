export DOCKER_CLI_HINTS=false

COMPOSE_RUN = docker compose run --rm --quiet-pull

all: test-editorcheck test-openapi test-shellcheck test-dependabot test-docker unit-tests ## Runs all tests

test-editorcheck:
	$(COMPOSE_RUN) runner ec

test-openapi:
	$(COMPOSE_RUN) redocly lint --skip-rule operation-4xx-response --format=github-actions resources/openapi.yaml

test-dependabot:
	$(COMPOSE_RUN) runner check-jsonschema --schemafile /schemas/dependabot-2.0.json .github/dependabot.yml

test-docker:
	$(COMPOSE_RUN) dockerlint

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
	@grep -F '##' Makefile | grep -vF 'grep -vF' | sed -e 's/:.*## */:|/' | column -t -s '|' -N Target,Description

shell: ## Enters a shell on the runner
	@$(COMPOSE_RUN) runner sh

clean: ## Clears docker to trigger re-pulling and re-build
	docker compose down --rmi all --remove-orphans