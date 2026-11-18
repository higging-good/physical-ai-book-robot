#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"
require_motion_ack "${1:-}"
require_port_config
check_legacy_conflict
ensure_container
"${SCRIPT_DIR}/check_devices.sh"

exec docker exec -it "${ros_env[@]}" "$CONTAINER_NAME" bash -lc '
  source /opt/ros/jazzy/setup.bash
  source /root/ros2_ws/install/setup.bash
  source /root/bimanual_ws/install/setup.bash
  export AMENT_PREFIX_PATH=/root/bimanual_ws/install/omx_bimanual_book:${AMENT_PREFIX_PATH}
  exec ros2 launch omx_bimanual_book dual_followers.launch.py \
    left_follower_port:="$LEFT_FOLLOWER_PORT" \
    right_follower_port:="$RIGHT_FOLLOWER_PORT"
'
