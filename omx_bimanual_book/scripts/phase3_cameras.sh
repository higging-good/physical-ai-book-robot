#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAMERA1_SERIAL="${CAMERA1_SERIAL:-ADAY52302X3}"
CAMERA2_SERIAL="${CAMERA2_SERIAL:-ADAY52302X1}"

set +u
source /opt/ros/humble/setup.bash
source "${ORBBEC_WS:-$HOME/orbbec_ws}/install/setup.bash"
set -u
export ROS_DOMAIN_ID=31
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export FASTRTPS_DEFAULT_PROFILES_FILE="${PROJECT_DIR}/config/fastdds_udp_only.xml"
unset ZENOH_CONFIG_OVERRIDE
unset ZENOH_ROUTER_CHECK_ATTEMPTS

astra_count="$(lsusb -d 2bc5:0404 2>/dev/null | awk 'END {print NR}')"
if [[ "$astra_count" -ne 2 ]]; then
  echo "ERROR: Expected 2 Astra USB devices (2bc5:0404), found ${astra_count}." >&2
  echo "Stop camera launches, unplug both Astra USB cables for 10 seconds," >&2
  echo "then reconnect them and confirm two devices with: lsusb -d 2bc5:0404" >&2
  exit 4
fi

if pgrep -f '/ros2 launch orbbec_camera astra.launch.py.*camera_name:=camera[12]' >/dev/null; then
  echo "ERROR: An Astra camera launch is already running." >&2
  echo "Stop the terminal running phase3_cameras.sh with Ctrl+C before starting it again." >&2
  exit 3
fi

pids=()
cleanup() {
  trap - INT TERM EXIT
  kill -INT "${pids[@]}" 2>/dev/null || true
  wait "${pids[@]}" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

start_camera() {
  local name="$1"
  local serial="$2"
  echo "Starting ${name}: ${serial} (ROS domain ${ROS_DOMAIN_ID})"
  ros2 launch orbbec_camera astra.launch.py \
    camera_name:="${name}" \
    serial_number:="${serial}" \
    device_num:=2 \
    enable_color:=true \
    color_width:=640 \
    color_height:=480 \
    color_fps:=30 \
    color_format:=RGB \
    color_qos:=reliable \
    color_camera_info_qos:=reliable \
    enable_depth:=false \
    enable_point_cloud:=false \
    enable_ir:=false \
    publish_tf:=false \
    log_level:=info &
  pids+=("$!")
}

start_camera camera1 "$CAMERA1_SERIAL"
sleep 6
start_camera camera2 "$CAMERA2_SERIAL"
sleep 3

echo "Starting PAM compressed-image relays"
env PYTHONNOUSERSITE=1 /usr/bin/python3 "${PROJECT_DIR}/scripts/camera_raw_to_compressed.py" &
pids+=("$!")

echo
echo "Camera topics should become:"
echo "  /camera1/color/image_raw"
echo "  /camera2/color/image_raw"
echo "  /camera1/color/image_raw/compressed"
echo "  /camera2/color/image_raw/compressed"
echo "Keep this terminal running. Press Ctrl+C to stop only these cameras."
wait
