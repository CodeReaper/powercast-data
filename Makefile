export DOCKER_CLI_HINTS=false

test: lint test-shellcheck unit-tests

lint: lint-editorcheck lint-openapi

lint-editorcheck:
	docker compose run --rm runner ec

lint-openapi:
	docker compose run --rm redocly lint --skip-rule operation-4xx-response --format=github-actions resources/openapi.yaml

lint-dependabot:
	docker compose run --rm runner check-jsonschema --schemafile /schemas/dependabot-2.0.json .github/dependabot.yml

test-shellcheck:
	docker compose run --rm runner shellcheck src/*.sh test/*.sh test/mocks/*/*

unit-tests:
	docker compose run --rm runner make _unit-tests
_unit-tests:
	@mkdir -p /tmp/t/ || true
	@find test -name \*.sh -maxdepth 1 -print0 | xargs -0 -I {} echo 'echo Running {}; sh -e {}' | sort | sh -e

swagger:
	docker compose up swagger

clean:
	docker compose down --rmi all --remove-orphans