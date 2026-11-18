#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_motion_ack "${1:-}"
check_legacy_conflict
ensure_container

for var in LEFT_FOLLOWER_PORT RIGHT_FOLLOWER_PORT; do
  value="${!var:-}"
  if [[ -z "$value" ]]; then
    echo "ERROR: ${var} is empty in ${ENV_FILE}." >&2
    exit 2
  fi
  if ! docker exec "$CONTAINER_NAME" test -e "$value"; then
    echo "ERROR: ${var} is not connected: ${value}" >&2
    exit 3
  fi
  target="$(docker exec "$CONTAINER_NAME" readlink -f "$value")"
  printf 'OK      %-22s %s -> %s\n' "$var" "$value" "$target"
done

if [[ "$LEFT_FOLLOWER_PORT" == "$RIGHT_FOLLOWER_PORT" ]]; then
  echo "ERROR: Left and right follower ports are identical." >&2
  exit 4
fi

if docker top "$CONTAINER_NAME" -eo pid,args 2>/dev/null |
    grep -Eq '[d]ual_(teleop|followers)\.launch\.py|[r]os2_control_node'; then
  echo "ERROR: Bimanual robot control is already running." >&2
  echo "Stop its original terminal with Ctrl+C." >&2
  echo "If it remains orphaned, run: docker restart ${CONTAINER_NAME}" >&2
  echo "Never run teleoperation and ACT inference against the followers together." >&2
  exit 5
fi

echo "Starting LEFT and RIGHT followers only for PAM/ACT inference."
echo "No leader arm will be started. Keep this terminal open."

exec docker exec -it "${ros_env[@]}" "$CONTAINER_NAME" bash -lc '
  source /opt/ros/jazzy/setup.bash
  source /root/ros2_ws/install/setup.bash
  source /root/bimanual_ws/install/setup.bash
  export AMENT_PREFIX_PATH=/root/bimanual_ws/install/omx_bimanual_book:${AMENT_PREFIX_PATH}
  exec ros2 launch omx_bimanual_book dual_followers.launch.py \
    left_follower_port:="$LEFT_FOLLOWER_PORT" \
    right_follower_port:="$RIGHT_FOLLOWER_PORT"
'
