#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECTION_DIR="${BOOK_DETECTION_DIR:-${PROJECT_DIR}/../OMX_BimanuAI_book_ocr_8_26}"
TARGET="${*:-}"

if [[ -z "${TARGET//[[:space:]]/}" ]]; then
  echo "Usage: $0 BOOK_TITLE" >&2
  echo "Example: $0 THINGS ARE WHAT" >&2
  exit 2
fi
if [[ ! -x "${DETECTION_DIR}/scripts/run_detection_view.sh" ]]; then
  echo "ERROR: Detection runner not found: ${DETECTION_DIR}/scripts/run_detection_view.sh" >&2
  exit 3
fi
if pgrep -f '[p]ublish_book_detection_view.py' >/dev/null; then
  echo "ERROR: Book detection/OCR is already running." >&2
  echo "Stop its terminal with Ctrl+C before starting another instance." >&2
  exit 4
fi

set +u
source /opt/ros/humble/setup.bash
set -u
export ROS_DOMAIN_ID=31
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export FASTRTPS_DEFAULT_PROFILES_FILE="${PROJECT_DIR}/config/fastdds_udp_only.xml"
export BOOK_CAMERA_TOPIC=/camera2/color/image_raw

# Keep the detector/OCR tuning identical to the proven single-arm setup.
# Callers may still override individual values for performance experiments.
export BOOK_CONFIDENCE="${BOOK_CONFIDENCE:-0.40}"
export BOOK_FPS="${BOOK_FPS:-8}"
export BOOK_YOLO_INTERVAL="${BOOK_YOLO_INTERVAL:-0.25}"
export BOOK_OCR_INTERVAL="${BOOK_OCR_INTERVAL:-0.5}"
export BOOK_OCR_CANDIDATES="${BOOK_OCR_CANDIDATES:-2}"
export BOOK_TORCH_THREADS="${BOOK_TORCH_THREADS:-2}"
export BOOK_MIN_MATCH="${BOOK_MIN_MATCH:-0.80}"

echo "Book detection input:  ${BOOK_CAMERA_TOPIC}"
echo "Book detection output: /book_detection/image_raw"
echo "Target title: ${TARGET}"
echo "Single-arm tuning: confidence=${BOOK_CONFIDENCE}, fps=${BOOK_FPS}, yolo_interval=${BOOK_YOLO_INTERVAL}s, ocr_interval=${BOOK_OCR_INTERVAL}s, candidates=${BOOK_OCR_CANDIDATES}, threads=${BOOK_TORCH_THREADS}, min_match=${BOOK_MIN_MATCH}"
echo "Keep this terminal running. Press Ctrl+C to stop detection."
cd "$DETECTION_DIR"

child_pid=""
cleanup() {
  trap - INT TERM EXIT
  if [[ -n "$child_pid" ]] && kill -0 "$child_pid" 2>/dev/null; then
    kill -INT -- "-${child_pid}" 2>/dev/null || true
    for _ in $(seq 1 30); do
      kill -0 "$child_pid" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$child_pid" 2>/dev/null; then
      kill -TERM -- "-${child_pid}" 2>/dev/null || true
    fi
    wait "$child_pid" 2>/dev/null || true
  fi
}
trap cleanup INT TERM EXIT

setsid ./scripts/run_detection_view.sh "$TARGET" &
child_pid=$!
set +e
wait "$child_pid"
result=$?
set -e
trap - INT TERM EXIT
exit "$result"
