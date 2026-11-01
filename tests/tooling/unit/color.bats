#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

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

@test "can be sourced on a terminal without color support" {
  run env TERM=dumb bash -c "source '${SCRIPTS_ROOT}/shared/color.bash' && echo sourced"

  assert_success
  assert_output "sourced"
}

@test "can be sourced without a terminal type" {
  run env -u TERM bash -c "source '${SCRIPTS_ROOT}/shared/color.bash' && echo sourced"

  assert_success
  assert_output "sourced"
}
