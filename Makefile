SHELL := /usr/bin/env bash

SCRIPT           := proton-community-updater.sh
TEST_DIR         := tests
DOCKER           ?= docker
BATS_IMAGE       ?= bats/bats:latest
SHELLCHECK_IMAGE ?= koalaman/shellcheck:stable

# Run containerised tooling as the invoking user. The script refuses to run as
# root, so a default-root container would fail the moment the tests source it.
DOCKER_RUN := $(DOCKER) run --rm --user "$(shell id -u):$(shell id -g)"

.PHONY: help test lint check

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

test: ## Run the bats test suite (native bats if present, otherwise Docker)
	@if command -v bats >/dev/null 2>&1; then \
		bats $(TEST_DIR); \
	else \
		echo "bats not found locally, using $(BATS_IMAGE)"; \
		$(DOCKER_RUN) -v "$(CURDIR):/code" -w /code $(BATS_IMAGE) $(TEST_DIR); \
	fi

lint: ## Shellcheck the script (native shellcheck if present, otherwise Docker)
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(SCRIPT); \
	else \
		echo "shellcheck not found locally, using $(SHELLCHECK_IMAGE)"; \
		$(DOCKER_RUN) -v "$(CURDIR):/mnt" -w /mnt $(SHELLCHECK_IMAGE) $(SCRIPT); \
	fi

check: lint test ## Run both lint and test
