#!/usr/bin/env bash
set -euo pipefail

# Try CLI first if available, otherwise open app.
if command -v lms >/dev/null 2>&1; then
  exec lms server start
fi

open -a "LM Studio"
# Keep process alive for launchd; app runs detached.
while true; do sleep 3600; done
