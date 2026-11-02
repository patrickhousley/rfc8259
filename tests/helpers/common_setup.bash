#!/usr/bin/env bash

_common_setup() {
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
  PATH="$PROJECT_ROOT:$PATH"

  load "$PROJECT_ROOT/modules/bats-assert/load"
  load "$PROJECT_ROOT/modules/bats-support/load"
}
