#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

  _unit_setup
  _unit_source_script "test"

  stub_link "nproc"
  stub_link "mkdir"
  stub_link "rm"
  JOBS="$(nproc)"

  # _test_main only needs the bats binary from the modules directory
  PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
  mkdir -p "${MODULES_ROOT}/bats-core/bin"
  _stub_bats

  CLONES="${BATS_TEST_TMPDIR}/clones"
  # shellcheck disable=SC2329
  _module_git_clone() {
    echo "clone [$*]" >>"${CLONES}"
  }
}

# Writes a stub bats binary into the fake modules directory
_stub_bats() {
  stub_command "bats" "${1:-exit 0}"
  mv "${STUB_BIN}/bats" "${MODULES_ROOT}/bats-core/bin/bats"
}

@test "registers the test command" {
  assert_equal "${COMMANDS[*]}" "test"
  assert_equal "${COMMAND_REGISTRY["test:func_name"]}" "_test_main"
  assert_equal "${COMMAND_REGISTRY["test:summary"]}" "Runs tests using bats"
}

@test "_test_main clones the bats modules" {
  run_with_path "${STUB_BIN}" _test_main

  assert_success
  run cat "${CLONES}"
  assert_output - <<EOF
clone [--name=bats-core --clone-uri=https://github.com/bats-core/bats-core.git --ref=master]
clone [--name=bats-support --clone-uri=https://github.com/bats-core/bats-support.git --ref=master]
clone [--name=bats-assert --clone-uri=https://github.com/bats-core/bats-assert.git --ref=master]
EOF
}

@test "_test_main does not run bats when a clone fails" {
  _module_git_clone() {
    _log "_module_git_clone" "Git clone failed" "fatal"
  }

  run_with_path "${STUB_BIN}" _test_main

  assert_failure
  assert_equal "$(stub_calls bats)" ""
}

@test "_test_main runs every test under the project tests directory" {
  run_with_path "${STUB_BIN}" _test_main

  assert_success
  run stub_calls bats
  assert_output --regexp " -rp ${PROJECT_ROOT}/tests/\$|^-rp ${PROJECT_ROOT}/tests/\$"
}

@test "_test_main runs bats in parallel when GNU parallel is installed" {
  stub_command "parallel"

  run_with_path "${STUB_BIN}" _test_main

  assert_success
  assert_equal "$(stub_calls bats)" "-j ${JOBS} -rp ${PROJECT_ROOT}/tests/"
}

@test "_test_main runs bats serially when GNU parallel is not installed" {
  run_with_path "${STUB_BIN}" _test_main

  assert_success
  assert_equal "$(stub_calls bats)" "-rp ${PROJECT_ROOT}/tests/"
}

@test "_test_main returns the bats exit code" {
  _stub_bats "exit 1"

  run_with_path "${STUB_BIN}" _test_main

  assert_failure 1
}

@test "_test_main fails on unknown argument" {
  run_with_path "${STUB_BIN}" _test_main --bogus

  assert_failure
  assert_log --scope "_test_main" --level "fatal" "Unknown argument [--bogus]"
  assert_equal "$(stub_calls bats)" ""
}

@test "_test_main recreates the reports directory" {
  mkdir -p "${REPORTS_ROOT}/stale"
  touch "${REPORTS_ROOT}/stale/old.xml"

  run_with_path "${STUB_BIN}" _test_main

  assert_success
  assert [ -d "${REPORTS_ROOT}" ]
  assert [ ! -e "${REPORTS_ROOT}/stale" ]
}

@test "_test_main keeps the reports directory when arguments are invalid" {
  mkdir -p "${REPORTS_ROOT}"
  touch "${REPORTS_ROOT}/old.xml"

  run_with_path "${STUB_BIN}" _test_main --bogus

  assert_failure
  assert [ -e "${REPORTS_ROOT}/old.xml" ]
}

@test "_test_main writes a JUnit report to the reports directory" {
  run_with_path "${STUB_BIN}" _test_main --junit

  assert_success
  assert [ -d "${REPORTS_ROOT}/junit" ]
  assert_equal "$(stub_calls bats)" "-rp --report-formatter junit -o ${REPORTS_ROOT}/junit ${PROJECT_ROOT}/tests/"
}

@test "_test_main accepts flags in any case" {
  stub_command "kcov"

  run_with_path "${STUB_BIN}" _test_main --JUNIT --Coverage

  assert_success
  assert_equal "$(stub_calls kcov)" "--include-path=${PROJECT_ROOT}/main.bash,${PROJECT_ROOT}/scripts ${REPORTS_ROOT}/coverage ${MODULES_ROOT}/bats-core/bin/bats -rp --report-formatter junit -o ${REPORTS_ROOT}/junit ${PROJECT_ROOT}/tests/"
}

@test "_test_main keeps running tests in parallel when writing a JUnit report" {
  stub_command "parallel"

  run_with_path "${STUB_BIN}" _test_main --junit

  assert_success
  assert_equal "$(stub_calls bats)" "-j ${JOBS} -rp --report-formatter junit -o ${REPORTS_ROOT}/junit ${PROJECT_ROOT}/tests/"
}

@test "_test_main runs bats under kcov with coverage" {
  stub_command "kcov"

  run_with_path "${STUB_BIN}" _test_main --coverage

  assert_success
  assert_equal "$(stub_calls kcov)" "--include-path=${PROJECT_ROOT}/main.bash,${PROJECT_ROOT}/scripts ${REPORTS_ROOT}/coverage ${MODULES_ROOT}/bats-core/bin/bats -rp ${PROJECT_ROOT}/tests/"
}

@test "_test_main runs coverage serially even when GNU parallel is installed" {
  stub_command "parallel"
  stub_command "kcov"

  run_with_path "${STUB_BIN}" _test_main --coverage

  assert_success
  refute_output --partial "-j"
  assert_equal "$(stub_calls kcov)" "--include-path=${PROJECT_ROOT}/main.bash,${PROJECT_ROOT}/scripts ${REPORTS_ROOT}/coverage ${MODULES_ROOT}/bats-core/bin/bats -rp ${PROJECT_ROOT}/tests/"
}

@test "_test_main requires kcov for coverage" {
  run_with_path "${STUB_BIN}" _test_main --coverage

  assert_failure
  assert_log --scope "_test_main" --level "fatal" "kcov is required for --coverage"
  assert_equal "$(stub_calls bats)" ""
  assert [ ! -e "${CLONES}" ]
}

@test "_test_main does not require kcov without coverage" {
  run_with_path "${STUB_BIN}" _test_main

  assert_success
}
