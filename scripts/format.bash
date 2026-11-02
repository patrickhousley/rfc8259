#!/usr/bin/env bash
set -euo pipefail

SHFMT_MODULE_BIN="${MODULES_ROOT}/shfmt/shfmt_v3.14.1_linux_amd64"
_register_command \
  --command="format" \
  --func-name="_format_main" \
  --summary="Runs formatting tooling against the repository" \
  --help="--write    Enable shfmt writing"

_format_main() {
  local write=0

  for arg in "$@"; do
    case "${arg,,}" in
    --write)
      write=1
      shift 1
      ;;
    *)
      _log "_format_main" "Unknown command argument [${arg}]" "fatal"
      ;;
    esac
  done

  if [[ ! -f "${SHFMT_MODULE_BIN}" ]]; then
    _module_download \
      --name="shfmt" \
      --download-url="https://github.com/mvdan/sh/releases/download/v3.14.1/shfmt_v3.14.1_linux_amd64" \
      --sha256="76e77641faa025814b77f153b29796b8e6fa2fca03e0c76a691608b86c7ea7bf"
  fi
  if [[ ! -x "${SHFMT_MODULE_BIN}" ]]; then
    chmod ug+x "${SHFMT_MODULE_BIN}"
  fi

  local exit_code=0
  if [[ $write -eq 1 ]]; then
    _log "_format_main" "Running shfmt in write mode..." "verbose"
    "${SHFMT_MODULE_BIN}" -w "$PROJECT_ROOT" || exit_code=$?
  else
    _log "_format_main" "Running shfmt in check mode..." "verbose"
    "${SHFMT_MODULE_BIN}" -d "$PROJECT_ROOT" || exit_code=$?
  fi

  if [[ $exit_code -ne 0 ]]; then
    _log "_format_main" "Repository files are not properly formatted" "fatal"
  else
    _log "_format_main" "Repository files formatted" "success"
  fi
}
