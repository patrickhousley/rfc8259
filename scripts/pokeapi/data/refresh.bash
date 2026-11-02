#!/usr/bin/env bash
set -euo pipefail

_register_sub_command \
  --command="pokeclient" \
  --sub-command="refresh" \
  --func-name="_pokeapi_client_refresh_main" \
  --summary="Refresh local pokeapi data" \
  --help="--pokemon        Refresh Pokémon" \
  --help="--pokemon-color  Refresh Pokémon colors" \
  --help="--all            Refresh all Pokémon data"

_pokeapi_client_refresh_main() {
  local refresh_pokemon=0
  local refresh_pokemon_color=0
  local refresh_all=0

  for arg in "$@"; do
    case "${arg,,}" in
    --pokemon)
      refresh_pokemon=1
      shift 1
      ;;
    --pokemon-color)
      refresh_pokemon_color=1
      shift 1
      ;;
    --all)
      refresh_all=1
      shift 1
      ;;
    *)
      _log "_pokeapi_client_refresh_main" "Unknown argument [${1}]" "fatal"
      ;;
    esac
  done

  if [[ $refresh_pokemon -eq 1 || $refresh_all -eq 1 ]]; then
    _pokeapi_client_refresh_pokemon
  fi
  if [[ $refresh_pokemon_color -eq 1 || $refresh_all -eq 1 ]]; then
    _pokeapi_client_refresh_pokemon_color
  fi
}

_pokeapi_client_refresh_pokemon() {
  local limit
  local offset
  local page_file

  limit=20
  offset=0
  while :; do
    _pokeapi_pokemon_list page_file \
      --limit="${limit}" \
      --offset="${offset}"

    echo "${page_file}"
    break
  done
}

_pokeapi_client_refresh_pokemon_color() {
  local limit
  local offset
  local page_file

  limit=20
  offset=0
  while :; do
    _pokeapi_pokemon_color_list page_file \
      --limit="${limit}" \
      --offset="${offset}"

    echo "${page_file}"
    break
  done
}
