#!/usr/bin/env bash
set -euo pipefail

NC=$(tput sgr0 2>/dev/null || true)
RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
BLUE=$(tput setaf 4 2>/dev/null || true)
PURPLE=$(tput setaf 5 2>/dev/null || true)
TURQUOISE=$(tput setaf 6 2>/dev/null || true)
GREY=$(tput setaf 7 2>/dev/null || true)
BOLD=$(tput bold 2>/dev/null || true)

# for c in {0..255}; do echo -e "$(tput setaf $c)$(tput setaf $c | cat -v) - ${c}"; done
