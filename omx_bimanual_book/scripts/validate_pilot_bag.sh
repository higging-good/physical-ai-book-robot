#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 log/bimanual_pilot_YYYYMMDD_HHMMSS" >&2
  exit 2
fi

ensure_container
host_bag="$(realpath "$1")"
case "$host_bag" in
  "${PROJECT_DIR}/log/"*) ;;
  *) echo "ERROR: bag must be inside ${PROJECT_DIR}/log" >&2; exit 2 ;;
esac
[[ -f "${host_bag}/metadata.yaml" ]] || {
  echo "ERROR: metadata.yaml not found in ${host_bag}" >&2
  exit 2
}

bag_name="$(basename "$host_bag")"
validator_path="/tmp/validate_pilot_bag.py"
docker cp "${SCRIPT_DIR}/validate_pilot_bag.py" "${CONTAINER_NAME}:${validator_path}" >/dev/null
docker exec "${ros_env[@]}" "$CONTAINER_NAME" bash -lc "
  source /opt/ros/jazzy/setup.bash
  python3 '${validator_path}' \\
    '/root/.ros/log/${bag_name}'
"
