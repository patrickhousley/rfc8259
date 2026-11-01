#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

  _unit_setup

  SHELLCHECK_BIN="${MODULES_ROOT}/shellcheck/shellcheck"
  _stub_shellcheck
  _unit_source_script "lint"

  stub_command "git"
  PATH="${STUB_BIN}:${PATH}"

  FIXTURE_ROOT="${BATS_TEST_TMPDIR}/project"
  mkdir -p "${FIXTURE_ROOT}/sub" "${FIXTURE_ROOT}/modules/dep"
  touch "${FIXTURE_ROOT}/a.bash" \
    "${FIXTURE_ROOT}/sub/b.bats" \
    "${FIXTURE_ROOT}/c.sh" \
    "${FIXTURE_ROOT}/modules/d.bash" \
    "${FIXTURE_ROOT}/modules/dep/e.bats"
  cd "${FIXTURE_ROOT}" || return 1
}

# Installs a stub shellcheck where lint.bash expects the downloaded module binary
_stub_shellcheck() {
  stub_command "shellcheck" "${1:-exit 0}"
  mkdir -p "$(dirname "${SHELLCHECK_BIN}")"
  mv "${STUB_BIN}/shellcheck" "${SHELLCHECK_BIN}"
}

# Replaces the shellcheck stub with one that outputs a diff on the first call only
_stub_shellcheck_diff_once() {
  _stub_shellcheck "$(
    cat <<EOF
if [[ ! -e "${STUB_BIN}/shellcheck.state" ]]; then
  : >"${STUB_BIN}/shellcheck.state"
  printf '%s\n' '--- a/./a.bash' '+++ b/./a.bash'
fi
EOF
  )"
}

@test "registers the lint command" {
  assert_equal "${COMMANDS[*]}" "lint"
  assert_equal "${COMMAND_REGISTRY["lint:func_name"]}" "_lint_main"
  assert_equal "${COMMAND_REGISTRY["lint:help"]}" "1"
}

@test "uses the shellcheck binary from the modules directory" {
  assert_equal "${SHELLCHECK_MODULE_BIN}" "${SHELLCHECK_BIN}"
}

@test "_lint_main downloads shellcheck when it is missing" {
  rm "${SHELLCHECK_BIN}"
  # shellcheck disable=SC2329
  _module_download() {
    echo "download [$*]"
    _stub_shellcheck
  }

  run _lint_main

  assert_success
  assert_line --regexp '^download \[--name=shellcheck --download-url=https://github.com/koalaman/shellcheck/releases/download/v[0-9.]+/shellcheck-v[0-9.]+\.linux\.x86_64\.tar\.gz --sha256=[0-9a-f]{64} --tar\]$'
}

@test "_lint_main does not download shellcheck when it is installed" {
  # shellcheck disable=SC2329
  _module_download() {
    echo "download"
  }

  run _lint_main

  assert_success
  refute_output --partial "download"
}

@test "_lint_main makes shellcheck executable" {
  chmod -x "${SHELLCHECK_BIN}"

  # chmod must persist so this cannot run in a subshell
  _lint_main >/dev/null

  [[ -x "${SHELLCHECK_BIN}" ]]
}

@test "_lint_main fails on unknown argument" {
  run _lint_main "--bogus"

  assert_failure
  assert_log --scope "_lint_main" --level "fatal" "Unknown command argument [--bogus]"
  assert_equal "$(stub_calls shellcheck)" ""
}

@test "_lint_main runs shellcheck in check mode" {
  run _lint_main

  assert_success
  assert_log --scope "_lint_main" --level "success" "Repository files linted"
  assert_equal "$(stub_calls shellcheck | wc -l)" "1"
  run stub_calls shellcheck
  assert_output --regexp '^--format tty '
}

@test "_lint_main fails when shellcheck fails" {
  _stub_shellcheck "exit 1"

  run _lint_main

  assert_failure
  assert_log --scope "_lint_main" --level "fatal" "Repository files have lint errors"
}

@test "_lint_main runs shellcheck in write mode" {
  local flag
  for flag in --write --WRITE; do
    rm -f "${STUB_BIN}/shellcheck.calls"

    run _lint_main "${flag}"

    assert_success
    assert_log --scope "_lint_main" --level "success" "Repository files linted"
    run stub_calls shellcheck
    assert_output --regexp '^--format diff '
  done
}

@test "_lint_main logs the mode when verbose" {
  LOG_VERBOSE=0

  run _lint_main
  assert_log --scope "_lint_main" --level "verbose" "Running shellcheck in check mode..."

  run _lint_main --write
  assert_log --scope "_lint_main" --level "verbose" "Running shellcheck in write mode..."
}

