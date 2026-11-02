#!/usr/bin/env bash
set -euo pipefail

_register_command \
  --command="pokeapi" \
  --func-name="_pokeapi_main" \
  --summary="Interact with pokeapi raw api"

# shellcheck source=scripts/pokeapi/raw/pokemon.bash
source "$SCRIPTS_ROOT/pokeapi/raw/pokemon.bash"
# shellcheck source=scripts/pokeapi/raw/pokemon_color.bash
source "$SCRIPTS_ROOT/pokeapi/raw/pokemon_color.bash"

_pokeapi_main() {
  local sub_command

  if [[ -z "${1:-}" ]]; then
    sub_command="help"
  else
    sub_command="${1}"
    shift 1
  fi

  if [[ $# -gt 0 ]]; then
    _run_sub_command "pokeapi" "${sub_command}" "${@}"
  else
    _run_sub_command "pokeapi" "${sub_command}"
  fi
}
