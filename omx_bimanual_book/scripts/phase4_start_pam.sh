#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$(cd "${PROJECT_DIR}/.." && pwd)"
COMPOSE_FILE="${TOOLS_DIR}/docker/docker-compose.yml"

external_drive=""
for candidate in /media/soju/외장하드*; do
  if mountpoint -q "$candidate" &&
      [[ -d "$candidate/physical_ai/datasets" ]] &&
      [[ -d "$candidate/physical_ai/cache" ]] &&
      [[ -d "$candidate/physical_ai/models" ]]; then
    external_drive="$candidate"
    break
  fi
done

if [[ -z "$external_drive" ]]; then
  echo "ERROR: Physical AI external drive was not found under /media/soju." >&2
  exit 2
fi

echo "Starting PAM for omx_bimanual on ROS domain 31."
echo "External drive: $external_drive"
PAM_ROS_DOMAIN_ID=31 EXTERNAL_DRIVE_MOUNT="$external_drive" docker compose -f "$COMPOSE_FILE" up -d --force-recreate physical_ai_server

echo "Waiting for PAM ROS services..."
for _ in $(seq 1 30); do
  if docker exec physical_ai_server bash -lc 'source /opt/ros/jazzy/setup.bash &&
       ROS_DOMAIN_ID=31 RMW_IMPLEMENTATION=rmw_fastrtps_cpp
       ros2 service list 2>/dev/null | grep -qx /get_robot_types'; then
    echo "PAM server is ready on domain 31."
    echo "Open http://localhost and select robot type: omx_bimanual"
    exit 0
  fi
  sleep 1
done

echo "ERROR: PAM server did not expose /get_robot_types within 30 seconds." >&2
echo "Inspect with: docker logs --tail 200 physical_ai_server" >&2
exit 3
