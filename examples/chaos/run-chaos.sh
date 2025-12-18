#!/usr/bin/env bash
set -euo pipefail

# Continuously hits the load balancer and randomly kills/resurrects sample backends.
# Assumes examples/default/run-example.sh is already running.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

LB_URL=${LB_URL:-http://localhost:80/hello}
# Default to very chatty request loop so unhealthy backends are detected fast.
REQUEST_DELAY=${REQUEST_DELAY:-0.2}
REQUEST_TIMEOUT=${REQUEST_TIMEOUT:-2}
KILL_INTERVAL_MIN=${KILL_INTERVAL_MIN:-5}
KILL_INTERVAL_MAX=${KILL_INTERVAL_MAX:-10}
RESPAWN_DELAY_MIN=${RESPAWN_DELAY_MIN:-15}
RESPAWN_DELAY_MAX=${RESPAWN_DELAY_MAX:-15}
BACKEND_PORTS=(8081 8082 8083 8084 8085)
BACKEND_PIDS=()
RESPAWNED_PIDS=()
REQUEST_LOOP_PID=""
BACKEND_CMD=(go run ./sample-backend/main.go)

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

is_port_listening() {
  local port="$1"
  lsof -ti tcp:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

find_backend_pid() {
  local port="$1"
  lsof -ti tcp:"$port" -sTCP:LISTEN | head -n1
}

init_backend_pids() {
  for port in "${BACKEND_PORTS[@]}"; do
    local pid
    pid=$(find_backend_pid "$port" || true)
    if [[ -z "$pid" ]]; then
      echo "Could not find a backend listening on port $port. Make sure examples/default is running." >&2
      exit 1
    fi
    BACKEND_PIDS+=("$pid")
    log "Discovered backend on :$port (pid $pid)"
  done
}

wait_for_port_state() {
  local port="$1"
  local expected="$2"
  local timeout="${3:-20}"

  for ((i = 0; i < timeout; i++)); do
    if [[ "$expected" == "down" ]]; then
      if ! is_port_listening "$port"; then
        return 0
      fi
    else
      if is_port_listening "$port"; then
        return 0
      fi
    fi
    sleep 1
  done

  return 1
}

rand_between() {
  local min="$1"
  local max="$2"

  if (( max <= min )); then
    echo "$min"
    return
  fi

  local range=$((max - min + 1))
  echo $((RANDOM % range + min))
}

kill_backend() {
  local idx="$1"
  local port="${BACKEND_PORTS[$idx]}"
  local pid="${BACKEND_PIDS[$idx]}"

  if [[ -z "$pid" ]]; then
    pid=$(find_backend_pid "$port" || true)
    if [[ -z "$pid" ]]; then
      log "No process tracked for backend on :$port; skipping"
      return
    fi
    BACKEND_PIDS[$idx]="$pid"
  fi

  if ! kill -0 "$pid" >/dev/null 2>&1; then
    log "Backend on :$port (pid $pid) is already stopped"
    BACKEND_PIDS[$idx]=""
    return
  fi

  log "Killing backend on :$port (pid $pid)"
  kill "$pid" >/dev/null 2>&1 || true
  sleep 1
  if wait_for_port_state "$port" "down" 15; then
    log "Port :$port is now offline"
  else
    log "Timed out waiting for :$port to go offline"
  fi
  BACKEND_PIDS[$idx]=""
}

start_backend() {
  local idx="$1"
  local port="${BACKEND_PORTS[$idx]}"

  log "Respawning backend on :$port"
  (
    cd "$REPO_ROOT"
    exec "${BACKEND_CMD[@]}" "$port"
  ) &
  local pid=$!
  BACKEND_PIDS[$idx]="$pid"
  RESPAWNED_PIDS+=("$pid")

  if wait_for_port_state "$port" "up" 30; then
    log "Backend on :$port is healthy again (pid $pid)"
  else
    log "Backend on :$port did not start listening within 30s"
  fi
}

request_loop() {
  local counter=1
  while true; do
    local response clean
    if response=$(curl -fsS -m "$REQUEST_TIMEOUT" "$LB_URL" 2>&1); then
      clean=${response//$'\n'/ }
      log "Request #$counter -> $clean"
    else
      clean=${response//$'\n'/ }
      log "Request #$counter -> FAILED ($clean)"
    fi
    ((counter++))
    sleep "$REQUEST_DELAY"
  done
}

cleanup() {
  if [[ -n "$REQUEST_LOOP_PID" ]] && kill -0 "$REQUEST_LOOP_PID" >/dev/null 2>&1; then
    kill "$REQUEST_LOOP_PID" >/dev/null 2>&1 || true
    wait "$REQUEST_LOOP_PID" 2>/dev/null || true
  fi

  if ((${#RESPAWNED_PIDS[@]} > 0)); then
    log "Stopping respawned backends..."
    for pid in "${RESPAWNED_PIDS[@]}"; do
      if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
        kill "$pid" >/dev/null 2>&1 || true
      fi
    done
  fi
}

trap cleanup EXIT INT TERM

require_cmd curl
require_cmd lsof
init_backend_pids

log "Sending requests to $LB_URL every ${REQUEST_DELAY}s"
request_loop &
REQUEST_LOOP_PID=$!

while true; do
  delay=$(rand_between "$KILL_INTERVAL_MIN" "$KILL_INTERVAL_MAX")
  log "Next chaos event in ${delay}s"
  sleep "$delay"

  idx=$((RANDOM % ${#BACKEND_PORTS[@]}))
  kill_backend "$idx"

  delay=$(rand_between "$RESPAWN_DELAY_MIN" "$RESPAWN_DELAY_MAX")
  log "Respawning :${BACKEND_PORTS[$idx]} in ${delay}s"
  sleep "$delay"
  start_backend "$idx"
done
