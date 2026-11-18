#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_NAME="physical_ai_server"

repo_id="${1:-YERI84/omx_bimanual_twoomx}"
episode="${2:-0}"
if ! [[ "$episode" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 [USER/DATASET] [EPISODE_INDEX]" >&2
  exit 2
fi

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -qx true; then
  echo "ERROR: physical_ai_server is not running." >&2
  exit 3
fi
plotter="/tmp/plot_pam_episode.py"
docker cp "${SCRIPT_DIR}/plot_pam_episode.py" "${CONTAINER_NAME}:${plotter}" >/dev/null
output_dir="${PROJECT_DIR}/plots"
mkdir -p "$output_dir"
output_file="${output_dir}/$(basename "$repo_id")_episode_$(printf '%06d' "$episode")_joints.svg"

docker exec "$CONTAINER_NAME" python3 "$plotter" "/root/.cache/huggingface/lerobot/${repo_id}" --episode "$episode" --output /tmp/joint_plot.svg
docker cp "${CONTAINER_NAME}:/tmp/joint_plot.svg" "$output_file" >/dev/null
echo "Joint graph: $output_file"
