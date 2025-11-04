# @file
# Makefile for EDK2 CI Matrix Builds
#
# Provides convenient targets for running CI matrix builds locally.
#
# Targets:
#   make setup          - Initial setup (virtual environment and dependencies)
#   make ci-debug       - Run all matrix builds (DEBUG only, default)
#   make ci-all         - Run all matrix builds (DEBUG, RELEASE, NOOPT)
#   make ci-core        - Run core package builds only (DEBUG)
#   make ci-platforms   - Run platform builds only (DEBUG)
#   make ci-retry       - Retry failed jobs
#   make ci-clean       - Remove all build results and start fresh
#   make ci-status      - Show status of all jobs
#   make help           - Show this help
#
# SPDX-License-Identifier: BSD-2-Clause-Patent

.PHONY: help setup ci-debug ci-all ci-core ci-platforms ci-retry ci-clean ci-status

# Default target
.DEFAULT_GOAL := help

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

help:
	@echo "========================================="
	@echo "EDK2 CI Matrix Build Makefile"
	@echo "========================================="
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  make setup          - Initial setup (run once)"
	@echo "  make ci-debug       - Run all matrix builds (DEBUG only)"
	@echo "  make ci-all         - Run all matrix builds (DEBUG, RELEASE, NOOPT)"
	@echo "  make ci-core        - Run core package builds only (DEBUG)"
	@echo "  make ci-platforms   - Run platform builds only (DEBUG)"
	@echo "  make ci-retry       - Retry failed jobs"
	@echo "  make ci-clean       - Remove all build results and start fresh"
	@echo "  make ci-status      - Show status of all jobs"
	@echo ""
	@echo "Examples:"
	@echo "  make setup          # First time setup"
	@echo "  make ci-debug       # Build everything in DEBUG mode"
	@echo "  make ci-core        # Build only core packages"
	@echo "  make ci-retry       # Retry any failed builds"
	@echo ""

setup:
	@echo "$(BLUE)Running initial setup...$(NC)"
	./ci-local-setup.sh
	@echo "$(GREEN)Setup complete!$(NC)"

ci-debug:
	@echo "$(BLUE)Running DEBUG matrix builds...$(NC)"
	./ci-matrix-runner.sh

ci-all:
	@echo "$(BLUE)Running all matrix builds (DEBUG, RELEASE, NOOPT)...$(NC)"
	./ci-matrix-runner.sh --all-targets

ci-core:
	@echo "$(BLUE)Running core package builds (DEBUG)...$(NC)"
	./ci-matrix-runner.sh --core-only

ci-platforms:
	@echo "$(BLUE)Running platform builds (DEBUG)...$(NC)"
	./ci-matrix-runner.sh --platforms-only

ci-retry:
	@echo "$(YELLOW)Retrying failed jobs...$(NC)"
	./ci-matrix-runner.sh --retry-failed

ci-clean:
	@echo "$(YELLOW)Cleaning all build results...$(NC)"
	./ci-matrix-runner.sh --clean
	@echo "$(GREEN)Clean complete!$(NC)"

ci-status:
	@echo "$(BLUE)Job Status Summary:$(NC)"
	@echo "========================================="
	@if [ -d ci-matrix-builds/status ]; then \
		success=$$(grep -l "SUCCESS" ci-matrix-builds/status/*.status 2>/dev/null | wc -l); \
		failed=$$(grep -l "FAILED" ci-matrix-builds/status/*.status 2>/dev/null | wc -l); \
		running=$$(grep -l "RUNNING" ci-matrix-builds/status/*.status 2>/dev/null | wc -l); \
		total=$$(ls ci-matrix-builds/status/*.status 2>/dev/null | wc -l); \
		pending=$$((total - success - failed - running)); \
		echo "Total jobs: $$total"; \
		echo "$(GREEN)Success: $$success$(NC)"; \
		echo "$(RED)Failed: $$failed$(NC)"; \
		echo "$(YELLOW)Pending: $$pending$(NC)"; \
		echo "Running: $$running"; \
		echo "=========================================" ; \
		echo ""; \
		if [ $$success -gt 0 ]; then \
			echo "$(GREEN)Successful jobs:$(NC)"; \
			for f in ci-matrix-builds/status/*.status; do \
				if grep -q "SUCCESS" "$$f" 2>/dev/null; then \
					basename "$$f" .status; \
				fi; \
			done | sed 's/^/  ✓ /'; \
			echo ""; \
		fi; \
		if [ $$failed -gt 0 ]; then \
			echo "$(RED)Failed jobs:$(NC)"; \
			for f in ci-matrix-builds/status/*.status; do \
				if grep -q "FAILED" "$$f" 2>/dev/null; then \
					basename "$$f" .status; \
				fi; \
			done | sed 's/^/  ✗ /'; \
			echo ""; \
			echo "To retry failed jobs: make ci-retry"; \
			echo ""; \
		fi; \
	else \
		echo "No builds found. Run 'make ci-debug' to start."; \
		echo "=========================================" ; \
	fi

# Quick aliases
.PHONY: all clean retry status
all: ci-all
clean: ci-clean
retry: ci-retry
status: ci-status
