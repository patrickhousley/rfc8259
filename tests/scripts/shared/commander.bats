#!/usr/bin/env bats

setup() {
  load '../../helpers/unit_setup'

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

  run _check_command_exists "fake"
  assert_success
}

@test "_check_command_exists fails for unregistered commands" {
  run _check_command_exists "fake"

  assert_failure
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

@test "_check_sub_command_exists finds registered sub-commands" {
  _register_command --command="fake" --func-name="_fake_main"
  _register_sub_command --command="fake" --sub-command="sub" --func-name="_fake_sub_main"

  run _check_sub_command_exists "fake:sub"
  assert_success
}

@test "_check_sub_command_exists fails for unregistered sub-commands" {
  run _check_sub_command_exists "fake:sub"

  assert_failure
}

@test "_register_sub_command stores the sub-command" {
  _register_command --command="fake" --func-name="_fake_main"
  _register_sub_command --command="fake" --sub-command="sub" --func-name="_fake_sub_main" --summary="sub summary"

  assert_equal "${SUB_COMMAND_REGISTRY["fake:sub"]}" "fake:sub"
  assert_equal "${SUB_COMMAND_REGISTRY["fake:sub:func_name"]}" "_fake_sub_main"
  assert_equal "${SUB_COMMAND_REGISTRY["fake:sub:summary"]}" "sub summary"
  assert_equal "${SUB_COMMAND_REGISTRY["fake:sub:help"]}" "0"
}

@test "_register_sub_command stores help lines" {
  _register_command --command="fake" --func-name="_fake_main"
  _register_sub_command --command="fake" --sub-command="sub" --func-name="_fake_sub_main" --help="line one" --help="line two"

  assert_equal "${SUB_COMMAND_REGISTRY["fake:sub:help"]}" "2"
  assert_equal "${SUB_COMMAND_REGISTRY["fake:sub:help:0"]}" "line one"
  assert_equal "${SUB_COMMAND_REGISTRY["fake:sub:help:1"]}" "line two"
}

@test "_register_sub_command accepts space separated flags in any case" {
  _register_command --command="fake" --func-name="_fake_main"
  _register_sub_command --COMMAND fake --Sub-Command sub --Func-Name _fake_sub_main --summary "a summary" --help "line one"

  assert_equal "${SUB_COMMAND_REGISTRY["fake:sub:func_name"]}" "_fake_sub_main"
  assert_equal "${SUB_COMMAND_REGISTRY["fake:sub:summary"]}" "a summary"
  assert_equal "${SUB_COMMAND_REGISTRY["fake:sub:help:0"]}" "line one"
}

@test "_register_sub_command allows the same sub-command under different commands" {
  _register_command --command="one" --func-name="_fake_main"
  _register_command --command="two" --func-name="_fake_main"
  _register_sub_command --command="one" --sub-command="sub" --func-name="_fake_sub_main"
  _register_sub_command --command="two" --sub-command="sub" --func-name="_fake_sub_main"

  assert_equal "${SUB_COMMAND_REGISTRY["one:sub"]}" "one:sub"
  assert_equal "${SUB_COMMAND_REGISTRY["two:sub"]}" "two:sub"
}

@test "_register_sub_command requires a command" {
  run _register_sub_command --sub-command="sub" --func-name="_fake_sub_main"

  assert_failure
  assert_log --scope "commander" --level "fatal" "--command is a required parameter"
}

@test "_register_sub_command requires a sub-command" {
  run _register_sub_command --command="fake" --func-name="_fake_sub_main"

  assert_failure
  assert_log --scope "commander" --level "fatal" "--sub-command is a required parameter"
}

@test "_register_sub_command requires a function name" {
  run _register_sub_command --command="fake" --sub-command="sub"

  assert_failure
  assert_log --scope "commander" --level "fatal" "--func-name is a required parameter"
}

@test "_register_sub_command requires a registered command" {
  run _register_sub_command --command="fake" --sub-command="sub" --func-name="_fake_sub_main"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Command [fake] not registered"
}

@test "_register_sub_command fails on duplicate sub-command" {
  _register_command --command="fake" --func-name="_fake_main"
  _register_sub_command --command="fake" --sub-command="sub" --func-name="_fake_sub_main"

  run _register_sub_command --command="fake" --sub-command="sub" --func-name="_fake_sub_main"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Sub-command [fake:sub] already registered"
}

@test "_register_sub_command fails on unknown argument" {
  _register_command --command="fake" --func-name="_fake_main"

  run _register_sub_command --command="fake" --bogus

  assert_failure
  assert_log --scope "commander" --level "fatal" "Unknown command argument [--bogus]"
}

@test "_run_command runs the command from the project root with its arguments" {
  # shellcheck disable=SC2329
  _fake_main() {
    echo "pwd=${PWD} args=[$*]"
  }
  _register_command --command="fake" --func-name="_fake_main"
  cd "${BATS_TEST_TMPDIR}"

  run _run_command "fake" "a" "b c"

  assert_success
  assert_output "pwd=${PROJECT_ROOT} args=[a b c]"
}

@test "_run_command fails on unknown command" {
  run _run_command "fake"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Unknown command: fake"
}

@test "_run_command logs the invocation when verbose" {
  _register_command --command="fake" --func-name="_fake_main"
  LOG_VERBOSE=0

  run _run_command "fake" "a" "b"

  assert_success
  assert_log --scope "commander" --level "verbose" "Running _fake_main for command fake with arguments: [a b]"
}

@test "_run_sub_command runs the sub-command from the project root with its arguments" {
  # shellcheck disable=SC2329
  _fake_sub_main() {
    echo "pwd=${PWD} args=[$*]"
  }
  _register_command --command="fake" --func-name="_fake_main"
  _register_sub_command --command="fake" --sub-command="sub" --func-name="_fake_sub_main"
  cd "${BATS_TEST_TMPDIR}"

  run _run_sub_command "fake" "sub" "a" "b c"

  assert_success
  assert_output "pwd=${PROJECT_ROOT} args=[a b c]"
}

@test "_run_sub_command runs the sub-command without arguments" {
  # shellcheck disable=SC2329
  _fake_sub_main() {
    echo "args=[$*]"
  }
  _register_command --command="fake" --func-name="_fake_main"
  _register_sub_command --command="fake" --sub-command="sub" --func-name="_fake_sub_main"

  run _run_sub_command "fake" "sub"

  assert_success
  assert_output "args=[]"
}

@test "_run_sub_command fails on unregistered command" {
  run _run_sub_command "fake" "sub"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Command [fake] not registered"
}

@test "_run_sub_command fails on unregistered sub-command" {
  _register_command --command="fake" --func-name="_fake_main"

  run _run_sub_command "fake" "sub"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Sub-command [fake:sub] not registered"
}

@test "_run_sub_command logs the invocation when verbose" {
  _register_command --command="fake" --func-name="_fake_main"
  _register_sub_command --command="fake" --sub-command="sub" --func-name="_fake_main"
  LOG_VERBOSE=0

  run _run_sub_command "fake" "sub" "a"

  assert_success
  assert_log --scope "commander" --level "verbose" "Running _fake_main for sub-command fake:sub with arguments: [a]"
}

@test "_register_sub_command keeps registration order" {
  _register_command --command="fake" --func-name="_fake_main"
  _register_sub_command --command="fake" --sub-command="b" --func-name="_fake_main"
  _register_sub_command --command="fake" --sub-command="a" --func-name="_fake_main"
  _register_sub_command --command="fake" --sub-command="c" --func-name="_fake_main"

  assert_equal "${SUB_COMMANDS[*]}" "fake:b fake:a fake:c"
}

@test "_command_has_sub_commands is true only for commands with sub-commands" {
  _register_command --command="plain" --func-name="_fake_main"
  _register_command --command="group" --func-name="_fake_main"
  _register_sub_command --command="group" --sub-command="sub" --func-name="_fake_main"

  run _command_has_sub_commands "group"
  assert_success

  run _command_has_sub_commands "plain"
  assert_failure

  run _command_has_sub_commands "unknown"
  assert_failure
}

@test "_command_has_sub_commands does not match a command that only shares a prefix" {
  _register_command --command="group" --func-name="_fake_main"
  _register_command --command="group-two" --func-name="_fake_main"
  _register_sub_command --command="group-two" --sub-command="sub" --func-name="_fake_main"

  run _command_has_sub_commands "group"

  assert_failure
}

@test "_args_request_help finds the help flag in any position and case" {
  run _args_request_help "--help"
  assert_success

  run _args_request_help "a" "--HELP" "b"
  assert_success

  run _args_request_help "a" "b"
  assert_failure

  run _args_request_help
  assert_failure
}

@test "_args_request_help ignores values that only contain help" {
  run _args_request_help "--helpful" "help" "-h"

  assert_failure
}

@test "_run_command prints the command help instead of running it" {
  # shellcheck disable=SC2329
  _fake_main() {
    echo "ran"
  }
  _register_command --command="fake" --func-name="_fake_main" --summary="Fake summary"

  run _run_command "fake" "--help"

  assert_success
  assert_line --regexp "^Usage: .* fake \[options\]$"
  assert_line "Fake summary"
  refute_output --partial "ran"
}

@test "_run_command prints the command help when the flag is not first" {
  # shellcheck disable=SC2329
  _fake_main() {
    echo "ran"
  }
  _register_command --command="fake" --func-name="_fake_main"

  run _run_command "fake" "--write" "--HELP"

  assert_success
  assert_line --regexp "^Usage: .* fake \[options\]$"
  refute_output --partial "ran"
}

@test "_run_command leaves the help flag to commands with sub-commands" {
  # shellcheck disable=SC2329
  _fake_main() {
    echo "ran [$*]"
  }
  _register_command --command="group" --func-name="_fake_main"
  _register_sub_command --command="group" --sub-command="sub" --func-name="_fake_main"

  run _run_command "group" "sub" "--help"

  assert_success
  assert_output "ran [sub --help]"
}

@test "_run_command does not print help without the flag" {
  # shellcheck disable=SC2329
  _fake_main() {
    echo "ran"
  }
  _register_command --command="fake" --func-name="_fake_main"

  run _run_command "fake" "a"

  assert_success
  assert_output "ran"
}

@test "_run_sub_command prints the sub-command help instead of running it" {
  # shellcheck disable=SC2329
  _fake_sub_main() {
    echo "ran"
  }
  _register_command --command="group" --func-name="_fake_main"
  _register_sub_command --command="group" --sub-command="sub" --func-name="_fake_sub_main" \
    --summary="Sub summary" --help="--option  An option"

  run _run_sub_command "group" "sub" "--help"

  assert_success
  assert_line --regexp "^Usage: .* group sub \[options\]$"
  assert_line "Sub summary"
  assert_line "  --option  An option"
  refute_output --partial "ran"
}

@test "_run_sub_command prints the sub-command help when the flag is not first" {
  # shellcheck disable=SC2329
  _fake_sub_main() {
    echo "ran"
  }
  _register_command --command="group" --func-name="_fake_main"
  _register_sub_command --command="group" --sub-command="sub" --func-name="_fake_sub_main"

  run _run_sub_command "group" "sub" "--list" "--Help"

  assert_success
  assert_line --regexp "^Usage: .* group sub \[options\]$"
  refute_output --partial "ran"
}

@test "_run_sub_command prints the command help without a sub-command" {
  _register_command --command="group" --func-name="_fake_main" --summary="Group summary"
  _register_sub_command --command="group" --sub-command="sub" --func-name="_fake_main" --summary="Sub summary"

  run _run_sub_command "group"

  assert_success
  assert_line --regexp "^Usage: .* group <sub-command> "
  assert_line --regexp "^  sub +Sub summary$"
}

@test "_run_sub_command prints the command help for the help flag" {
  _register_command --command="group" --func-name="_fake_main" --summary="Group summary"
  _register_sub_command --command="group" --sub-command="sub" --func-name="_fake_main" --summary="Sub summary"

  run _run_sub_command "group" "--help"

  assert_success
  assert_line --regexp "^Usage: .* group <sub-command> "
}

@test "_run_sub_command fails for an unregistered command even without a sub-command" {
  run _run_sub_command "group"

  assert_failure
  assert_log --scope "commander" --level "fatal" "Command [group] not registered"
}
