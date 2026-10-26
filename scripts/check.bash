#!/usr/bin/env bash
set -euo pipefail

_register_command "check" "check" "_check_main" \
	"Runs formatting, linting, and other verification tooling" \
	"-w/--write    Runs tools in write mode that support it"

_check_main() {
	local write=1
	for arg in "$@"; do
		case "${arg,,}" in
		-w | --write)
			write=0
			;;
		*)
			_log "check" "Unknown command argument [${arg}]" "fatal"
			;;
		esac
	done

	local exit_code=0
	if [[ $write -eq 0 ]]; then
		_format_main --write
		_lint_main --write
	else
		_format_main
		_lint_main
	fi
}
