#!/usr/bin/env bash
set -euo pipefail

POKEAPI_SERVER_BASE="https://pokeapi.co/api/v2"

# shellcheck source=scripts/pokeapi/raw_client.bash
source "$SCRIPTS_ROOT/pokeapi/raw_client.bash"
# shellcheck source=scripts/pokeapi/data_client.bash
source "$SCRIPTS_ROOT/pokeapi/data_client.bash"
