#!/usr/bin/bash
set -euo pipefail

MAIN_SCRIPT="${BASH_SOURCE[0]}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
MODULES_ROOT="${PROJECT_ROOT}/modules"
SCRIPTS_ROOT="${PROJECT_ROOT}/scripts"

# Helpers
# shellcheck source=scripts/shared/color.bash
source "$SCRIPTS_ROOT/shared/color.bash"
# shellcheck source=scripts/shared/log.bash
source "$SCRIPTS_ROOT/shared/log.bash"
# shellcheck source=scripts/shared/module.bash
source "$SCRIPTS_ROOT/shared/module.bash"
# shellcheck source=scripts/shared/fetch.bash
source "$SCRIPTS_ROOT/shared/fetch.bash"
# shellcheck source=scripts/shared/commander.bash
source "$SCRIPTS_ROOT/shared/commander.bash"

# Commands
# shellcheck source=scripts/help.bash
source "$SCRIPTS_ROOT/help.bash"
# shellcheck source=scripts/lint.bash
source "$SCRIPTS_ROOT/lint.bash"
# shellcheck source=scripts/format.bash
source "$SCRIPTS_ROOT/format.bash"
# shellcheck source=scripts/test.bash
source "$SCRIPTS_ROOT/test.bash"

# Proxy commands
# shellcheck source=scripts/check.bash
source "$SCRIPTS_ROOT/check.bash"

_main() {
  local verbose_found=false
  local args=()
  local command

  for arg in "$@"; do
    case "${arg,,}" in
    -v | --verbose)
      verbose_found=true
      shift 1
      ;;
    *)
      args+=("$arg")
      shift 1
      ;;
    esac
  done

  if $verbose_found; then
    _log_toggle_verbose
  fi

  command="${args[0]:-}"
  if [[ -z "${command}" ]]; then
    command="help"
  else
    args=("${args[@]:1}")
  fi

  if ! _check_command_exists "${command}"; then
    _log "commander" "Unknown command: ${command}" "fatal"
  fi

  local target_func="${COMMAND_REGISTRY["${command}:func_name"]}"
  if _log_is_verbose_enabled; then
    _log "commander" "Running ${target_func} for command ${command} with arguments: [${args[*]}]" "verbose"
  fi

  pushd "$PROJECT_ROOT" >/dev/null
  "$target_func" "${args[@]}"
  popd >/dev/null
}

_main "$@"
# _log_toggle_verbose
# _module_download "shellcheck" "https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.gz"
