#!/usr/bin/env bash

_common_setup() {
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
  PATH="$PROJECT_ROOT:$PATH"

  load "$PROJECT_ROOT/modules/bats-assert/load"
  load "$PROJECT_ROOT/modules/bats-support/load"

  _common_setup_kcov_run
}

# kcov traces bash with a DEBUG trap and functrace, and bats' run clears both, which hides everything
# executed under run from the coverage report. Under kcov, run is wrapped so the traced command
# re-arms them. Without kcov the bats run is left untouched.
_common_setup_kcov_run() {
  if [[ -z "${KCOV_BASH_XTRACEFD:-}" ]]; then
    return 0
  fi

  if ! declare -F _bats_run >/dev/null; then
    eval "$(declare -f run | sed '1s/^run /_bats_run /')"
  fi

  # shellcheck disable=SC2329
  run() {
    local flags=()
    while [[ $# -gt 0 && ($1 == -* || $1 == '!') ]]; do
      flags+=("$1")
      if [[ $1 == -- ]]; then
        shift 1
        break
      fi
      shift 1
    done

    KCOV_DEBUG_TRAP="$(trap -p DEBUG)"
    _bats_run ${flags[@]+"${flags[@]}"} _common_setup_kcov_traced "$@"
  }
}

_common_setup_kcov_traced() {
  set -T
  eval "${KCOV_DEBUG_TRAP}"
  "$@"
}
