#!/usr/bin/env bash

# Removes the escape sequences emitted by tput so log lines can be compared as plain text
_log_fixture_strip_color() {
  sed -E $'s/\x1b\\[[0-9;]*m//g; s/\x1b\\(B//g'
}

# Returns 0 if any line of $output is a log line matching the given filters
#
# Usage: _log_fixture_find [--partial|--regexp] [--scope <scope>] [--level <level>] <message>
_log_fixture_find() {
  local scope=""
  local level=""
  local partial=1
  local regexp=1
  local message=""

  while [[ $# -gt 0 ]]; do
    case "${1,,}" in
    --regexp)
      regexp=0
      shift 1
      ;;
    --partial)
      partial=0
      shift 1
      ;;
    --scope)
      scope="$2"
      shift 2
      ;;
    --scope=*)
      scope="${1#*=}"
      shift 1
      ;;
    --level)
      level="$2"
      shift 2
      ;;
    --level=*)
      level="${1#*=}"
      shift 1
      ;;
    *)
      message="$1"
      shift 1
      ;;
    esac
  done

  local line
  local line_regex='^\[([^]]*)\]\[([A-Z]+)\] (.*)$'
  # $output is set by bats run
  # shellcheck disable=SC2154
  while IFS= read -r line; do
    if ! [[ "${line}" =~ $line_regex ]]; then
      continue
    fi

    local line_scope="${BASH_REMATCH[1]}"
    local line_level="${BASH_REMATCH[2]}"
    local line_message="${BASH_REMATCH[3]}"

    if [[ -n "${scope}" && "${line_scope}" != "${scope}" ]]; then
      continue
    fi
    if [[ -n "${level}" && "${line_level}" != "${level^^}" ]]; then
      continue
    fi

    if [[ $regexp -eq 0 ]]; then
      [[ "${line_message}" =~ ${message} ]] && return 0
    elif [[ $partial -eq 0 ]]; then
      [[ "${line_message}" == *"${message}"* ]] && return 0
    else
      [[ "${line_message}" == "${message}" ]] && return 0
    fi
  done < <(printf '%s\n' "${output}" | _log_fixture_strip_color)

  return 1
}

# Fails unless $output contains a log line matching the given filters
#
# Usage: assert_log [--partial|--regexp] [--scope <scope>] [--level <level>] <message>
assert_log() {
  if ! _log_fixture_find "$@"; then
    batslib_print_kv_single_or_multi 8 \
      'expected' "$*" \
      'output' "$(printf '%s\n' "${output}" | _log_fixture_strip_color)" |
      batslib_decorate 'log line not found in output' |
      fail
  fi
}

# Fails if $output contains a log line matching the given filters
#
# Usage: refute_log [--partial|--regexp] [--scope <scope>] [--level <level>] <message>
refute_log() {
  if _log_fixture_find "$@"; then
    batslib_print_kv_single_or_multi 8 \
      'unexpected' "$*" \
      'output' "$(printf '%s\n' "${output}" | _log_fixture_strip_color)" |
      batslib_decorate 'log line should not be in output' |
      fail
  fi
}
