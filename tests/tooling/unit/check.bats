#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

  _unit_setup
  _unit_source_script "check"

  # shellcheck disable=SC2329
  _format_main() {
    echo "format [$*]"
  }
  # shellcheck disable=SC2329
  _lint_main() {
    echo "lint [$*]"
  }
}

@test "registers the check command" {
  assert_equal "${COMMANDS[*]}" "check"
  assert_equal "${COMMAND_REGISTRY["check:func_name"]}" "_check_main"
  assert_equal "${COMMAND_REGISTRY["check:help"]}" "1"
}

@test "_check_main runs format then lint in check mode" {
  run _check_main

  assert_success
  assert_output - <<EOF
format []
lint []
EOF
}

@test "_check_main runs format then lint in write mode" {
  local flag
  for flag in -w --write -W --WRITE; do
    run _check_main "${flag}"

    assert_success
    assert_output - <<EOF
format [--write]
lint [--write]
EOF
  done
}

@test "_check_main fails on unknown argument" {
  run _check_main "--bogus"

  assert_failure
  assert_log --scope "check" --level "fatal" "Unknown command argument [--bogus]"
  refute_output --partial "format"
}

@test "_check_main stops when format fails" {
  _format_main() {
    _log "formatter" "failed" "fatal"
  }

  run _check_main

  assert_failure
  refute_output --partial "lint"
}
