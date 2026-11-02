#!/usr/bin/env bats

setup() {
  load '../../helpers/unit_setup'

  _unit_setup

  _register_command --command="lint" --func-name="_fake_main" --summary="Lint summary" \
    --help="--write    Enable autofixing"
  _register_command --command="a-very-long-name" --func-name="_fake_main" --summary="Long summary"
  _register_command --command="group" --func-name="_fake_main" --summary="Group summary" \
    --help="--verbose  Group option"
  _register_sub_command --command="group" --sub-command="one" --func-name="_fake_main" \
    --summary="First sub-command" \
    --help="--list    List things" \
    --help="  [--id]  Thing id"
  _register_sub_command --command="group" --sub-command="second-sub" --func-name="_fake_main" \
    --summary="Second sub-command"
}

@test "_print_help prints the usage and every registered command" {
  run _print_help

  assert_success
  assert_output - <<EOF2
RFC8259 Parsers

Usage: ${MAIN_SCRIPT} [-v|--verbose] <command> [command_args]

Options:
  -v, --verbose  Enable verbose logging
  -h, --help     Print this help information

Commands:
  lint              Lint summary
  a-very-long-name  Long summary
  group             Group summary

Run '${MAIN_SCRIPT} <command> --help' for details
EOF2
}

@test "_print_help leaves command options to the command help" {
  run _print_help

  assert_success
  refute_output --partial "--write"
  refute_output --partial "Group option"
}

@test "_print_help aligns summaries to the longest command" {
  run _print_help

  assert_line "  lint              Lint summary"
  assert_line "  a-very-long-name  Long summary"
}

@test "_print_help keeps registration order" {
  run _print_help

  assert_success
  local lint_line group_line
  lint_line="$(echo "${output}" | grep -n "^  lint " | cut -d: -f1)"
  group_line="$(echo "${output}" | grep -n "^  group " | cut -d: -f1)"
  assert [ "${lint_line}" -lt "${group_line}" ]
}

@test "_print_help does not exit the calling shell" {
  _print_help >/dev/null

  assert_equal "reached" "reached"
}

@test "_print_command_help prints the command usage, options and sub-commands" {
  run _print_command_help --command "group"

  assert_success
  assert_output - <<EOF2
RFC8259 Parsers

Usage: ${MAIN_SCRIPT} group <sub-command> [sub-command_args]

Group summary

Options:
  --verbose  Group option

Sub-commands:
  one         First sub-command
  second-sub  Second sub-command

Run '${MAIN_SCRIPT} group <sub-command> --help' for details
EOF2
}

@test "_print_command_help omits sub-commands for a plain command" {
  run _print_command_help --command "lint"

  assert_success
  assert_output - <<EOF2
RFC8259 Parsers

Usage: ${MAIN_SCRIPT} lint [options]

Lint summary

Options:
  --write    Enable autofixing
EOF2
}

@test "_print_command_help omits the options block without help lines" {
  run _print_command_help --command "a-very-long-name"

  assert_success
  refute_output --partial "Options:"
}

@test "_print_command_help only lists its own sub-commands" {
  _register_command --command="other" --func-name="_fake_main"
  _register_sub_command --command="other" --sub-command="stray" --func-name="_fake_main" --summary="Stray"

  run _print_command_help --command "group"

  assert_success
  refute_output --partial "stray"
}

@test "_print_command_help accepts the command in any form" {
  run _print_command_help --COMMAND=lint
  assert_success
  assert_output --partial "Lint summary"

  run _print_command_help --Command lint
  assert_success
  assert_output --partial "Lint summary"
}

@test "_print_command_help requires a command" {
  run _print_command_help

  assert_failure
  assert_log --scope "_print_command_help" --level "fatal" "--command is a required parameter"
}

@test "_print_command_help fails for an unregistered command" {
  run _print_command_help --command "bogus"

  assert_failure
  assert_log --scope "_print_command_help" --level "fatal" "Command [bogus] not registered"
}

@test "_print_command_help fails on unknown argument" {
  run _print_command_help --command "lint" --bogus

  assert_failure
  assert_log --scope "_print_command_help" --level "fatal" "Unknown argument [--bogus]"
}

@test "_print_sub_command_help prints the usage, summary and options" {
  run _print_sub_command_help --command "group" --sub-command "one"

  assert_success
  assert_output - <<EOF2
RFC8259 Parsers

Usage: ${MAIN_SCRIPT} group one [options]

First sub-command

Options:
  --list    List things
    [--id]  Thing id
EOF2
}

@test "_print_sub_command_help omits the options block without help lines" {
  run _print_sub_command_help --command "group" --sub-command "second-sub"

  assert_success
  assert_output - <<EOF2
RFC8259 Parsers

Usage: ${MAIN_SCRIPT} group second-sub [options]

Second sub-command
EOF2
}

@test "_print_sub_command_help accepts arguments in any form" {
  run _print_sub_command_help --COMMAND group --Sub-Command=one

  assert_success
  assert_output --partial "First sub-command"
}

@test "_print_sub_command_help requires a command" {
  run _print_sub_command_help --sub-command "one"

  assert_failure
  assert_log --scope "_print_sub_command_help" --level "fatal" "--command is a required parameter"
}

@test "_print_sub_command_help requires a sub-command" {
  run _print_sub_command_help --command "group"

  assert_failure
  assert_log --scope "_print_sub_command_help" --level "fatal" "--sub-command is a required parameter"
}

@test "_print_sub_command_help fails for an unregistered sub-command" {
  run _print_sub_command_help --command "group" --sub-command "bogus"

  assert_failure
  assert_log --scope "_print_sub_command_help" --level "fatal" "Sub-command [group:bogus] not registered"
}

@test "_print_sub_command_help fails on unknown argument" {
  run _print_sub_command_help --command "group" --sub-command "one" --bogus

  assert_failure
  assert_log --scope "_print_sub_command_help" --level "fatal" "Unknown argument [--bogus]"
}
