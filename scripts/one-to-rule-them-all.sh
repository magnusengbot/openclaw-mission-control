#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/magnuseng/Projects/openclaw-mission-control"
LOG_DIR="$ROOT/scripts"
PID_DIR="$ROOT/.pids"
mkdir -p "$PID_DIR"

start_proc() {
  local name="$1"; shift
  local pidfile="$PID_DIR/$name.pid"
  if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo "[$name] already running (pid $(cat "$pidfile"))"
    return
  fi
  echo "[$name] starting..."
  nohup "$@" >"$LOG_DIR/$name.out.log" 2>"$LOG_DIR/$name.err.log" &
  echo $! > "$pidfile"
  sleep 0.3
}

stop_proc() {
  local name="$1"
  local pidfile="$PID_DIR/$name.pid"
  if [[ -f "$pidfile" ]]; then
    local pid
    pid="$(cat "$pidfile")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "[$name] stopping pid $pid"
      kill "$pid" || true
    fi
    rm -f "$pidfile"
  else
    echo "[$name] not running"
  fi
}

status_proc() {
  local name="$1"
  local pidfile="$PID_DIR/$name.pid"
  if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo "[$name] RUNNING pid=$(cat "$pidfile")"
  else
    echo "[$name] STOPPED"
  fi
}

start_all() {
  echo "== Infra =="
  brew services start redis >/dev/null 2>&1 || true
  brew services start postgresql@16 >/dev/null 2>&1 || true
  openclaw gateway start >/dev/null 2>&1 || true

  echo "== LM Studio =="
  if command -v lms >/dev/null 2>&1; then
    lms server start >/dev/null 2>&1 || true
  else
    open -a "LM Studio" >/dev/null 2>&1 || true
  fi

  echo "== Mission Control =="
  start_proc mc-backend \
    "$ROOT/backend/.venv/bin/uvicorn" app.main:app --host 127.0.0.1 --port 8000

  start_proc mc-worker \
    /opt/homebrew/bin/uv run --directory "$ROOT/backend" python "$ROOT/scripts/rq" worker

  # Use production frontend if build exists; fallback to dev.
  if [[ -d "$ROOT/frontend/.next" ]]; then
    start_proc mc-frontend bash -lc "cd '$ROOT/frontend' && npm run start -- --port 3000"
  else
    start_proc mc-frontend bash -lc "cd '$ROOT/frontend' && npm run dev -- --port 3000"
  fi

  start_proc mc-watchdog \
    "$ROOT/backend/.venv/bin/python" "$ROOT/scripts/board_watchdog.py"

  echo "== Health =="
  curl -sS http://127.0.0.1:8000/healthz || true
  curl -I -sS http://127.0.0.1:3000 | head -n 1 || true
}

stop_all() {
  stop_proc mc-watchdog
  stop_proc mc-frontend
  stop_proc mc-worker
  stop_proc mc-backend
}

status_all() {
  status_proc mc-backend
  status_proc mc-worker
  status_proc mc-frontend
  status_proc mc-watchdog
  echo "[openclaw-gateway]"; openclaw gateway status || true
  echo "[redis/postgres]"; brew services list | rg 'redis|postgresql@16' || true
}

case "${1:-}" in
  start) start_all ;;
  stop) stop_all ;;
  restart) stop_all; sleep 1; start_all ;;
  status) status_all ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
