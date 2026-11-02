#!/usr/bin/env bash
set -euo pipefail

COMMANDS=()
declare -gA COMMAND_REGISTRY
declare -gA SUB_COMMAND_REGISTRY

_check_command_exists() {
  local command="${1}"

  if [[ -z "${COMMAND_REGISTRY[$command]+abc}" ]]; then
    return 1
  fi

  return 0
}

_check_sub_command_exists() {
  local sub_command="${1}"

  if [[ -z "${SUB_COMMAND_REGISTRY[$sub_command]+abc}" ]]; then
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
  COMMAND_REGISTRY["${command}"]="${command}"
  COMMAND_REGISTRY["${command}:func_name"]="${func_name}"
  COMMAND_REGISTRY["${command}:summary"]="${summary}"

  local help_length=0
  for help_line in "${help_lines[@]}"; do
    COMMAND_REGISTRY["${command}:help:${help_length}"]="${help_line}"
    help_length=$((help_length + 1))
  done
  COMMAND_REGISTRY["${command}:help"]=$help_length
}

_register_sub_command() {
  local command
  local sub_command
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
    --sub-command)
      sub_command="${2}"
      shift 2
      ;;
    --sub-command=*)
      sub_command="${1#*=}"
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
  if [[ -z "${sub_command:-}" ]]; then
    _log "commander" "--sub-command is a required parameter" "fatal"
  fi
  if [[ -z "${func_name:-}" ]]; then
    _log "commander" "--func-name is a required parameter" "fatal"
  fi

  if ! _check_command_exists "${command}"; then
    _log "commander" "Command [${command}] not registered" "fatal"
  fi

  local sub_command_name="${command}:${sub_command}"
  if _check_sub_command_exists "${sub_command_name}"; then
    _log "commander" "Sub-command [${sub_command_name}] already registered" "fatal"
  fi

  SUB_COMMAND_REGISTRY["${sub_command_name}"]="${sub_command_name}"
  SUB_COMMAND_REGISTRY["${sub_command_name}:func_name"]="${func_name}"
  SUB_COMMAND_REGISTRY["${sub_command_name}:summary"]="${summary}"

  local help_length=0
  for help_line in "${help_lines[@]}"; do
    SUB_COMMAND_REGISTRY["${sub_command_name}:help:${help_length}"]="${help_line}"
    help_length=$((help_length + 1))
  done
  SUB_COMMAND_REGISTRY["${sub_command_name}:help"]=$help_length
}

_run_command() {
  local command="${1}"
  shift 1

  if ! _check_command_exists "${command}"; then
    _log "commander" "Unknown command: ${command}" "fatal"
  fi

  local target_func
  target_func="${COMMAND_REGISTRY["${command}:func_name"]}"
  if _log_is_verbose_enabled; then
    _log "commander" "Running ${target_func} for command ${command} with arguments: [${*}]" "verbose"
  fi

  pushd "$PROJECT_ROOT" >/dev/null
  "$target_func" "$@"
  popd >/dev/null
}

_run_sub_command() {
  local command="${1}"
  local sub_command="${2}"
  shift 2

  if ! _check_command_exists "${command}"; then
    _log "commander" "Command [${command}] not registered" "fatal"
  fi

  local sub_command_name="${command}:${sub_command}"
  if ! _check_sub_command_exists "${sub_command_name}"; then
    _log "commander" "Sub-command [${sub_command_name}] not registered" "fatal"
  fi

  local target_func
  target_func="${SUB_COMMAND_REGISTRY["${sub_command_name}:func_name"]}"
  if _log_is_verbose_enabled; then
    _log "commander" "Running ${target_func} for sub-command ${sub_command_name} with arguments: [${*}]" "verbose"
  fi

  pushd "$PROJECT_ROOT" >/dev/null
  "$target_func" "$@"
  popd >/dev/null
}
