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

if pgrep -f '[c]amera_raw_to_compressed.py' >/dev/null; then
  echo "ERROR: Camera compressed relays are already running." >&2
  exit 3
fi

echo "Keep this terminal running. Press Ctrl+C to stop only the compressed relays."
exec env PYTHONNOUSERSITE=1 /usr/bin/python3 "${PROJECT_DIR}/scripts/camera_raw_to_compressed.py"
