#!/usr/bin/env bash

_unit_setup() {
  load "../../helpers/common_setup"
  load "../helpers/log_fixture"
  load "../helpers/stub_fixture"

  _common_setup
  _stub_setup

  # color.bash requires a terminal that supports colors
  export TERM="xterm-256color"

  MAIN_SCRIPT="${PROJECT_ROOT}/main.bash"
  SCRIPTS_ROOT="${PROJECT_ROOT}/scripts"
  # Scripts resolve tool binaries from here, so tests never touch the real modules
  MODULES_ROOT="${BATS_TEST_TMPDIR}/modules"
  # shellcheck source=scripts/shared/color.bash
  source "${SCRIPTS_ROOT}/shared/color.bash"
  # shellcheck source=scripts/shared/log.bash
  source "${SCRIPTS_ROOT}/shared/log.bash"
  # shellcheck source=scripts/shared/commander.bash
  source "${SCRIPTS_ROOT}/shared/commander.bash"
  _unit_load_main_functions
}

# main.bash runs _main when sourced, so only its function definitions are loaded
_unit_load_main_functions() {
  # shellcheck source=/dev/null
  source <(sed -n '/^_[a-z_]*() {$/,/^}$/p' "${PROJECT_ROOT}/main.bash")
}

# Sources a script from the scripts directory, e.g. "check" or "shared/fetch"
_unit_source_script() {
  # shellcheck source=/dev/null
  source "${SCRIPTS_ROOT}/${1}.bash"
}
