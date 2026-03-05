#!/usr/bin/env bash
set -euo pipefail
cd /Users/magnuseng/Projects/openclaw-mission-control/backend
exec /Users/magnuseng/Projects/openclaw-mission-control/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
