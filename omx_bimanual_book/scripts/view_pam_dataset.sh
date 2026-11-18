#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ID="${1:-YERI84/omx_bimanual_twoomx}"
PORT="${2:-9091}"
CONTAINER="physical_ai_server"
LOG_FILE="/tmp/visualize_dataset_${PORT}.log"

if [[ ! "$REPO_ID" =~ ^[^/]+/[^/]+$ ]]; then
  echo "Usage: $0 [HF_USER/DATASET_NAME] [PORT]" >&2
  exit 2
fi

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -qx true; then
  echo "PAM server is not running; starting the bimanual PAM configuration first."
  "$PROJECT_DIR/scripts/phase4_start_pam.sh"
fi

dataset_dir="/root/.cache/huggingface/lerobot/$REPO_ID"
if ! docker exec "$CONTAINER" test -d "$dataset_dir"; then
  echo "ERROR: Dataset is not present in the external-drive cache:" >&2
  echo "  $dataset_dir" >&2
  echo "Available datasets:" >&2
  docker exec "$CONTAINER" bash -lc \
    'find /root/.cache/huggingface/lerobot -mindepth 2 -maxdepth 2 -type d -printf "  %P\n" 2>/dev/null | sort' >&2 || true
  exit 3
fi

# Stop only a previous viewer using this port. This does not stop PAM or recording.
docker exec "$CONTAINER" bash -lc \
  "pkill -TERM -f '[v]isualize_dataset_html.*--port ${PORT}' 2>/dev/null || true"

docker exec -d "$CONTAINER" bash -lc \
  "cd /root/ros2_ws/src/physical_ai_tools/lerobot/src &&
   exec python -m lerobot.scripts.visualize_dataset_html \
     --host 0.0.0.0 --port '$PORT' --repo-id '$REPO_ID' \
     >'$LOG_FILE' 2>&1"

sleep 2
if docker exec "$CONTAINER" bash -lc \
    "pgrep -af '[v]isualize_dataset_html.*--port ${PORT}' >/dev/null"; then
  echo "Dataset viewer started: $REPO_ID"
  echo "Open: http://localhost:$PORT"
  echo "Log:  docker exec $CONTAINER tail -f $LOG_FILE"
else
  echo "ERROR: Dataset viewer exited during startup." >&2
  docker exec "$CONTAINER" tail -n 100 "$LOG_FILE" >&2 || true
  exit 4
fi
