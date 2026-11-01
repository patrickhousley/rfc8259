#!/usr/bin/env bash
set -euo pipefail

COMMANDS=()
declare -gA COMMAND_REGISTRY

_check_command_exists() {
  if [[ -z "${COMMAND_REGISTRY[$command]+abc}" ]]; then
    return 1
  fi

  return 0
}

_register_command() {
  local command
  local func_name
  local summary=""
  local help_lines=()

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
    --func-name)
      func_name="${2}"
      shift 2
      ;;
    --func-name=*)
      func_name="${1#*=}"
      shift 1
      ;;
    --summary)
      summary="${2}"
      shift 2
      ;;
    --summary=*)
      summary="${1#*=}"
      shift 1
      ;;
    --help)
      help_lines+=("${2}")
      shift 2
      ;;
    --help=*)
      help_lines+=("${1#*=}")
      shift 1
      ;;
    *)
      _log "commander" "Unknown command argument [${1}]" "fatal"
      ;;
    esac
  done

  if [[ -z "${command:-}" ]]; then
    _log "commander" "--command is a required parameter" "fatal"
  fi
  if [[ -z "${func_name:-}" ]]; then
    _log "commander" "--func-name is a required parameter" "fatal"
  fi

  if _check_command_exists "${command}"; then
    _log "commander" "Command [${command}] already registered" "fatal"
  fi

  COMMANDS+=("${command}")
  COMMAND_REGISTRY["${command}"]=$command
  COMMAND_REGISTRY["${command}:func_name"]=$func_name
  COMMAND_REGISTRY["${command}:summary"]=$summary

  local help_length=0
  for help_line in "${help_lines[@]}"; do
    COMMAND_REGISTRY["${command}:help:${help_length}"]="${help_line}"
    help_length=$((help_length + 1))
  done
  COMMAND_REGISTRY["${command}:help"]=$help_length
}
