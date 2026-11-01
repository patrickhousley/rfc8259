#!/usr/bin/env bash

# Creates the directory stub executables are written to
_stub_setup() {
  STUB_BIN="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${STUB_BIN}"
}

# Writes an executable to $STUB_BIN which records its arguments then runs the given body
#
# Usage: stub_command <name> [body]
stub_command() {
  local name="${1}"
  local body="${2:-exit 0}"

  {
    printf '#!%s\n' "${BASH}"
    printf 'printf "%%s\\n" "$*" >>%q\n' "${STUB_BIN}/${name}.calls"
    printf '%s\n' "${body}"
  } >"${STUB_BIN}/${name}"
  chmod +x "${STUB_BIN}/${name}"
}

# Exposes a real binary in $STUB_BIN for tests that run with an isolated PATH
#
# Usage: stub_link <name>
stub_link() {
  ln -s "$(command -v "${1}")" "${STUB_BIN}/${1}"
}

# Prints the arguments of every call made to a stub, one call per line
#
# Usage: stub_calls <name>
stub_calls() {
  if [[ -f "${STUB_BIN}/${1}.calls" ]]; then
    cat "${STUB_BIN}/${1}.calls"
  fi
}

# Runs a command with PATH replaced, restoring it afterwards
#
# Usage: run_with_path <path> <command> [args...]
run_with_path() {
  local -x PATH="${1}"
  shift 1

  hash -r
  run "$@"
  hash -r
}
