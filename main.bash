#!/usr/bin/bash
set -euo pipefail

MAIN_SCRIPT="${BASH_SOURCE[0]}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
MODULES_ROOT="${PROJECT_ROOT}/modules"
SCRIPTS_ROOT="${PROJECT_ROOT}/scripts"
DATA_ROOT="${PROJECT_ROOT}/data"

# shellcheck source=scripts/shared/system.bash
source "$SCRIPTS_ROOT/shared/system.bash"
_system_validate

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
# shellcheck source=scripts/pokeapi/pokeapi.bash
source "$SCRIPTS_ROOT/pokeapi/pokeapi.bash"

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

  mkdir -p "${MODULES_ROOT}"
  mkdir -p "${DATA_ROOT}"

  pushd "$PROJECT_ROOT" >/dev/null
  _run_command "${command}" "${args[@]}"
  popd >/dev/null
}

_main "$@"
