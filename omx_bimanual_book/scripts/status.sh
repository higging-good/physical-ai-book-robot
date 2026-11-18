#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"
ensure_container

docker exec "${ros_env[@]}" "$CONTAINER_NAME" bash -lc '
  source /opt/ros/jazzy/setup.bash
  source /root/ros2_ws/install/setup.bash
  source /root/bimanual_ws/install/setup.bash
  export AMENT_PREFIX_PATH=/root/bimanual_ws/install/omx_bimanual_book:${AMENT_PREFIX_PATH}
  echo "=== Nodes ==="
  nodes="$(ros2 node list)"
  if ! grep -q "^/bimanual/.*/follower/controller_manager$" <<<"$nodes"; then
    echo "No bimanual follower controller is running."
    echo "Keep phase1_bringup.sh running in the first terminal, then run status.sh here."
    exit 1
  fi
  sort <<<"$nodes"
  echo "=== Bimanual topics ==="
  ros2 topic list | grep "^/bimanual/" | sort || true
  for side in left right; do
    echo "=== ${side} follower controllers ==="
    timeout 5 ros2 control list_controllers \
      -c "/bimanual/${side}/follower/controller_manager" || true
  done
'
