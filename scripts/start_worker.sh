#!/usr/bin/env bash
set -euo pipefail
cd /Users/magnuseng/Projects/openclaw-mission-control/backend
exec /opt/homebrew/bin/uv run --directory /Users/magnuseng/Projects/openclaw-mission-control/backend python /Users/magnuseng/Projects/openclaw-mission-control/scripts/rq worker
