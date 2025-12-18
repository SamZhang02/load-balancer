#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
CONFIG_PATH="${CONFIG_PATH:-$REPO_ROOT/config.yaml}"
PARALLEL_REQUESTS=${PARALLEL_REQUESTS:-5}
BURSTS=${BURSTS:-5}

resolve_port() {
  local port
  if [[ -n "${LB_TARGET_PORT:-}" ]]; then
    echo "$LB_TARGET_PORT"
    return
  fi

  if [[ -r "$CONFIG_PATH" ]]; then
    port=$(awk '
      $1 == "server:" {in_server=1; next}
      in_server && $1 == "port:" {print $2; exit}
      in_server && NF == 0 {exit}
    ' "$CONFIG_PATH")
    if [[ -n "$port" ]]; then
      echo "$port"
      return
    fi
  fi

  echo 8080
}

TARGET_PORT=$(resolve_port)
LB_URL="${LB_URL:-http://127.0.0.1:${TARGET_PORT}/hello}"

echo "Sending $((PARALLEL_REQUESTS * BURSTS)) requests to $LB_URL" \
  "($PARALLEL_REQUESTS parallel requests across $BURSTS bursts)"

echo "Tip: run examples/default/run-example.sh in another terminal first"

for burst in $(seq 1 "$BURSTS"); do
  echo "\nBurst $burst"
  pids=()

  for idx in $(seq 1 "$PARALLEL_REQUESTS"); do
    (
      body=$(curl -sS "$LB_URL")
      printf '  [%02d.%02d] %s\n' "$burst" "$idx" "$body"
    ) &
    pids+=($!)
  done

  burst_status=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      burst_status=1
    fi
  done

  if (( burst_status != 0 )); then
    echo "One or more requests failed in burst $burst" >&2
    exit "$burst_status"
  fi

done

echo "\nRound-robin responses above should show the backend port changing each time, and a roughly even distribution of ports overrall."
