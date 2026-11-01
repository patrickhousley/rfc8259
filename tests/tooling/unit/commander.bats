#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

  _unit_setup

  # shellcheck disable=SC2329
  _fake_main() {
    :
  }
}

@test "_register_command stores the command" {
  _register_command --command="fake" --func-name="_fake_main" --summary="fake summary"

  assert_equal "${COMMANDS[*]}" "fake"
  assert_equal "${COMMAND_REGISTRY["fake"]}" "fake"
  assert_equal "${COMMAND_REGISTRY["fake:func_name"]}" "_fake_main"
  assert_equal "${COMMAND_REGISTRY["fake:summary"]}" "fake summary"
  assert_equal "${COMMAND_REGISTRY["fake:help"]}" "0"
}

@test "_register_command defaults to an empty summary" {
  _register_command --command="fake" --func-name="_fake_main"

  assert_equal "${COMMAND_REGISTRY["fake:summary"]}" ""
}

@test "_register_command stores help lines" {
  _register_command --command="fake" --func-name="_fake_main" --summary="summary" --help="line one" --help="line two"

  assert_equal "${COMMAND_REGISTRY["fake:help"]}" "2"
  assert_equal "${COMMAND_REGISTRY["fake:help:0"]}" "line one"
  assert_equal "${COMMAND_REGISTRY["fake:help:1"]}" "line two"
}

@test "_register_command keeps registration order" {
  _register_command --command="b" --func-name="_fake_main"
  _register_command --command="a" --func-name="_fake_main"
  _register_command --command="c" --func-name="_fake_main"

  assert_equal "${COMMANDS[*]}" "b a c"
}

@test "_register_command fails on duplicate command" {
  _register_command --command="fake" --func-name="_fake_main"
  run _register_command --command="fake" --func-name="_fake_main"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Command [fake] already registered"
}

@test "_check_command_exists finds registered commands" {
  _register_command --command="fake" --func-name="_fake_main"
  local command="fake"

  run _check_command_exists "fake"
  assert_success
}

@test "_register_command accepts space separated flags in any case" {
  _register_command --COMMAND fake --Func-Name _fake_main --summary "a summary" --help "line one"

  assert_equal "${COMMANDS[*]}" "fake"
  assert_equal "${COMMAND_REGISTRY["fake:func_name"]}" "_fake_main"
  assert_equal "${COMMAND_REGISTRY["fake:summary"]}" "a summary"
  assert_equal "${COMMAND_REGISTRY["fake:help:0"]}" "line one"
}

@test "_register_command requires a command" {
  run _register_command --func-name="_fake_main"

  assert_failure
  assert_log --scope "commander" --level "fatal" "--command is a required parameter"
}

@test "_register_command requires a function name" {
  run _register_command --command="fake"

  assert_failure
  assert_log --scope "commander" --level "fatal" "--func-name is a required parameter"
}

@test "_register_command fails on unknown argument" {
  run _register_command --command="fake" --bogus

  assert_failure
  assert_log --scope "commander" --level "fatal" "Unknown command argument [--bogus]"
}
