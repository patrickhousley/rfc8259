#!/usr/bin/env bash
set -euo pipefail

_register_command \
  --command="pokeclient" \
  --func-name="_pokeapi_client_main" \
  --summary="Data client interface to pokeapi"

# shellcheck source=scripts/pokeapi/data/refresh.bash
source "$SCRIPTS_ROOT/pokeapi/data/refresh.bash"

_pokeapi_client_main() {
  _run_sub_command "pokeclient" "$@"
}
