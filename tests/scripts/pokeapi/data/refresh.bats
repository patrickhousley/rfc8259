#!/usr/bin/env bats

setup() {
  load '../../../helpers/unit_setup'

  _unit_setup
  _unit_source_script "shared/fetch"
  _unit_source_script "pokeapi/pokeapi"

  LIST_CALLS="${BATS_TEST_TMPDIR}/list.calls"
}

# Replaces the refresh functions so _pokeapi_client_refresh_main can be tested on its own
_stub_refresh_functions() {
  # shellcheck disable=SC2329
  _pokeapi_client_refresh_pokemon() {
    echo "refresh pokemon"
  }
  # shellcheck disable=SC2329
  _pokeapi_client_refresh_pokemon_color() {
    echo "refresh pokemon-color"
  }
}

@test "_pokeapi_client_refresh_main refreshes nothing without flags" {
  _stub_refresh_functions
  run _pokeapi_client_refresh_main

  assert_success
  assert_output ""
}

@test "_pokeapi_client_refresh_main refreshes pokemon" {
  _stub_refresh_functions
  run _pokeapi_client_refresh_main --pokemon

  assert_success
  assert_output "refresh pokemon"
}

@test "_pokeapi_client_refresh_main refreshes pokemon colors" {
  _stub_refresh_functions
  run _pokeapi_client_refresh_main --pokemon-color

  assert_success
  assert_output "refresh pokemon-color"
}

@test "_pokeapi_client_refresh_main refreshes everything with --all" {
  _stub_refresh_functions
  run _pokeapi_client_refresh_main --all

  assert_success
  assert_output - <<EOF2
refresh pokemon
refresh pokemon-color
EOF2
}

@test "_pokeapi_client_refresh_main accepts flags in any case" {
  _stub_refresh_functions
  run _pokeapi_client_refresh_main --POKEMON --Pokemon-Color

  assert_success
  assert_output - <<EOF2
refresh pokemon
refresh pokemon-color
EOF2
}

@test "_pokeapi_client_refresh_main fails on unknown argument" {
  _stub_refresh_functions
  run _pokeapi_client_refresh_main --bogus

  assert_failure
  assert_log --scope "_pokeapi_client_refresh_main" --level "fatal" "Unknown argument [--bogus]"
  refute_output --partial "refresh pokemon"
}

@test "_pokeapi_client_refresh_pokemon requests the first page" {
  # shellcheck disable=SC2329
  _pokeapi_pokemon_list() {
    local -n _out=$1
    shift 1
    echo "$*" >>"${LIST_CALLS}"
    _out="${DATA_ROOT}/pokemon-page.json"
  }

  run _pokeapi_client_refresh_pokemon

  assert_success
  assert_equal "$(cat "${LIST_CALLS}")" "--limit=20 --offset=0"
}

@test "_pokeapi_client_refresh_pokemon prints the page file" {
  # shellcheck disable=SC2329
  _pokeapi_pokemon_list() {
    local -n _out=$1
    _out="${DATA_ROOT}/pokemon-page.json"
  }

  run _pokeapi_client_refresh_pokemon

  assert_success
  assert_output "${DATA_ROOT}/pokemon-page.json"
}

@test "_pokeapi_client_refresh_pokemon fails when the list request fails" {
  # shellcheck disable=SC2329
  _pokeapi_pokemon_list() {
    _log "_pokeapi_pokemon_list" "request failed" "fatal"
  }

  run _pokeapi_client_refresh_pokemon

  assert_failure
  assert_log --scope "_pokeapi_pokemon_list" --level "fatal" "request failed"
}

@test "_pokeapi_client_refresh_pokemon_color requests the first page" {
  # shellcheck disable=SC2329
  _pokeapi_pokemon_color_list() {
    local -n _out=$1
    shift 1
    echo "$*" >>"${LIST_CALLS}"
    _out="${DATA_ROOT}/pokemon-color-page.json"
  }

  run _pokeapi_client_refresh_pokemon_color

  assert_success
  assert_equal "$(cat "${LIST_CALLS}")" "--limit=20 --offset=0"
}

@test "_pokeapi_client_refresh_pokemon_color prints the page file" {
  # shellcheck disable=SC2329
  _pokeapi_pokemon_color_list() {
    local -n _out=$1
    _out="${DATA_ROOT}/pokemon-color-page.json"
  }

  run _pokeapi_client_refresh_pokemon_color

  assert_success
  assert_output "${DATA_ROOT}/pokemon-color-page.json"
}

@test "_pokeapi_client_refresh_pokemon_color fails when the list request fails" {
  # shellcheck disable=SC2329
  _pokeapi_pokemon_color_list() {
    _log "_pokeapi_pokemon_color_list" "request failed" "fatal"
  }

  run _pokeapi_client_refresh_pokemon_color

  assert_failure
  assert_log --scope "_pokeapi_pokemon_color_list" --level "fatal" "request failed"
}

@test "_pokeapi_client_refresh_main refreshes pokemon through the list request" {
  # shellcheck disable=SC2329
  _pokeapi_pokemon_list() {
    local -n _out=$1
    _out="${DATA_ROOT}/pokemon-page.json"
  }

  run _pokeapi_client_refresh_main --pokemon

  assert_success
  assert_output "${DATA_ROOT}/pokemon-page.json"
}
