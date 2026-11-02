#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

  _unit_setup
  _unit_source_script "shared/fetch"
  _unit_source_script "pokeapi/pokeapi"

  FETCH_CALLS="${BATS_TEST_TMPDIR}/fetch.calls"
  # shellcheck disable=SC2329
  _fetch_download() {
    printf '%s\n' "$*" >>"${FETCH_CALLS}"
  }
}

# Prints the cache file path a list request for the given query string is stored under
_list_file() {
  local url="https://pokeapi.co/api/v2/pokemon${1}"
  echo "${DATA_ROOT}/pokeapi/pokemon/list/$(printf '%s\n' "${url}" | md5sum | awk '{print $1}').json"
}

@test "registers the pokemon sub-command" {
  assert_equal "${SUB_COMMAND_REGISTRY["pokeapi:pokemon:func_name"]}" "_pokeapi_pokemon_main"
}

@test "_pokeapi_pokemon_main requires --list or --retrieve" {
  run _pokeapi_pokemon_main

  assert_failure
  assert_log --scope "_pokeapi_pokemon_main" --level "fatal" "--list or --retrieve is a required parameter"
}

@test "_pokeapi_pokemon_main rejects --list with --retrieve" {
  run _pokeapi_pokemon_main --list --retrieve

  assert_failure
  assert_log --scope "_pokeapi_pokemon_main" --level "fatal" "--list or --retrieve parameters mutually exclusive"
}

@test "_pokeapi_pokemon_main lists with the remaining arguments" {
  run _pokeapi_pokemon_main --list --limit=5 --offset=10

  assert_success
  assert_equal "$(cat "${FETCH_CALLS}")" "--url=https://pokeapi.co/api/v2/pokemon?limit=5&offset=10 --out-file=$(_list_file "?limit=5&offset=10") --cache"
}

@test "_pokeapi_pokemon_main retrieves with the remaining arguments" {
  run _pokeapi_pokemon_main --retrieve --id=1

  assert_success
  assert_equal "$(cat "${FETCH_CALLS}")" "--url=https://pokeapi.co/api/v2/pokemon/1 --out-file=${DATA_ROOT}/pokeapi/pokemon/1.json --cache"
}

@test "_pokeapi_pokemon_main logs the saved file when verbose" {
  LOG_VERBOSE=0

  run _pokeapi_pokemon_main --retrieve --id=1

  assert_success
  assert_log --scope "_pokeapi_pokemon_main" --level "verbose" "Downloaded saved to ${DATA_ROOT}/pokeapi/pokemon/1.json"
}

@test "_pokeapi_pokemon_list returns the output file through the named variable" {
  local result_file
  _pokeapi_pokemon_list result_file --limit=20 --offset=40

  assert_equal "${result_file}" "$(_list_file "?limit=20&offset=40")"
}

@test "_pokeapi_pokemon_list does not write to stdout" {
  local result_file
  run _pokeapi_pokemon_list result_file --limit=20

  assert_success
  assert_output ""
}

@test "_pokeapi_pokemon_list omits query parameters that were not given" {
  local result_file
  _pokeapi_pokemon_list result_file

  assert_equal "${result_file}" "$(_list_file "")"
  assert_equal "$(cat "${FETCH_CALLS}")" "--url=https://pokeapi.co/api/v2/pokemon --out-file=${result_file} --cache"
}

@test "_pokeapi_pokemon_list accepts space separated arguments in any case" {
  local result_file
  _pokeapi_pokemon_list result_file --LIMIT 5 --Offset 10

  assert_equal "${result_file}" "$(_list_file "?limit=5&offset=10")"
}

@test "_pokeapi_pokemon_list bypasses the cache with --no-cache" {
  local result_file
  _pokeapi_pokemon_list result_file --no-cache

  assert_equal "$(cat "${FETCH_CALLS}")" "--url=https://pokeapi.co/api/v2/pokemon --out-file=${result_file} --no-cache"
}

@test "_pokeapi_pokemon_list uses a different file for each page" {
  local first
  local second
  _pokeapi_pokemon_list first --limit=20 --offset=0
  _pokeapi_pokemon_list second --limit=20 --offset=20

  assert_not_equal "${first}" "${second}"
}

@test "_pokeapi_pokemon_list fails on unknown argument" {
  local result_file
  run _pokeapi_pokemon_list result_file --bogus

  assert_failure
  assert_log --scope "_pokeapi_pokemon_list" --level "fatal" "Unknown argument [--bogus]"
  assert [ ! -e "${FETCH_CALLS}" ]
}

@test "_pokeapi_pokemon_retrieve returns the output file through the named variable" {
  local result_file
  _pokeapi_pokemon_retrieve result_file --id=25

  assert_equal "${result_file}" "${DATA_ROOT}/pokeapi/pokemon/25.json"
  assert_equal "$(cat "${FETCH_CALLS}")" "--url=https://pokeapi.co/api/v2/pokemon/25 --out-file=${result_file} --cache"
}

@test "_pokeapi_pokemon_retrieve does not write to stdout" {
  local result_file
  run _pokeapi_pokemon_retrieve result_file --id=25

  assert_success
  assert_output ""
}

@test "_pokeapi_pokemon_retrieve accepts a space separated id" {
  local result_file
  _pokeapi_pokemon_retrieve result_file --ID 25

  assert_equal "${result_file}" "${DATA_ROOT}/pokeapi/pokemon/25.json"
}

@test "_pokeapi_pokemon_retrieve bypasses the cache with --no-cache" {
  local result_file
  _pokeapi_pokemon_retrieve result_file --id=25 --no-cache

  assert_equal "$(cat "${FETCH_CALLS}")" "--url=https://pokeapi.co/api/v2/pokemon/25 --out-file=${result_file} --no-cache"
}

@test "_pokeapi_pokemon_retrieve requires an id" {
  local result_file
  run _pokeapi_pokemon_retrieve result_file

  assert_failure
  assert_log --scope "_pokeapi_pokemon_retrieve" --level "fatal" "--id is a required parameter"
  assert [ ! -e "${FETCH_CALLS}" ]
}

@test "_pokeapi_pokemon_retrieve fails on unknown argument" {
  local result_file
  run _pokeapi_pokemon_retrieve result_file --id=25 --bogus

  assert_failure
  assert_log --scope "_pokeapi_pokemon_retrieve" --level "fatal" "Unknown argument [--bogus]"
}

@test "_pokeapi_pokemon_retrieve sets the caller variable even when the caller names it out_file" {
  local out_file_result
  _pokeapi_pokemon_retrieve out_file_result --id=25

  assert_equal "${out_file_result}" "${DATA_ROOT}/pokeapi/pokemon/25.json"
}
