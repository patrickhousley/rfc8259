#!/usr/bin/env bash
set -euo pipefail

_help_title() {
  printf "RFC8259 Parsers\n\n"
}

# Prints a registry entry as an aligned row, with its help lines underneath in the summary column
#
# Usage: _help_print_entry <registry name> <key> <label> <label width> [--summary-only]
_help_print_entry() {
  local -n _help_registry="${1}"
  local key="${2}"
  local label="${3}"
  local width="${4}"
  local summary="${_help_registry["${key}:summary"]:-}"
  local help_length="${_help_registry["${key}:help"]:-0}"
  local i

  printf "  %-*s  %s\n" "${width}" "${label}" "${summary}"
  if [[ "${5:-}" == "--summary-only" ]]; then
    return 0
  fi
  for ((i = 0; i < help_length; i++)); do
    printf "  %-*s  %s\n" "${width}" "" "${_help_registry["${key}:help:${i}"]}"
  done
}

# Prints the help lines of a registry entry as a block of options, nothing when there are none
#
# Usage: _help_print_options <registry name> <key>
_help_print_options() {
  local -n _help_registry="${1}"
  local key="${2}"
  local help_length="${_help_registry["${key}:help"]:-0}"
  local i

  if [[ $help_length -eq 0 ]]; then
    return 0
  fi

  printf "\nOptions:\n"
  for ((i = 0; i < help_length; i++)); do
    printf "  %s\n" "${_help_registry["${key}:help:${i}"]}"
  done
}

_print_help() {
  local command
  local width=0

  for command in "${COMMANDS[@]}"; do
    if [[ ${#command} -gt $width ]]; then
      width=${#command}
    fi
  done

  _help_title
  printf "Usage: %s [-v|--verbose] <command> [command_args]\n\n" "${MAIN_SCRIPT}"
  printf "Options:\n"
  printf "  -v, --verbose  Enable verbose logging\n"
  printf "  -h, --help     Print this help information\n\n"
  printf "Commands:\n"
  for command in "${COMMANDS[@]}"; do
    _help_print_entry COMMAND_REGISTRY "${command}" "${command}" "${width}" --summary-only
  done
  printf "\nRun '%s <command> --help' for details\n" "${MAIN_SCRIPT}"
}

_print_command_help() {
  local command=""
  local sub_command_name
  local sub_commands=()
  local width=0

  while [[ $# -gt 0 ]]; do
    case "${1,,}" in
    --command)
      command="${2}"
      shift 2
      ;;
    --command=*)
      command="${1#*=}"
      shift 1
      ;;
    *)
      _log "_print_command_help" "Unknown argument [${1}]" "fatal"
      ;;
    esac
  done

  if [[ -z "${command}" ]]; then
    _log "_print_command_help" "--command is a required parameter" "fatal"
  fi
  if ! _check_command_exists "${command}"; then
    _log "_print_command_help" "Command [${command}] not registered" "fatal"
  fi

  for sub_command_name in "${SUB_COMMANDS[@]}"; do
    if [[ "${sub_command_name}" == "${command}:"* ]]; then
      sub_commands+=("${sub_command_name}")
      if [[ $((${#sub_command_name} - ${#command} - 1)) -gt $width ]]; then
        width=$((${#sub_command_name} - ${#command} - 1))
      fi
    fi
  done

  _help_title
  if [[ ${#sub_commands[@]} -gt 0 ]]; then
    printf "Usage: %s %s <sub-command> [sub-command_args]\n\n" "${MAIN_SCRIPT}" "${command}"
  else
    printf "Usage: %s %s [options]\n\n" "${MAIN_SCRIPT}" "${command}"
  fi
  printf "%s\n" "${COMMAND_REGISTRY["${command}:summary"]:-}"
  _help_print_options COMMAND_REGISTRY "${command}"

  if [[ ${#sub_commands[@]} -gt 0 ]]; then
    printf "\nSub-commands:\n"
    for sub_command_name in "${sub_commands[@]}"; do
      _help_print_entry SUB_COMMAND_REGISTRY "${sub_command_name}" "${sub_command_name#*:}" "${width}" --summary-only
    done
    printf "\nRun '%s %s <sub-command> --help' for details\n" "${MAIN_SCRIPT}" "${command}"
  fi
}

_print_sub_command_help() {
  local command=""
  local sub_command=""

  while [[ $# -gt 0 ]]; do
    case "${1,,}" in
    --command)
      command="${2}"
      shift 2
      ;;
    --command=*)
      command="${1#*=}"
      shift 1
      ;;
    --sub-command)
      sub_command="${2}"
      shift 2
      ;;
    --sub-command=*)
      sub_command="${1#*=}"
      shift 1
      ;;
    *)
      _log "_print_sub_command_help" "Unknown argument [${1}]" "fatal"
      ;;
    esac
  done

  if [[ -z "${command}" ]]; then
    _log "_print_sub_command_help" "--command is a required parameter" "fatal"
  fi
  if [[ -z "${sub_command}" ]]; then
    _log "_print_sub_command_help" "--sub-command is a required parameter" "fatal"
  fi
  if ! _check_sub_command_exists "${command}:${sub_command}"; then
    _log "_print_sub_command_help" "Sub-command [${command}:${sub_command}] not registered" "fatal"
  fi

  _help_title
  printf "Usage: %s %s %s [options]\n\n" "${MAIN_SCRIPT}" "${command}" "${sub_command}"
  printf "%s\n" "${SUB_COMMAND_REGISTRY["${command}:${sub_command}:summary"]:-}"
  _help_print_options SUB_COMMAND_REGISTRY "${command}:${sub_command}"
}
