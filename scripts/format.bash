#!/usr/bin/env bash
set -euo pipefail

_register_command "format" "format" "_format_main" \
	"Runs all lint tooling against the repository" \
	"-w/--write    Enable shfmt writting"

_format_main() {
	if ! command -v "shfmt" >/dev/null 2>&1; then
		_log "formatter" "Binary [shfmt] not installed" "fatal"
	fi

	local write=1
	for arg in "$@"; do
		case "${arg,,}" in
		-w | --write)
			write=0
			;;
		*)
			_log "formatter" "Unknown command argument [${arg}]" "fatal"
			;;
		esac
	done

	local exit_code=0
	if [[ $write -eq 0 ]]; then
		_log "formatter" "Running shfmt in write mode..." "verbose"
		shfmt -w "$PROJECT_ROOT" || exit_code=$?
	else
		_log "formatter" "Running shfmt in check mode..." "verbose"
		shfmt -d "$PROJECT_ROOT" || exit_code=$?
	fi

	if [[ $exit_code -ne 0 ]]; then
		_log "formatter" "Repository files are not properly formatted" "fatal"
	else
		_log "formatter" "Repository files formatted" "success"
	fi
}
