#!/usr/bin/env bats

setup() {
  load 'helpers/common_setup'
  load 'helpers/log_fixture'
  load 'helpers/stub_fixture'

  _common_setup
  _stub_setup

  # color.bash requires a terminal that supports colors
  export TERM="xterm-256color"
}

@test "defaults to help command" {
  run main.bash

  assert_success
  assert_output --regexp 'Example:.*?main.bash command'
}

@test "help lists every command" {
  run main.bash help

  assert_success
  local command
  for command in help lint format test pokeapi pokeclient; do
    assert_line --regexp "^  ${command} +[A-Z]"
  done
}

@test "log fatal on unknown command" {
  local command="foobar"
  run main.bash "${command}"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Unknown command: ${command}"
}

@test "verbose flag enables verbose logging" {
  run main.bash --verbose help

  assert_success
  assert_log --scope "logger" --level "verbose" "Enabled verbose logging"
  assert_log --scope "commander" --level "verbose" "Running _help_main for command help with arguments: []"
}

@test "runs on a terminal without color support" {
  TERM=dumb run main.bash help

  assert_success
  assert_output --regexp 'Example:.*?main.bash command'
}

@test "runs without a terminal type" {
  run env -u TERM main.bash help

  assert_success
  assert_output --regexp 'Example:.*?main.bash command'
}

@test "runs from any working directory" {
  cd "${BATS_TEST_TMPDIR}"

  run main.bash help

  assert_success
  assert_output --regexp 'Example:.*?main.bash command'
}

@test "format rejects unknown arguments" {
  run main.bash format --bogus

  assert_failure
  assert_log --level "fatal" "Unknown command argument [--bogus]"
}

@test "lint rejects unknown arguments" {
  run main.bash lint --bogus

  assert_failure
  assert_log --level "fatal" "Unknown command argument [--bogus]"
}

@test "verbose flag is accepted after the command" {
  run main.bash help --verbose

  assert_success
  assert_log --scope "logger" --level "verbose" "Enabled verbose logging"
}
