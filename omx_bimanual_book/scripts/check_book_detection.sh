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

topic=/book_detection/image_raw
if ! timeout 8 ros2 topic list 2>/dev/null | grep -qx "$topic"; then
  echo "MISSING: $topic" >&2
  echo "Keep phase5_book_detection.sh running." >&2
  exit 1
fi
echo "OK: $topic"
timeout 8 ros2 topic hz "$topic" --window 20 2>/dev/null || true
