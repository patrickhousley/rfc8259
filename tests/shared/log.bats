#!/usr/bin/env bats

setup() {
  load '../helpers/unit_setup'

  _unit_setup
}

@test "_log defaults to info level" {
  run _log "scope" "message"

  assert_success
  assert_log --scope "scope" --level "info" "message"
}

@test "_log prints each non fatal level" {
  local level
  for level in info success warn error; do
    run _log "scope" "message ${level}" "${level}"

    assert_success
    assert_log --scope "scope" --level "${level}" "message ${level}"
  done
}

@test "_log accepts levels in any case" {
  run _log "scope" "message" "SuCcEsS"

  assert_success
  assert_log --scope "scope" --level "success" "message"
}

@test "_log colors the level" {
  run _log "scope" "message" "info"
  assert_output --partial "${BLUE}INFO"

  run _log "scope" "message" "success"
  assert_output --partial "${GREEN}SUCCESS"

  run _log "scope" "message" "warn"
  assert_output --partial "${YELLOW}WARN"

  run _log "scope" "message" "error"
  assert_output --partial "${RED}ERROR"
}

@test "_log colors the scope" {
  run _log "scope" "message"

  assert_output --partial "${GREY}scope"
}

@test "_log does not interpret escapes in the message" {
  run _log "scope" 'a\tb %s'

  assert_success
  assert_log --scope "scope" 'a\tb %s'
}

@test "_log exits on fatal level" {
  run _log "scope" "message" "fatal"

  assert_failure 1
  assert_log --scope "scope" --level "fatal" "message"
}

@test "_log exits on unknown level" {
  run _log "scope" "message" "bogus"

  assert_failure 1
  assert_log --scope "scope" --level "fatal" "Unknown log level bogus"
}

@test "_log hides verbose level by default" {
  run _log "scope" "message" "verbose"

  assert_success
  assert_output ""
}

@test "_log shows verbose level when verbose is enabled" {
  LOG_VERBOSE=0
  run _log "scope" "message" "verbose"

  assert_success
  assert_log --scope "scope" --level "verbose" "message"
  assert_output --partial "${YELLOW}VERBOSE"
}

@test "_log_is_verbose_enabled is disabled by default" {
  run _log_is_verbose_enabled

  assert_failure
}

@test "_log_toggle_verbose enables verbose logging" {
  run _log_toggle_verbose
  assert_log --scope "logger" --level "verbose" "Enabled verbose logging"

  _log_toggle_verbose >/dev/null
  run _log_is_verbose_enabled
  assert_success
}

@test "_log_toggle_verbose disables verbose logging when enabled" {
  _log_toggle_verbose >/dev/null
  run _log_toggle_verbose
  assert_output ""

  _log_toggle_verbose
  run _log_is_verbose_enabled
  assert_failure
}
