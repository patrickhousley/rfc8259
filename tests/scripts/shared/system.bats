#!/usr/bin/env bats

setup() {
  load '../../helpers/unit_setup'

  _unit_setup
  _unit_source_script "shared/system"

  _stub_system_binaries
}

# Stubs every required binary reporting exactly its minimum version, so each test only changes what it checks
_stub_system_binaries() {
  local entry
  local binary
  local min_version
  for entry in "${SYSTEM_REQUIRED_BINARIES[@]}"; do
    binary="${entry%%:*}"
    min_version="${entry#*:}"
    stub_command "${binary}" "echo '${binary} version ${min_version:-1.0.0}'"
  done
}

# Runs validation with only the stubbed binaries on the PATH
_validate_with_stubs() {
  run_with_path "${STUB_BIN}" _system_validate
}

@test "_system_version_gte compares numeric parts" {
  local pair
  for pair in "1.0.0 1.0.0" "1.0.1 1.0.0" "1.1.0 1.0.9" "2.0.0 1.9.9" "7.100.0 7.76.0" "8 7.76.0" "7.76 7.76.0" "7.76.0 7.76"; do
    # shellcheck disable=SC2086
    run _system_version_gte ${pair}
    assert_success
  done
}

@test "_system_version_gte fails for older versions" {
  local pair
  for pair in "1.0.0 1.0.1" "1.0.9 1.1.0" "1.9.9 2.0.0" "7.9.0 7.76.0" "7 7.76.0" "7.76 7.76.1"; do
    # shellcheck disable=SC2086
    run _system_version_gte ${pair}
    assert_failure
  done
}

@test "_system_version_gte treats leading zeros as decimal" {
  run _system_version_gte "2.08.0" "2.8.0"
  assert_success

  run _system_version_gte "2.8.0" "2.08.0"
  assert_success
}

@test "_system_binary_version prints the first version in the output" {
  stub_command "fake" "echo 'fake (GNU fake) 3.14.15 built with libfoo 9.9'"

  run_with_path "${STUB_BIN}" _system_binary_version fake

  assert_success
  assert_output "3.14.15"
}

@test "_system_binary_version fails without a version in the output" {
  stub_command "fake" "echo 'no numbers here'"

  run_with_path "${STUB_BIN}" _system_binary_version fake

  assert_failure
}

@test "_system_binary_version reads the version when the binary exits non zero" {
  stub_command "fake" "echo 'fake 1.2.3'; exit 2"

  run_with_path "${STUB_BIN}" _system_binary_version fake

  assert_success
  assert_output "1.2.3"
}

@test "requires curl 7.76.0 for --fail-with-body" {
  assert_equal "${SYSTEM_REQUIRED_BINARIES[0]}" "curl:7.76.0"
}

@test "_system_validate passes when requirements are met" {
  _validate_with_stubs

  assert_success
  assert_output ""
}

@test "_system_validate accepts newer versions" {
  stub_command "curl" "echo 'curl 8.23.0 (x86_64-pc-linux-gnu) libcurl/8.23.0'"
  stub_command "git" "echo 'git version 2.56.0'"

  _validate_with_stubs

  assert_success
}

@test "_system_validate fails when a binary is missing" {
  rm "${STUB_BIN}/tar"

  _validate_with_stubs

  assert_failure
  assert_log --scope "system" --level "error" "Required binary [tar] was not found"
  assert_log --scope "system" --level "fatal" "System requirements not met"
}

@test "_system_validate fails when a binary is older than required" {
  stub_command "curl" "echo 'curl 7.75.0'"

  _validate_with_stubs

  assert_failure
  assert_log --scope "system" --level "error" "[curl] 7.75.0 is older than the required 7.76.0"
  assert_log --scope "system" --level "fatal" "System requirements not met"
}

@test "_system_validate fails when the version cannot be determined" {
  stub_command "git" "echo 'unknown'"

  _validate_with_stubs

  assert_failure
  assert_log --scope "system" --level "error" "Could not determine the version of [git], 2.0.0 or newer is required"
}

@test "_system_validate reports every problem" {
  rm "${STUB_BIN}/tar" "${STUB_BIN}/awk"
  stub_command "curl" "echo 'curl 7.0.0'"

  _validate_with_stubs

  assert_failure
  assert_log --scope "system" --level "error" "Required binary [tar] was not found"
  assert_log --scope "system" --level "error" "Required binary [awk] was not found"
  assert_log --scope "system" --level "error" "[curl] 7.0.0 is older than the required 7.76.0"
}

@test "_system_validate fails when bash is too old" {
  SYSTEM_MIN_BASH_VERSION="99.0.0"

  _validate_with_stubs

  assert_failure
  assert_log --scope "system" --level "error" --partial "is older than the required 99.0.0"
}

@test "_system_validate allows missing data and modules directories" {
  assert [ ! -e "${DATA_ROOT}" ]
  assert [ ! -e "${MODULES_ROOT}" ]

  _validate_with_stubs

  assert_success
}

@test "_system_validate allows existing writable directories" {
  mkdir -p "${DATA_ROOT}" "${MODULES_ROOT}"

  _validate_with_stubs

  assert_success
}

@test "_system_validate fails when an existing directory is not writable" {
  [[ $EUID -ne 0 ]] || skip "root can write to any directory"
  mkdir -p "${DATA_ROOT}"
  chmod a-w "${DATA_ROOT}"

  _validate_with_stubs

  assert_failure
  assert_log --scope "system" --level "error" "Directory [${DATA_ROOT}] is not writable"
}

@test "_system_validate fails when a missing directory cannot be created" {
  [[ $EUID -ne 0 ]] || skip "root can write to any directory"
  mkdir -p "${BATS_TEST_TMPDIR}/locked"
  chmod a-w "${BATS_TEST_TMPDIR}/locked"
  DATA_ROOT="${BATS_TEST_TMPDIR}/locked/data"

  _validate_with_stubs

  assert_failure
  assert_log --scope "system" --level "error" "Directory [${DATA_ROOT}] cannot be created, [${BATS_TEST_TMPDIR}/locked] is not writable"
}

@test "_system_validate fails when the parent of a missing directory does not exist" {
  MODULES_ROOT="${BATS_TEST_TMPDIR}/missing/modules"

  _validate_with_stubs

  assert_failure
  assert_log --scope "system" --level "error" "Directory [${MODULES_ROOT}] cannot be created, [${BATS_TEST_TMPDIR}/missing] is not writable"
}
