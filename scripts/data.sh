#!/usr/bin/env bash
set -euo pipefail

_register_command "data" "data" "_data_main" \
	"Manage the data files in the repository"

_data_main() {
	echo "Test"
}
