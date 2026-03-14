# Agent Guidelines

This file provides guidelines for agentic coding agents operating in this repository.

## Quick Reference

### Running Tests

```bash
# Run all tests (Go + shell scripts + linting)
make

# Run only Go tests
make test-go

# Run Go tests with verbose output
go test -v ./...

# Run a single Go test by name
go test -v -run TestName ./...

# Run only shell script tests (requires Docker)
make unit-tests

# Run specific linter
make test-github      # GitHub workflow/action validation
make test-json        # JSON validation
make test-markdown    # Markdown linting
make test-openapi     # OpenAPI spec validation
make test-shellcheck  # Shell script linting
```

## Code Style Guidelines

### General

Read `.editorconfig` for formatting rules.

### Go

Use idiomatic go:

- **Testing**: Uses `github.com/stretchr/testify/assert` for assertions
- **Error handling**: Wrap errors with `errors.Join()` for multiple errors, use sentinel errors defined at package level
- **JSON**: Use struct tags for serialization (e.g., `json:"euro"`)
- **Formatting**: Run `go fmt` before committing; `go mod tidy` for dependencies

### Shell Scripts

- Use POSIX-compliant `sh` (not bash)
- Always use `set -e` for error handling
- Check required tools with `which` before use
- Exit codes: 1 = file error, 2 = directory error, 3 = validation error
- Quote variables: `"$VAR"` not `$VAR`

Example pattern for validation:

```sh
set -e

FILE=$1
[ -f "$FILE" ] || { echo "Not a file: $FILE"; exit 1; }
```

## GitHub Workflows

This repository relies on GitHub Actions for CI/CD and data updates.
Workflows are located in `.github/workflows/`.

### Essential Workflows

| Workflow                      | Purpose                                                                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `merge-test.yaml`             | Runs `make` on all PRs to main. Auto-merges dependabot and automation bot PRs.                                                  |
| `health-checks.yaml`          | Scheduled daily health checks. Calls `health-check-grid.yaml`, `health-check-networks.yaml`, and `health-check-integrity.yaml`. |
| `health-check-grid.yaml`      | Validates grid configuration data                                                                                               |
| `health-check-networks.yaml`  | Validates network configuration data                                                                                            |
| `health-check-integrity.yaml` | Validates data integrity across datasets                                                                                        |
| `pull-data.yaml`              | Fetches energy price data from Energi Data Service API                                                                          |
| `pull-tariff-data.yaml`       | Fetches tariff data from Energinet                                                                                              |
| `update-visualization.yaml`   | Updates static visualization files                                                                                              |
| `update-api-constants.yaml`   | Updates API constant definitions                                                                                                |
| `upgrade-go.yaml`             | Automated Go version upgrades                                                                                                   |

### Workflow Patterns

- Workflows use `on.schedule` for periodic tasks
- Most workflows support `workflow_dispatch` for manual runs
- Health check workflows publish results to `gh-pages` branch

## Docker

Docker and Docker Compose are required for running tests and development:

```bash
# Install dependencies and run all tests
make deps
make

# Run a shell in the runner container
make shell
```

The `compose.yml` defines services for:

- `runner` - Main container for running scripts and tests
- `builder` - For build operations
- `swagger` - Local OpenAPI documentation

## Maintenance

When modifying this repository:

1. **Adding new tests**: Add Go tests in `*_test.go` files. Add shell tests in `test/*.sh` and call them from the main Makefile target.

2. **Adding new workflows**: Place in `.github/workflows/` and validate with `make test-github`.

3. **Updating AGENTS.md**: If you add new commands, change code style, or add new workflows, update this file to reflect those changes. Run `make` to ensure all tests pass.

4. **Dependencies**: Use `go mod tidy` for Go dependencies. Shell scripts should use tools available in the runner container (check `compose.yml` for the base image).

## Project Structure

```
├── .github/
│   ├── workflows/  # GitHub Actions workflows
│   └── actions/    # Reusable GitHub Actions
├── build/          # Generated build artifacts (gitignored)
├── configuration/  # JSON configuration files
├── resources/      # OpenAPI spec and static HTML
├── src/            # Shell scripts for data operations
├── test/           # Shell script tests
├── test/fixtures/  # Shell test fixtures
├── testdata/       # Go test fixtures (raw API responses)
└── Makefile        # Build automation
```
