#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

  _unit_setup

  # shellcheck disable=SC2329
  _fake_main() {
    echo "pwd=${PWD} args=[$*]"
  }
}

@test "_main runs the command from the project root with its arguments" {
  _register_command --command="fake" --func-name="_fake_main"
  cd "${BATS_TEST_TMPDIR}"

  run _main "fake" "a" "b c"

  assert_success
  assert_output "pwd=${PROJECT_ROOT} args=[a b c]"
}

@test "_main runs the command without arguments" {
  _register_command --command="fake" --func-name="_fake_main"

  run _main "fake"

  assert_success
  assert_output "pwd=${PROJECT_ROOT} args=[]"
}

@test "_main prints the help without a command" {
  _register_command --command="fake" --func-name="_fake_main" --summary="Fake summary"

  run _main

  assert_success
  assert_line "Commands:"
  assert_line --regexp "^  fake +Fake summary$"
  refute_output --partial "pwd="
}

@test "_main prints the help for the help flag" {
  _register_command --command="fake" --func-name="_fake_main" --summary="Fake summary"

  local flag
  for flag in -h --help -H --HELP; do
    run _main "${flag}"

    assert_success
    assert_line "Commands:"
    refute_output --partial "pwd="
  done
}

@test "_main prints the command help for the help flag after a command" {
  _register_command --command="fake" --func-name="_fake_main" --summary="Fake summary"

  run _main "fake" "--help"

  assert_success
  assert_line --regexp "^Usage: .* fake \[options\]$"
  assert_line "Fake summary"
  refute_output --partial "pwd="
}

@test "_main does not treat help as a command" {
  run _main "help"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Unknown command: help"
}

@test "_main fails on unknown command" {
  run _main "foobar"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Unknown command: foobar"
}

@test "_main enables verbose logging and removes the flag from arguments" {
  _register_command --command="fake" --func-name="_fake_main"

  local flag
  for flag in -v --verbose -V --VERBOSE; do
    run _main "${flag}" "fake" "a"

    assert_success
    assert_log --scope "logger" --level "verbose" "Enabled verbose logging"
    assert_log --scope "commander" --level "verbose" "Running _fake_main for command fake with arguments: [a]"
    assert_line "pwd=${PROJECT_ROOT} args=[a]"
  done
}

@test "_main accepts the verbose flag after the command" {
  _register_command --command="fake" --func-name="_fake_main"

  run _main "fake" "a" "-v" "b"

  assert_success
  assert_log --scope "logger" --level "verbose" "Enabled verbose logging"
  assert_line "pwd=${PROJECT_ROOT} args=[a b]"
}

@test "_main does not log verbose messages by default" {
  _register_command --command="fake" --func-name="_fake_main"

  run _main "fake"

  assert_success
  refute_log --level "verbose" --partial ""
}
