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
  _run_sub_command "pokeapi" "$@"
}
