#!/usr/bin/env bash
set -euo pipefail

LOG_VERBOSE=1
LOG_START="${NC}"
LOG_END="${NC}\n"
LOG_OPEN_BRACKET="${NC}${PURPLE}[${NC}"
LOG_CLOSE_BRACKET="${NC}${PURPLE}]${NC}"

_log() {
	local scope="${1}"
	local message="${2}"
	local level="${3:-info}"
	local is_fatal=1

	if [[ "${level,,}" == "verbose" ]] && (! _log_is_verbose_enabled); then
		return
	fi

	if [[ "${level,,}" == "fatal" ]]; then
		is_fatal=0
	fi

	printf "%b" "${LOG_START}"
	printf "%b" "${LOG_OPEN_BRACKET}${GREY}${scope}${LOG_CLOSE_BRACKET}"

	case "${level,,}" in
	# Blue levels
	"info")
		printf "%b" "${LOG_OPEN_BRACKET}${BLUE}${level^^}${LOG_CLOSE_BRACKET}"
		;;
	# Green levels
	"success")
		printf "%b" "${LOG_OPEN_BRACKET}${GREEN}${level^^}${LOG_CLOSE_BRACKET}"
		;;
	# Yellow levels
	"warn" | "verbose")
		printf "%b" "${LOG_OPEN_BRACKET}${YELLOW}${level^^}${LOG_CLOSE_BRACKET}"
		;;
	# Red levels
	"error" | "fatal")
		printf "%b" "${LOG_OPEN_BRACKET}${RED}${level^^}${LOG_CLOSE_BRACKET}"
		;;
	# Unknown levels
	*)
		message="Unknown log level ${level}"
		is_fatal=0
		printf "%b" "${LOG_OPEN_BRACKET}${RED}FATAL${LOG_CLOSE_BRACKET}"
		;;
	esac

	printf " %s" "$message"
	printf "%b" "${LOG_END}"

	if [[ is_fatal -eq 0 ]]; then
		exit 1
	fi
}

_log_is_verbose_enabled() {
	return $LOG_VERBOSE
}

_log_toggle_verbose() {
	if [[ $LOG_VERBOSE -ne 0 ]]; then
		LOG_VERBOSE=0
		_log "logger" "Enabled verbose logging" "verbose"
	else
		LOG_VERBOSE=1
	fi
}
