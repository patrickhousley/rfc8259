#!/usr/bin/env bats

setup() {
  load '../../helpers/unit_setup'

  _unit_setup
  _unit_source_script "shared/fetch"
  _unit_source_script "pokeapi/pokeapi"

  # shellcheck disable=SC2329
  _fake_sub_main() {
    echo "pwd=${PWD} args=[$*]"
  }
  _register_sub_command --command="pokeapi" --sub-command="fake" --func-name="_fake_sub_main"
}

@test "registers the pokeapi command" {
  assert_equal "${COMMAND_REGISTRY["pokeapi:func_name"]}" "_pokeapi_main"
}

@test "registers the raw pokemon sub-commands" {
  assert_equal "${SUB_COMMAND_REGISTRY["pokeapi:pokemon:func_name"]}" "_pokeapi_pokemon_main"
  assert_equal "${SUB_COMMAND_REGISTRY["pokeapi:pokemon-color:func_name"]}" "_pokeapi_pokemon_color_main"
}

@test "_pokeapi_main runs the sub-command with its arguments" {
  run _pokeapi_main "fake" "a" "b c"

  assert_success
  assert_output "pwd=${PROJECT_ROOT} args=[a b c]"
}

@test "_pokeapi_main runs the sub-command without arguments" {
  run _pokeapi_main "fake"

  assert_success
  assert_output "pwd=${PROJECT_ROOT} args=[]"
}

@test "_pokeapi_main fails on unknown sub-command" {
  run _pokeapi_main "bogus"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Sub-command [pokeapi:bogus] not registered"
}
