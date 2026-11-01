#!/usr/bin/env bash
set -euo pipefail

_register_command \
  --command="test" \
  --func-name="_test_main" \
  --summary="Runs tests using bats"

_test_main() {
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

  if command parallel --version >/dev/null 2>&1; then
    "${MODULES_ROOT}/bats-core/bin/bats" -j "$(nproc)" -rp "${PROJECT_ROOT}/tests/"
  else
    "${MODULES_ROOT}/bats-core/bin/bats" -rp "${PROJECT_ROOT}/tests/"
  fi
}
