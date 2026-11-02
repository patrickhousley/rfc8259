#!/usr/bin/env bats

setup() {
  load '../../helpers/unit_setup'

  _unit_setup
  _unit_source_script "shared/fetch"
  _unit_source_script "pokeapi/pokeapi"
}

@test "sets the pokeapi server base url" {
  assert_equal "${POKEAPI_SERVER_BASE}" "https://pokeapi.co/api/v2"
}

@test "registers the raw and data client commands" {
  assert_equal "${COMMANDS[*]}" "pokeapi pokeclient"
}
