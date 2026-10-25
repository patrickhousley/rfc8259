#!/usr/bin/env bash
set -euo pipefail

_register_command "lint" "lint" "_lint_main" \
	"Runs all lint tooling against the repository" \
	"-w/--write    Enable shellcheck autofixing"

_lint_main() {
	if ! command -v "shellcheck" >/dev/null 2>&1; then
		_log "linter" "Binary [shellcheck] not installed" "fatal"
	fi

	local write=1
	for arg in "$@"; do
		case "${arg,,}" in
		-w | --write)
			write=0
			;;
		*)
			_log "linter" "Unknown command argument [${arg}]" "fatal"
			;;
		esac
	done

	local exit_code=0
	if [[ $write -eq 0 ]]; then
		_log "linter" "Running shellcheck in write mode..." "verbose"
		_lint_shellcheck_write_loop || exit_code=$?
	else
		_log "linter" "Running shellcheck in check mode..." "verbose"
		find . \( -path "./test-suite" -o -path "./data" \) -prune -o -name "*.sh" -exec shellcheck {} + || exit_code=$?
	fi

	if [[ $exit_code -ne 0 ]]; then
		_log "linter" "Repository files have lint errors" "fatal"
	else
		_log "linter" "Repository files linted" "success"
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
			break
		fi

		if [[ $exit_code -ne 0 ]]; then
			break
		fi
	done

	return $exit_code
}

_lint_shellcheck_write_diff() {
	local patch_file="${1}"

	_log "linter" "Writing patch file to ${patch_file}" "verbose"
	_log "linter" "Writing patch error file to ${patch_file}.err" "verbose"
	find . \( -path "./test-suite" -o -path "./data" \) -prune -o -name "*.sh" -exec shellcheck -f diff {} + >"${patch_file}" 2>"${patch_file}.err" || true
}

_lint_shellcheck_apply_diff() {
	local patch_file="${1}"
	local exit_code=0

	if [[ -s "$patch_file" ]]; then
		_log "linter" "Applying auto-fixes to files..." "verbose"
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
