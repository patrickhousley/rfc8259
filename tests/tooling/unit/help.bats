#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

  _unit_setup
  _unit_source_script "help"
}

@test "registers the help command" {
  assert_equal "${COMMANDS[*]}" "help"
  assert_equal "${COMMAND_REGISTRY["help:func_name"]}" "_help_main"
  assert_equal "${COMMAND_REGISTRY["help:summary"]}" "Prints this help information"
}

@test "_help_main prints usage and registered commands" {
  _register_command --command="fake" --func-name="_fake_main" --summary="Fake summary" \
    --help="-a/--alpha   First option" \
    --help="-b/--beta    Second option"

  run _help_main

  assert_success
  assert_output - <<EOF
RFC8259 Parsers

Example: ${MAIN_SCRIPT} command [command_args]

Commands:
  help                  Prints this help information

  fake                  Fake summary
    -a/--alpha   First option
    -b/--beta    Second option
EOF
}

@test "_help_main wraps the summary of long command names" {
  _register_command --command="a-very-long-name" --func-name="_fake_main" --summary="Long summary"

  run _help_main

  assert_success
  assert_output --partial - <<EOF
  a-very-long-name
                        Long summary
EOF
}

@test "_help_main aligns summaries of short and long command names" {
  _register_command --command="a-very-long-name" --func-name="_fake_main" --summary="Long summary"

  run _help_main

  assert_line "  help                  Prints this help information"
  assert_line "                        Long summary"
}
