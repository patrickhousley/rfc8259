#!/usr/bin/env bash
set -euo pipefail

_register_command \
  --command="test" \
  --func-name="_test_main" \
  --summary="Runs tests using bats" \
  --help="--junit      Write a JUnit report to the reports directory" \
  --help="--coverage   Write a kcov coverage report to the reports directory (requires kcov)"

_test_main() {
  local junit=0
  local coverage=0

  while [[ $# -gt 0 ]]; do
    case "${1,,}" in
    --junit)
      junit=1
      shift 1
      ;;
    --coverage)
      coverage=1
      shift 1
      ;;
    *)
      _log "_test_main" "Unknown argument [${1}]" "fatal"
      ;;
    esac
  done

  if [[ $coverage -eq 1 ]] && ! command -v kcov >/dev/null 2>&1; then
    _log "_test_main" "kcov is required for --coverage" "fatal"
  fi

  rm -rf "${REPORTS_ROOT:?}"
  mkdir -p "${REPORTS_ROOT}"

  _module_git_clone \
    --name="bats-core" \
    --clone-uri="https://github.com/bats-core/bats-core.git" \
    --ref="master"
  _module_git_clone \
    --name="bats-support" \
    --clone-uri="https://github.com/bats-core/bats-support.git" \
    --ref="master"
  _module_git_clone \
    --name="bats-assert" \
    --clone-uri="https://github.com/bats-core/bats-assert.git" \
    --ref="master"

  local bats_args=()
  # kcov traces a single process tree, so coverage runs are serial
  if [[ $coverage -eq 0 ]] && command parallel --version >/dev/null 2>&1; then
    bats_args+=(-j "$(nproc)")
  fi
  bats_args+=(-rp)
  if [[ $junit -eq 1 ]]; then
    mkdir -p "${REPORTS_ROOT}/junit"
    bats_args+=(--report-formatter junit -o "${REPORTS_ROOT}/junit")
  fi
  bats_args+=("${PROJECT_ROOT}/tests/")

  if [[ $coverage -eq 1 ]]; then
    kcov \
      --include-path="${PROJECT_ROOT}/main.bash,${PROJECT_ROOT}/scripts" \
      "${REPORTS_ROOT}/coverage" \
      "${MODULES_ROOT}/bats-core/bin/bats" "${bats_args[@]}"
  else
    "${MODULES_ROOT}/bats-core/bin/bats" "${bats_args[@]}"
  fi
}
