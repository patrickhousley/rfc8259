#!/usr/bin/env bats

setup() {
  load '../../helpers/unit_setup'

  _unit_setup
}

@test "defines colors from the terminal" {
  assert_equal "${NC}" "$(tput sgr0)"
  assert_equal "${RED}" "$(tput setaf 1)"
  assert_equal "${GREEN}" "$(tput setaf 2)"
  assert_equal "${YELLOW}" "$(tput setaf 3)"
  assert_equal "${BLUE}" "$(tput setaf 4)"
  assert_equal "${PURPLE}" "$(tput setaf 5)"
  assert_equal "${TURQUOISE}" "$(tput setaf 6)"
  assert_equal "${GREY}" "$(tput setaf 7)"
  assert_equal "${BOLD}" "$(tput bold)"
}

# Runs from a file instead of bash -c because kcov reads BASH_SOURCE, which is unset in a -c string
_write_source_script() {
  printf '%s\n' "source '${SCRIPTS_ROOT}/shared/color.bash' && echo sourced" >"${BATS_TEST_TMPDIR}/source_color.bash"
}

@test "can be sourced on a terminal without color support" {
  _write_source_script
  run env TERM=dumb bash "${BATS_TEST_TMPDIR}/source_color.bash"

  assert_success
  assert_output "sourced"
}

@test "can be sourced without a terminal type" {
  _write_source_script
  run env -u TERM bash "${BATS_TEST_TMPDIR}/source_color.bash"

  assert_success
  assert_output "sourced"
}
