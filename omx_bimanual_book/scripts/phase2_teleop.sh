#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"
require_motion_ack "${1:-}"
require_port_config
ensure_container
if bimanual_teleop_is_running; then
  echo "Bimanual teleoperation is already running."
  echo "Keep its original phase2_teleop.sh terminal open; do not start a second instance."
  exit 0
fi
check_legacy_conflict
"${SCRIPT_DIR}/check_devices.sh"

exec docker exec -it "${ros_env[@]}" "$CONTAINER_NAME" bash -lc '
  source /opt/ros/jazzy/setup.bash
  source /root/ros2_ws/install/setup.bash
  source /root/bimanual_ws/install/setup.bash
  export AMENT_PREFIX_PATH=/root/bimanual_ws/install/omx_bimanual_book:${AMENT_PREFIX_PATH}
  exec ros2 launch omx_bimanual_book dual_teleop.launch.py \
    left_follower_port:="$LEFT_FOLLOWER_PORT" \
    left_leader_port:="$LEFT_LEADER_PORT" \
    right_follower_port:="$RIGHT_FOLLOWER_PORT" \
    right_leader_port:="$RIGHT_LEADER_PORT"
'
