#!/bin/bash
<<<<<<< HEAD
cd "$(dirname "$0")"
venv/bin/python plch_holds.py system-wide >> log.txt &
wait
=======
set -euo pipefail

cd "$(dirname "$0")"

# Ensure cron can find uv
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

uv run python plch_holds.py system-wide >> log_system-wide.txt 2>&1
>>>>>>> 105bd48 (updates for uv, sh, and config.ini changes")