@test "_lint_shellcheck_run checks bash and bats files outside of modules" {
  run _lint_shellcheck_run

  assert_success
  run stub_calls shellcheck
  assert_output --partial "./a.bash"
  assert_output --partial "./sub/b.bats"
  refute_output --partial "c.sh"
  refute_output --partial "d.bash"
  refute_output --partial "e.bats"
}

@test "_lint_shellcheck_run passes the output format" {
  run _lint_shellcheck_run "gcc"

  run stub_calls shellcheck
  assert_output --regexp '^--format gcc '
}

@test "_lint_shellcheck_run returns the shellcheck exit code" {
  _stub_shellcheck "exit 1"

  run _lint_shellcheck_run

  assert_failure
}

@test "_lint_shellcheck_write_diff writes stdout and stderr to separate files" {
  _stub_shellcheck 'echo "patch"; echo "problem" >&2; exit 1'

  run _lint_shellcheck_write_diff "${BATS_TEST_TMPDIR}/out.patch"

  assert_success
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/out.patch")" "patch"
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/out.patch.err")" "problem"
}

@test "_lint_shellcheck_apply_diff skips empty patches" {
  : >"${BATS_TEST_TMPDIR}/empty.patch"

  run _lint_shellcheck_apply_diff "${BATS_TEST_TMPDIR}/empty.patch"

  assert_success
  assert_equal "$(stub_calls git)" ""
}

@test "_lint_shellcheck_apply_diff applies the patch with git" {
  echo "patch" >"${BATS_TEST_TMPDIR}/fix.patch"

  run _lint_shellcheck_apply_diff "${BATS_TEST_TMPDIR}/fix.patch"

  assert_success
  assert_equal "$(stub_calls git)" "apply ${BATS_TEST_TMPDIR}/fix.patch"
}

@test "_lint_shellcheck_apply_diff returns the git exit code" {
  echo "patch" >"${BATS_TEST_TMPDIR}/fix.patch"
  stub_command "git" "exit 3"

  run _lint_shellcheck_apply_diff "${BATS_TEST_TMPDIR}/fix.patch"

  assert_failure 3
}

@test "_lint_shellcheck_write_loop stops when there is nothing to fix" {
  run _lint_shellcheck_write_loop

  assert_success
  assert_equal "$(stub_calls shellcheck | wc -l)" "1"
  assert_equal "$(stub_calls git)" ""
}

@test "_lint_shellcheck_write_loop applies fixes until none remain" {
  _stub_shellcheck_diff_once
  stub_command "git" "cp \"\$2\" \"${BATS_TEST_TMPDIR}/applied.patch\""

  run _lint_shellcheck_write_loop

  assert_success
  assert_equal "$(stub_calls shellcheck | wc -l)" "2"
  assert_equal "$(stub_calls git | wc -l)" "1"
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/applied.patch")" $'--- a/a.bash\n+++ b/a.bash'
}

@test "_lint_shellcheck_write_loop fails when git cannot apply fixes" {
  _stub_shellcheck_diff_once
  stub_command "git" "exit 1"

  run _lint_shellcheck_write_loop

  assert_failure
  assert_equal "$(stub_calls git | wc -l)" "1"
}

@test "_lint_shellcheck_write_loop logs unfixable errors" {
  _stub_shellcheck \
    'echo "./a.bash: issues were detected, but none were auto-fixable. Use another format to see them." >&2; exit 1'

  run _lint_shellcheck_write_loop

  assert_failure
  assert_log --scope "linter" --level "error" \
    "./a.bash: issues were detected, but none were auto-fixable. Use check mode to see them."
  assert_equal "$(stub_calls git)" ""
}

@test "_lint_shellcheck_write_loop removes its temporary files" {
  _stub_shellcheck_diff_once
  export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
  mkdir -p "${TMPDIR}"

  run _lint_shellcheck_write_loop

  assert_success
  assert_equal "$(find "${TMPDIR}" -type f)" ""
}

@test "_lint_shellcheck_fmt_error points unfixable errors at check mode" {
  run _lint_shellcheck_fmt_error "none were auto-fixable. Use another format to see them."

  assert_output "none were auto-fixable. Use check mode to see them."
}

@test "_lint_shellcheck_fmt_error leaves other errors unchanged" {
  run _lint_shellcheck_fmt_error "Use another format to see them."

  assert_output "Use another format to see them."
}
