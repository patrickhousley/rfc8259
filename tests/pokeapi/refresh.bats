#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

  _unit_setup
  _unit_source_script "shared/fetch"
  _unit_source_script "pokeapi/pokeapi"

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
  run _pokeapi_client_refresh_main

  assert_success
  assert_output ""
}

@test "_pokeapi_client_refresh_main refreshes pokemon" {
  run _pokeapi_client_refresh_main --pokemon

  assert_success
  assert_output "refresh pokemon"
}

@test "_pokeapi_client_refresh_main refreshes pokemon colors" {
  run _pokeapi_client_refresh_main --pokemon-color

  assert_success
  assert_output "refresh pokemon-color"
}

@test "_pokeapi_client_refresh_main refreshes everything with --all" {
  run _pokeapi_client_refresh_main --all

  assert_success
  assert_output - <<EOF2
refresh pokemon
refresh pokemon-color
EOF2
}

@test "_pokeapi_client_refresh_main accepts flags in any case" {
  run _pokeapi_client_refresh_main --POKEMON --Pokemon-Color

  assert_success
  assert_output - <<EOF2
refresh pokemon
refresh pokemon-color
EOF2
}

@test "_pokeapi_client_refresh_main fails on unknown argument" {
  run _pokeapi_client_refresh_main --bogus

  assert_failure
  assert_log --scope "_pokeapi_client_refresh_main" --level "fatal" "Unknown argument [--bogus]"
  refute_output --partial "refresh pokemon"
}
