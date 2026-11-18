#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set +u
source /opt/ros/humble/setup.bash
source /home/soju/orbbec_ws/install/setup.bash
set -u
export ROS_DOMAIN_ID=31
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export FASTRTPS_DEFAULT_PROFILES_FILE="${PROJECT_DIR}/config/fastdds_udp_only.xml"

topics="$(timeout 8 ros2 topic list 2>/dev/null || true)"
failed=0
if ! pgrep -f '[/]opt/ros/humble/bin/ros2 launch orbbec_camera astra.launch.py.*camera_name:=camera1' >/dev/null ||
   ! pgrep -f '[/]opt/ros/humble/bin/ros2 launch orbbec_camera astra.launch.py.*camera_name:=camera2' >/dev/null; then
  echo "MISSING: live camera1/camera2 launch processes" >&2
  echo "Start ./scripts/phase3_cameras.sh and keep its terminal running." >&2
  exit 1
fi
for topic in /camera1/color/image_raw /camera2/color/image_raw; do
  if grep -qx "$topic" <<<"$topics"; then
    echo "OK: $topic"
  else
    echo "MISSING: $topic" >&2
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "Camera check failed. Keep phase3_cameras.sh running and inspect its terminal." >&2
  exit 1
fi

for topic in /camera1/color/image_raw /camera2/color/image_raw; do
  echo
  echo "Rate sample: $topic"
  timeout 6 ros2 topic hz "$topic" --window 30 2>/dev/null || true
done
