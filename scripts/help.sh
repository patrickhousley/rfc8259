#!/usr/bin/env bash
set -euo pipefail

_register_command "help" "help" "_help_main" \
	"Prints this help information"

_help_main() {
	printf "RFC8259 Parsers\n\n"
	printf "Example: %s command [command_args]\n\n" "${MAIN_SCRIPT}"
	printf "Commands:\n"

	for command in "${COMMANDS[@]}"; do
		local display="${COMMAND_REGISTRY["${command}:display"]:-}"
		local summary="${COMMAND_REGISTRY["${command}:summary"]:-}"
		local display_length="${#display}"

		if [[ $display_length -ge 15 ]]; then
			printf "  %s\n" "${display}"
			printf "%24s" ""
			printf "%s\n" "${summary}"
		else
			printf "  %-20s" "${display}"
			printf "  %s\n" "${summary}"
		fi

		local help_length="${COMMAND_REGISTRY["${command}:help"]}"
		if [[ $help_length -gt 0 ]]; then
			for ((i = 0; i < help_length; i++)); do
				printf "%4s%s\n" "" "${COMMAND_REGISTRY["${command}:help:${i}"]}"
			done
		fi

		printf "\n"
	done
}
