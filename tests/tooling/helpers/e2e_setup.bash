#!/usr/bin/env bash

_e2e_setup() {
  load "../../helpers/common_setup"
  load "../helpers/log_fixture"
  load "../helpers/stub_fixture"

  _common_setup
  _stub_setup

  # color.bash requires a terminal that supports colors
  export TERM="xterm-256color"
}
