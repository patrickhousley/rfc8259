#!/usr/bin/env bash
set -euo pipefail

SHELLCHECK_MODULE_BIN="${MODULES_ROOT}/shellcheck/shellcheck"
_register_command \
  --command="lint" \
  --func-name="_lint_main" \
  --summary="Runs all lint tooling against the repository" \
  --help="--write    Enable shellcheck autofixing"

_lint_main() {
  local write=0

  for arg in "$@"; do
    case "${arg,,}" in
    --write)
      write=1
      shift 1
      ;;
    *)
      _log "_lint_main" "Unknown command argument [${arg}]" "fatal"
      ;;
    esac
  done

  if [[ ! -f "${SHELLCHECK_MODULE_BIN}" ]]; then
    _module_download \
      --name="shellcheck" \
      --download-url="https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.gz" \
      --sha256="b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6" \
      --tar
  fi
  if [[ ! -x "${SHELLCHECK_MODULE_BIN}" ]]; then
    chmod ug+x "${SHELLCHECK_MODULE_BIN}"
  fi

  local exit_code=0
  if [[ $write -eq 1 ]]; then
    _log "_lint_main" "Running shellcheck in write mode..." "verbose"
    _lint_shellcheck_write_loop || exit_code=$?
  else
    _log "_lint_main" "Running shellcheck in check mode..." "verbose"
    _lint_shellcheck_run || exit_code=$?
  fi

  if [[ $exit_code -ne 0 ]]; then
    _log "_lint_main" "Repository files have lint errors" "fatal"
  else
    _log "_lint_main" "Repository files linted" "success"
  fi
}

_lint_shellcheck_write_loop() {
  local exit_code=0
  local patch_file
  local error

  while true; do
    patch_file=$(mktemp)
    _lint_shellcheck_write_diff "${patch_file}" || true

    if [[ -f "${patch_file}.err" && -s "${patch_file}.err" ]]; then
      while read -r line; do
        error=$(_lint_shellcheck_fmt_error "${line}")
        _log "linter" "${error}" "error"
      done <"${patch_file}.err"
      exit_code=1
    elif [[ -f "${patch_file}" && -s "${patch_file}" ]]; then
      sed -i 's|a/\./|a/|g; s|b/\./|b/|g' "${patch_file}"
      _lint_shellcheck_apply_diff "$patch_file" || exit_code=$?
    else
      rm -f "${patch_file}" "${patch_file}.err"
      break
    fi

    rm -f "${patch_file}" "${patch_file}.err"

    if [[ $exit_code -ne 0 ]]; then
      break
    fi
  done

  return $exit_code
}

_lint_shellcheck_run() {
  local output_format="${1:-tty}"
  local file_list=()

  while IFS= read -r -d '' file; do
    [ -f "$file" ] && file_list+=("$file")
  done < <(git ls-files -z --exclude-standard "*.bash" "*.bats")

  if [ ${#file_list[@]} -gt 0 ]; then
    "${SHELLCHECK_MODULE_BIN}" --format "${output_format}" "${file_list[@]}"
  fi
}

_lint_shellcheck_write_diff() {
  local patch_file="${1}"

  _log "_lint_shellcheck_write_diff" "Writing patch file to ${patch_file}" "verbose"
  _log "_lint_shellcheck_write_diff" "Writing patch error file to ${patch_file}.err" "verbose"
  _lint_shellcheck_run "diff" >"${patch_file}" 2>"${patch_file}.err" || true
}

_lint_shellcheck_apply_diff() {
  local patch_file="${1}"
  local exit_code=0

  if [[ -s "$patch_file" ]]; then
    _log "_lint_shellcheck_apply_diff" "Applying auto-fixes to files..." "verbose"
    git apply "$patch_file" || exit_code=$?
  fi

  return $exit_code
}

_lint_shellcheck_fmt_error() {
  local error="${1}"
  local find
  local replace

  if [[ "${error}" == *"none were auto-fixable"* ]]; then
    find="Use another format"
    replace="Use check mode"
    error=${error//$find/$replace}
  fi

  echo "${error}"
}
