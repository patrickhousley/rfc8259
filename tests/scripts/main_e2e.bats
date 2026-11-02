#!/usr/bin/env bats

setup() {
  load '../helpers/common_setup'
  load '../helpers/log_fixture'
  load '../helpers/stub_fixture'

  _common_setup
  _stub_setup

  # color.bash requires a terminal that supports colors
  export TERM="xterm-256color"
}

@test "prints the help without a command" {
  run main.bash

  assert_success
  assert_output --regexp 'Usage:.*?main.bash \[-v\|--verbose\] <command>'
}

@test "help flag lists every command" {
  run main.bash --help

  assert_success
  local command
  for command in lint format test pokeapi pokeclient; do
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
  run main.bash --verbose --help

  assert_success
  assert_log --scope "logger" --level "verbose" "Enabled verbose logging"
}

@test "runs on a terminal without color support" {
  TERM=dumb run main.bash --help

  assert_success
  assert_output --regexp 'Usage:.*?main.bash \[-v\|--verbose\] <command>'
}

@test "runs without a terminal type" {
  run env -u TERM main.bash --help

  assert_success
  assert_output --regexp 'Usage:.*?main.bash \[-v\|--verbose\] <command>'
}

@test "runs from any working directory" {
  cd "${BATS_TEST_TMPDIR}"

  run main.bash --help

  assert_success
  assert_output --regexp 'Usage:.*?main.bash \[-v\|--verbose\] <command>'
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
  run main.bash --help --verbose

  assert_success
  assert_log --scope "logger" --level "verbose" "Enabled verbose logging"
}

@test "fails when a required binary is too old" {
  stub_command "curl" "echo 'curl 7.0.0'"

  PATH="${STUB_BIN}:${PATH}" run main.bash --help

  assert_failure
  assert_log --scope "system" --level "error" "[curl] 7.0.0 is older than the required 7.76.0"
  assert_log --scope "system" --level "fatal" "System requirements not met"
}

@test "help is not a command" {
  run main.bash help

  assert_failure
  assert_log --scope "commander" --level "fatal" "Unknown command: help"
}

@test "short help flag prints the help" {
  run main.bash -h

  assert_success
  assert_line "Commands:"
}

@test "commands print their own help" {
  local command
  for command in lint format test pokeapi pokeclient; do
    run main.bash "${command}" --help

    assert_success
    assert_line --regexp "^Usage: .*main.bash ${command} "
  done
}

@test "sub-commands print their own help" {
  run main.bash pokeapi pokemon --help

  assert_success
  assert_line --regexp "^Usage: .*main.bash pokeapi pokemon \[options\]$"
  assert_line "Options:"
}

@test "commands without a sub-command print their help" {
  run main.bash pokeapi

  assert_success
  assert_line "Sub-commands:"
  assert_line --regexp "^  pokemon-color +Colors"
}
