#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

duration="${1:-15}"
if ! [[ "$duration" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 [positive-duration-seconds]" >&2
  exit 2
fi

ensure_container
bag_name="bimanual_pilot_$(date +%Y%m%d_%H%M%S)"
bag_path="/root/.ros/log/${bag_name}"

echo "Recording ${duration}s pilot bag. Slowly move both leaders during recording."
echo "Output: ${PROJECT_DIR}/log/${bag_name}"

set +e
docker exec "${ros_env[@]}" "$CONTAINER_NAME" bash -lc "
  source /opt/ros/jazzy/setup.bash
  source /root/ros2_ws/install/setup.bash
  source /root/bimanual_ws/install/setup.bash
  export AMENT_PREFIX_PATH=/root/bimanual_ws/install/omx_bimanual_book:\${AMENT_PREFIX_PATH}

  nodes=\"\$(ros2 node list)\"
  for expected in \\
    /bimanual/left/follower/controller_manager \\
    /bimanual/right/follower/controller_manager \\
    /bimanual/left/leader/controller_manager \\
    /bimanual/right/leader/controller_manager; do
    if ! grep -qx \"\$expected\" <<<\"\$nodes\"; then
      echo \"ERROR: Missing node \$expected. Keep phase2_teleop.sh running.\" >&2
      exit 3
    fi
  done

  timeout --signal=INT --kill-after=5 ${duration} \\
    ros2 bag record -o '${bag_path}' \\
      --topics \\
      /bimanual/left/follower/joint_states \\
      /bimanual/right/follower/joint_states \\
      /bimanual/left/leader/joint_trajectory \\
      /bimanual/right/leader/joint_trajectory
"
record_rc=$?
set -e

if [[ "$record_rc" -ne 0 && "$record_rc" -ne 124 ]]; then
  echo "ERROR: Pilot recording failed with exit code ${record_rc}." >&2
  exit "$record_rc"
fi

docker exec "${ros_env[@]}" "$CONTAINER_NAME" bash -lc "
  source /opt/ros/jazzy/setup.bash
  ros2 bag info '${bag_path}'
"

echo "Pilot recording complete: ${PROJECT_DIR}/log/${bag_name}"
