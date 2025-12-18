#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
BACKEND_CMD=(go run ./sample-backend/main.go)
LOAD_BALANCER_CMD=(go run ./main.go)
BACKEND_PORTS=(8081 8082 8083 8084 8085)
BACKEND_PIDS=()

cleanup() {
  if (( ${#BACKEND_PIDS[@]} == 0 )); then
    return
  fi

  echo "\nStopping sample backends..."
  for pid in "${BACKEND_PIDS[@]}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done
}

trap cleanup EXIT INT TERM

start_backend() {
  local port="$1"
  (
    cd "$REPO_ROOT"
    exec "${BACKEND_CMD[@]}" "$port"
  ) &
  local pid=$!
  BACKEND_PIDS+=("$pid")
  echo "Started sample backend on :$port (pid $pid)"
}

echo "Starting sample backends..."
for port in "${BACKEND_PORTS[@]}"; do
  start_backend "$port"
done

echo "Sample backends are up. Starting load balancer..."
(
  cd "$REPO_ROOT"
  exec "${LOAD_BALANCER_CMD[@]}"
)
