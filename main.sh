#!/usr/bin/bash
set -euo pipefail

MAIN_SCRIPT="${BASH_SOURCE[0]}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPTS_ROOT="${PROJECT_ROOT}/scripts"
COMMANDS=()
declare -A COMMAND_REGISTRY

# shellcheck source=scripts/color.sh
source "$SCRIPTS_ROOT/color.sh"
# shellcheck source=scripts/log.sh
source "$SCRIPTS_ROOT/log.sh"

_check_command_exists() {
	if [[ -z "${COMMAND_REGISTRY[$command]+abc}" ]]; then
		return 1
	fi

	return 0
}

_register_command() {
	local command="${1}"
	local display="${2}"
	local func_name="${3}"
	local summary="${4:-}"

	if _check_command_exists "${command}"; then
		_log "commander" "Command [${command}] already registered" "fatal"
	fi

	COMMANDS+=("${command}")
	COMMAND_REGISTRY["${command}"]=$command
	COMMAND_REGISTRY["${command}:display"]=$display
	COMMAND_REGISTRY["${command}:func_name"]=$func_name
	COMMAND_REGISTRY["${command}:summary"]=$summary

	local help_length=0
	for help_line in "${@:5}"; do
		COMMAND_REGISTRY["${command}:help:${help_length}"]="${help_line}"
		help_length=$((help_length + 1))
	done
	COMMAND_REGISTRY["${command}:help"]=$help_length
}

# shellcheck source=scripts/help.sh
source "$SCRIPTS_ROOT/help.sh"
# shellcheck source=scripts/lint.sh
source "$SCRIPTS_ROOT/lint.sh"
# shellcheck source=scripts/format.sh
source "$SCRIPTS_ROOT/format.sh"
# shellcheck source=scripts/data.sh
source "$SCRIPTS_ROOT/data.sh"

# shellcheck source=scripts/check.sh
source "$SCRIPTS_ROOT/check.sh"

_main() {
	local verbose_found=false
	local args=()

	for arg in "$@"; do
		case "${arg,,}" in
		-v | --verbose)
			verbose_found=true
			shift
			;;
		*)
			# Save non-verbose arguments into an array
			args+=("$arg")
			;;
		esac
	done

	if $verbose_found; then
		_log_toggle_verbose
	fi

	local command="${args[0]:-help}"
	shift

	if ! _check_command_exists "${command}"; then
		_log "commander" "Unknown command: ${command}" "fatal"
	fi

	local target_func="${COMMAND_REGISTRY["${command}:func_name"]}"
	if _log_is_verbose_enabled; then
		_log "commander" "Running ${target_func} for command ${command} with arguments: [$*]" "verbose"
	fi

	pushd "$PROJECT_ROOT" >/dev/null
	"$target_func" "$@"
	popd >/dev/null
}

_main "$@"
