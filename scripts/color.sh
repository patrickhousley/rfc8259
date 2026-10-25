#!/usr/bin/env bash
set -euo pipefail

NC=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
PURPLE=$(tput setaf 5)
TURQUOISE=$(tput setaf 6)
GREY=$(tput setaf 7)
BOLD=$(tput bold)

# for c in {0..255}; do echo -e "$(tput setaf $c)$(tput setaf $c | cat -v) - ${c}"; done
