#!/usr/bin/env bats

setup() {
  load 'helpers/unit_setup'

  _unit_setup

  SHFMT_BIN="${MODULES_ROOT}/shfmt/shfmt_v3.14.1_linux_amd64"
  _stub_shfmt
  _unit_source_script "format"
}

# Installs a stub shfmt where format.bash expects the downloaded module binary
_stub_shfmt() {
  stub_command "shfmt" "${1:-exit 0}"
  mkdir -p "$(dirname "${SHFMT_BIN}")"
  mv "${STUB_BIN}/shfmt" "${SHFMT_BIN}"
}

@test "registers the format command" {
  assert_equal "${COMMANDS[*]}" "format"
  assert_equal "${COMMAND_REGISTRY["format:func_name"]}" "_format_main"
  assert_equal "${COMMAND_REGISTRY["format:help"]}" "1"
}

@test "uses the shfmt binary from the modules directory" {
  assert_equal "${SHFMT_MODULE_BIN}" "${SHFMT_BIN}"
}

@test "_format_main downloads shfmt when it is missing" {
  rm "${SHFMT_BIN}"
  # shellcheck disable=SC2329
  _module_download() {
    echo "download [$*]"
    _stub_shfmt
  }

  run _format_main

  assert_success
  assert_line --regexp '^download \[--name=shfmt --download-url=https://github.com/mvdan/sh/releases/download/v[0-9.]+/shfmt_v[0-9.]+_linux_amd64 --sha256=[0-9a-f]{64}\]$'
  assert_equal "$(stub_calls shfmt)" "-d ${PROJECT_ROOT}"
}

@test "_format_main does not download shfmt when it is installed" {
  # shellcheck disable=SC2329
  _module_download() {
    echo "download"
  }

  run _format_main

  assert_success
  refute_output --partial "download"
}

@test "_format_main makes shfmt executable" {
  chmod -x "${SHFMT_BIN}"
  [[ ! -x "${SHFMT_BIN}" ]]

  # chmod must persist so this cannot run in a subshell
  _format_main >/dev/null

  [[ -x "${SHFMT_BIN}" ]]
}

@test "_format_main fails on unknown argument" {
  run _format_main "--bogus"

  assert_failure
  assert_log --level "fatal" "Unknown command argument [--bogus]"
  assert_equal "$(stub_calls shfmt)" ""
}

@test "_format_main reports unknown arguments with its own scope" {
  run _format_main "--bogus"

  assert_log --scope "_format_main" --level "fatal" "Unknown command argument [--bogus]"
}

@test "_format_main runs shfmt in check mode" {
  run _format_main

  assert_success
  assert_log --scope "_format_main" --level "success" "Repository files formatted"
  assert_equal "$(stub_calls shfmt)" "-d ${PROJECT_ROOT}"
}

@test "_format_main runs shfmt in write mode" {
  local flag
  for flag in --write --WRITE; do
    rm -f "${STUB_BIN}/shfmt.calls"

    run _format_main "${flag}"

    assert_success
    assert_log --scope "_format_main" --level "success" "Repository files formatted"
    assert_equal "$(stub_calls shfmt)" "-w ${PROJECT_ROOT}"
  done
}

@test "_format_main fails when shfmt fails" {
  _stub_shfmt "exit 1"

  run _format_main

  assert_failure
  assert_log --scope "_format_main" --level "fatal" "Repository files are not properly formatted"
}

@test "_format_main logs the mode when verbose" {
  LOG_VERBOSE=0

  run _format_main
  assert_log --scope "_format_main" --level "verbose" "Running shfmt in check mode..."

  run _format_main --write
  assert_log --scope "_format_main" --level "verbose" "Running shfmt in write mode..."
}
