#!/usr/bin/env bash
set -euo pipefail

# Associative arrays (declare -gA), namerefs (local -n) and case conversion (${var,,})
SYSTEM_MIN_BASH_VERSION="4.4.0"

# Entries are "binary:minimum version", an empty minimum only requires the binary to exist
SYSTEM_REQUIRED_BINARIES=(
  # --fail-with-body
  "curl:7.76.0"
  # git -C
  "git:2.0.0"
  "tar:"
  "awk:"
  "sed:"
  "find:"
  "mktemp:"
  "tput:"
  "sha256sum:"
  "md5sum:"
)

_system_error() {
  printf '[system][ERROR] %s\n' "${1}" >&2
}

_system_version_gte() {
  local IFS=.
  local -a have
  local -a want
  read -r -a have <<<"${1}"
  read -r -a want <<<"${2}"

  local count=${#have[@]}
  if [[ ${#want[@]} -gt $count ]]; then
    count=${#want[@]}
  fi

  local i
  for ((i = 0; i < count; i++)); do
    local have_part="${have[i]:-0}"
    local want_part="${want[i]:-0}"
    if ((10#${have_part} > 10#${want_part})); then
      return 0
    elif ((10#${have_part} < 10#${want_part})); then
      return 1
    fi
  done

  return 0
}

_system_binary_version() {
  local output
  local pattern='([0-9]+(\.[0-9]+)+)'

  output="$("${1}" --version 2>&1)" || true
  if [[ "${output}" =~ ${pattern} ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    return 1
  fi
}

_system_check_bash() {
  local version="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"

  if ! _system_version_gte "${version}" "${SYSTEM_MIN_BASH_VERSION}"; then
    _system_error "bash ${version} is older than the required ${SYSTEM_MIN_BASH_VERSION}"
    return 1
  fi
}

_system_check_binary() {
  local binary="${1%%:*}"
  local min_version="${1#*:}"
  local version

  if ! command -v "${binary}" >/dev/null 2>&1; then
    _system_error "Required binary [${binary}] was not found"
    return 1
  fi

  if [[ -z "${min_version}" ]]; then
    return 0
  fi

  if ! version="$(_system_binary_version "${binary}")"; then
    _system_error "Could not determine the version of [${binary}], ${min_version} or newer is required"
    return 1
  fi

  if ! _system_version_gte "${version}" "${min_version}"; then
    _system_error "[${binary}] ${version} is older than the required ${min_version}"
    return 1
  fi
}

_system_check_writable() {
  local path="${1}"

  if [[ -d "${path}" ]]; then
    if [[ ! -w "${path}" || ! -x "${path}" ]]; then
      _system_error "Directory [${path}] is not writable"
      return 1
    fi
    return 0
  fi

  local parent="${path%/*}"
  if [[ ! -d "${parent}" || ! -w "${parent}" || ! -x "${parent}" ]]; then
    _system_error "Directory [${path}] cannot be created, [${parent}] is not writable"
    return 1
  fi
}

_system_validate() {
  local failed=0
  local entry

  _system_check_bash || failed=1
  for entry in "${SYSTEM_REQUIRED_BINARIES[@]}"; do
    _system_check_binary "${entry}" || failed=1
  done
  _system_check_writable "${MODULES_ROOT}" || failed=1
  _system_check_writable "${DATA_ROOT}" || failed=1

  if [[ $failed -ne 0 ]]; then
    printf '[system][FATAL] %s\n' "System requirements not met" >&2
    exit 1
  fi
}
