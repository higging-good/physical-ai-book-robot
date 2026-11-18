#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${PROJECT_DIR}/.env"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
CONTAINER_NAME="omx_bimanual_book"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "${PROJECT_DIR}/.env.example" "$ENV_FILE"
  echo "Created ${ENV_FILE}. Verify left/right USB IDs before continuing." >&2
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required_port_vars=(
  LEFT_FOLLOWER_PORT
  LEFT_LEADER_PORT
  RIGHT_FOLLOWER_PORT
  RIGHT_LEADER_PORT
)

require_port_config() {
  local var value
  local -A seen=()
  for var in "${required_port_vars[@]}"; do
    value="${!var:-}"
    if [[ -z "$value" ]]; then
      echo "ERROR: ${var} is empty in ${ENV_FILE}." >&2
      return 1
    fi
    if [[ -n "${seen[$value]:-}" ]]; then
      echo "ERROR: ${var} duplicates ${seen[$value]} (${value})." >&2
      return 1
    fi
    seen[$value]="$var"
  done
}

container_is_running() {
  docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -qx true
}

ensure_container() {
  if ! container_is_running; then
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
  fi
}

check_legacy_conflict() {
  if docker inspect -f '{{.State.Running}}' open_manipulator 2>/dev/null | grep -qx true; then
    if docker top open_manipulator -eo pid,args 2>/dev/null |
        grep -Eq '[r]os2_control_node|[o]pen_manipulator_bringup'; then
      echo "ERROR: The legacy open_manipulator container has active robot processes." >&2
      echo "Stop its launch with Ctrl+C, then run: docker restart open_manipulator" >&2
      echo "Do not let both projects access the same OpenRB devices." >&2
      return 1
    fi
  fi
}

bimanual_teleop_is_running() {
  container_is_running &&
    docker top "$CONTAINER_NAME" -eo pid,args 2>/dev/null |
      grep -q '[d]ual_teleop.launch.py'
}

require_motion_ack() {
  if [[ "${1:-}" != "--arms-clear-and-estop-ready" ]]; then
    echo "This command can enable torque and move robot arms." >&2
    echo "Clear the workspace, keep an emergency stop ready, then run:" >&2
    echo "  $0 --arms-clear-and-estop-ready" >&2
    return 1
  fi
}

ros_env=(
  -e "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-31}"
  -e ROS_LOCALHOST_ONLY=0
  -e RMW_IMPLEMENTATION=rmw_fastrtps_cpp
  -e FASTRTPS_DEFAULT_PROFILES_FILE=/root/fastdds_udp_only.xml
)
