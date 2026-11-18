#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

if ! container_is_running; then
  echo "Bimanual container is already stopped."
  exit 0
fi
if ! bimanual_teleop_is_running; then
  echo "Bimanual teleoperation is already stopped."
  exit 0
fi

echo "Stopping all bimanual leader/follower control nodes..."
docker restart "$CONTAINER_NAME" >/dev/null
sleep 2

if bimanual_teleop_is_running; then
  echo "ERROR: Bimanual teleoperation still appears to be running." >&2
  exit 1
fi
echo "Bimanual teleoperation stopped. Camera, OCR, and PAM were not changed."
