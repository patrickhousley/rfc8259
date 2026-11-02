#!/usr/bin/env bash
set -euo pipefail

_register_command \
  --command="pokeclient" \
  --func-name="_pokeapi_client_main" \
  --summary="Data client interface to pokeapi"

# shellcheck source=scripts/pokeapi/data/refresh.bash
source "$SCRIPTS_ROOT/pokeapi/data/refresh.bash"

_pokeapi_client_main() {
  local sub_command

  if [[ -z "${1:-}" ]]; then
    sub_command="help"
  else
    sub_command="${1}"
    shift 1
  fi

  if [[ $# -gt 0 ]]; then
    _run_sub_command "pokeclient" "${sub_command}" "${@}"
  else
    _run_sub_command "pokeclient" "${sub_command}"
  fi
}
