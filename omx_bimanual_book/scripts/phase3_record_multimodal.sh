#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

duration="${1:-10}"
if ! [[ "$duration" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 [positive-duration-seconds]" >&2
  exit 2
fi

ensure_container
bag_name="bimanual_multimodal_$(date +%Y%m%d_%H%M%S)"
bag_path="/root/.ros/log/${bag_name}"

echo "Recording ${duration}s: 12D joints + two RGB cameras."
echo "Move both leaders slowly. This command only records; it never replays."
echo "Output: ${PROJECT_DIR}/log/${bag_name}"

set +e
docker exec "${ros_env[@]}" "$CONTAINER_NAME" bash -lc "
  source /opt/ros/jazzy/setup.bash
  source /root/ros2_ws/install/setup.bash
  source /root/bimanual_ws/install/setup.bash

  required_topics='
/bimanual/left/follower/joint_states
/bimanual/right/follower/joint_states
/bimanual/left/leader/joint_trajectory
/bimanual/right/leader/joint_trajectory
/camera1/color/image_raw
/camera2/color/image_raw'
  available=\"\$(timeout 10 ros2 topic list)\"
  while IFS= read -r topic; do
    [[ -z \"\$topic\" ]] && continue
    if ! grep -qx \"\$topic\" <<<\"\$available\"; then
      echo \"ERROR: Missing topic \$topic\" >&2
      exit 3
    fi
  done <<<\"\$required_topics\"

  timeout --signal=INT --kill-after=10 ${duration} \
    ros2 bag record -o '${bag_path}' \
      --compression-mode file \
      --compression-format zstd \
      --topics \
      /bimanual/left/follower/joint_states \
      /bimanual/right/follower/joint_states \
      /bimanual/left/leader/joint_trajectory \
      /bimanual/right/leader/joint_trajectory \
      /camera1/color/image_raw \
      /camera2/color/image_raw
"
record_rc=$?
set -e

if [[ "$record_rc" -ne 0 && "$record_rc" -ne 124 ]]; then
  echo "ERROR: Multimodal recording failed with exit code ${record_rc}." >&2
  exit "$record_rc"
fi

docker exec "${ros_env[@]}" "$CONTAINER_NAME" bash -lc "
  source /opt/ros/jazzy/setup.bash
  ros2 bag info '${bag_path}'
"
echo "Multimodal pilot complete: ${PROJECT_DIR}/log/${bag_name}"
