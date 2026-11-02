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
  _register_sub_command --command="pokeclient" --sub-command="fake" --func-name="_fake_sub_main"
}

@test "registers the pokeclient command" {
  assert_equal "${COMMAND_REGISTRY["pokeclient:func_name"]}" "_pokeapi_client_main"
}

@test "registers the pokeclient refresh sub-command" {
  assert_equal "${SUB_COMMAND_REGISTRY["pokeclient:refresh:func_name"]}" "_pokeapi_client_refresh_main"
}

@test "_pokeapi_client_main runs the sub-command with its arguments" {
  run _pokeapi_client_main "fake" "a" "b c"

  assert_success
  assert_output "pwd=${PROJECT_ROOT} args=[a b c]"
}

@test "_pokeapi_client_main runs the sub-command without arguments" {
  run _pokeapi_client_main "fake"

  assert_success
  assert_output "pwd=${PROJECT_ROOT} args=[]"
}

@test "_pokeapi_client_main fails on unknown sub-command" {
  run _pokeapi_client_main "bogus"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Sub-command [pokeclient:bogus] not registered"
}
