#!/usr/bin/env bash
set -euo pipefail

_register_sub_command \
  --command="pokeapi" \
  --sub-command="pokemon" \
  --func-name="_pokeapi_pokemon_main" \
  --summary="Pokémon are the creatures that inhabit the world of the Pokémon games." \
  --help="--list        List Pokémon" \
  --help="  [--limit]   Number of results to return per page" \
  --help="  [--offset]  The initial index from which to return the results" \
  --help="--retrieve    Get Pokémon" \
  --help="  --id        ID of the Pokémon to get"

_pokeapi_pokemon_main() {
  local do_list=0
  local do_retrieve=0
  local args=()
  local result_file

  for arg in "$@"; do
    case "${arg,,}" in
    --list)
      do_list=1
      shift 1
      ;;
    --retrieve)
      do_retrieve=1
      shift 1
      ;;
    *)
      args+=("$arg")
      shift 1
      ;;
    esac
  done

  if [[ $do_list -eq 0 && $do_retrieve -eq 0 ]]; then
    _log "_pokeapi_pokemon_main" "--list or --retrieve is a required parameter" "fatal"
  elif [[ $do_list -eq 1 && $do_retrieve -eq 1 ]]; then
    _log "_pokeapi_pokemon_main" "--list or --retrieve parameters mutually exclusive" "fatal"
  elif [[ $do_list -eq 1 ]]; then
    _pokeapi_pokemon_list result_file "${args[@]}"
  else
    _pokeapi_pokemon_retrieve result_file "${args[@]}"
  fi

  _log "_pokeapi_pokemon_main" "Downloaded saved to ${result_file}" "verbose"
}

_pokeapi_pokemon_list() {
  local -n _out=$1
  shift 1
  local limit
  local offset
  local no_cache=0

  while [[ $# -gt 0 ]]; do
    case "${1,,}" in
    --limit)
      limit="${2}"
      shift 2
      ;;
    --limit=*)
      limit="${1#*=}"
      shift 1
      ;;
    --offset)
      offset="${2}"
      shift 2
      ;;
    --offset=*)
      offset="${1#*=}"
      shift 1
      ;;
    --no-cache)
      no_cache=1
      shift 1
      ;;
    *)
      _log "_pokeapi_pokemon_list" "Unknown argument [${1}]" "fatal"
      ;;
    esac
  done

  local fetch_url
  fetch_url="${POKEAPI_SERVER_BASE}/pokemon"
  if [[ -n "${limit:-}" ]]; then
    fetch_url="$(_fetch_append_query "${fetch_url}" "limit" "${limit}")"
  fi
  if [[ -n "${offset:-}" ]]; then
    fetch_url="$(_fetch_append_query "${fetch_url}" "offset" "${offset}")"
  fi

  local out_file
  out_file="${DATA_ROOT}/pokeapi/pokemon/list/$(echo "${fetch_url}" | md5sum | awk '{print $1}').json"

  _fetch_download \
    --url="${fetch_url}" \
    --out-file="${out_file}" \
    "$([[ $no_cache -eq 1 ]] && echo "--no-cache" || echo "--cache")"

  _out="${out_file}"
}

_pokeapi_pokemon_retrieve() {
  local -n _out=$1
  shift 1
  local id
  local no_cache=0

  while [[ $# -gt 0 ]]; do
    case "${1,,}" in
    --id)
      id="${2}"
      shift 2
      ;;
    --id=*)
      id="${1#*=}"
      shift 1
      ;;
    --no-cache)
      no_cache=1
      shift 1
      ;;
    *)
      _log "_pokeapi_pokemon_retrieve" "Unknown argument [${1}]" "fatal"
      ;;
    esac
  done

  if [[ -z "${id:-}" ]]; then
    _log "_pokeapi_pokemon_retrieve" "--id is a required parameter" "fatal"
  fi

  local fetch_url
  fetch_url="${POKEAPI_SERVER_BASE}/pokemon/${id}"
  local out_file
  out_file="${DATA_ROOT}/pokeapi/pokemon/${id}.json"

  _fetch_download \
    --url="${fetch_url}" \
    --out-file="${out_file}" \
    "$([[ $no_cache -eq 1 ]] && echo "--no-cache" || echo "--cache")"

  _out="${out_file}"
}
