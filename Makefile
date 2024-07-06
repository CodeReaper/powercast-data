.default = test
.phony = test

export DOCKER_CLI_HINTS=false

test: lint test-shellcheck unit-tests

lint:
	@echo 'Running editorconfig check'
	@ec

test-shellcheck:
	@echo 'Running shellcheck'
	@shellcheck src/*.sh test/*.sh test/mocks/*/*

unit-tests:
	@mkdir -p /tmp/t/ || true
	@find test -name \*.sh -maxdepth 1 -print0 | xargs -0 -I {} echo 'echo Running {}; sh -e {}' | sort | sh -e

shell:
	@docker rmi --force powercast-runner:latest 2>&1 > /dev/null
	@docker build -qt powercast-runner . >/dev/null
	@docker run -it --rm \
	-v $$(pwd):/workspace \
	-w /workspace \
	powercast-runner /bin/sh
