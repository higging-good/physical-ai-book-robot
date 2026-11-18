#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_port_config
if bimanual_teleop_is_running; then
  echo "ERROR: Bimanual teleoperation is already running." >&2
  echo "Stop its existing terminal with Ctrl+C, then run this command again." >&2
  exit 1
fi
check_legacy_conflict
ensure_container
"${SCRIPT_DIR}/check_devices.sh"

# Keep compatibility with the existing PAM, camera, and book-detection
# commands, which all run on ROS domain 30.
exec docker exec -it \
  -e ROS_DOMAIN_ID=30 \
  -e ROS_LOCALHOST_ONLY=0 \
  -e RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
  -e FASTRTPS_DEFAULT_PROFILES_FILE=/root/fastdds_udp_only.xml \
  "$CONTAINER_NAME" bash -lc '
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
