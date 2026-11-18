#!/usr/bin/env bash
set -u

if [[ $# -ne 1 || -z "$1" ]]; then
    printf '사용법: bash deployment/check-new-pc.sh "/media/사용자/외장SSD"\n' >&2
    exit 2
fi

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ssd="$1"
checkpoint="$ssd/physical_ai/models/train/ANG/checkpoints/050000"
dataset="$ssd/physical_ai/cache/lerobot/YERI84/ANG"
failed=0

check() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf '[OK] %s\n' "$label"
    else
        printf '[확인 필요] %s\n' "$label"
        failed=1
    fi
}

check 'x86_64 CPU 아키텍처' test "$(uname -m)" = x86_64
check '호스트 ROS 2 Humble' test -f /opt/ros/humble/setup.bash
check 'Orbbec 워크스페이스' test -f "${ORBBEC_WS:-$HOME/orbbec_ws}/install/setup.bash"
check 'Docker Compose' docker compose version
check '현재 사용자로 Docker 엔진 접속' docker info
check '호스트 NVIDIA 드라이버' nvidia-smi -L
check 'Docker NVIDIA 런타임' bash -o pipefail -c 'docker info --format "{{json .Runtimes}}" | grep -q "\"nvidia\""'
check 'LeRobot 소스' test -f "$repo/lerobot/pyproject.toml"
check 'OCR 검출 모델' test -s "$repo/OMX_BimanuAI_book_ocr_8_26/models/book_spine_detector.pt"
check '양팔 설정' test -f "$repo/physical_ai_server/config/omx_bimanual_config.yaml"
check '외장 SSD 마운트' mountpoint -q "$ssd"
check 'ANG 데이터셋 메타데이터' test -s "$dataset/meta/info.json"
check 'ANG 학습 설정' test -s "$checkpoint/pretrained_model/train_config.json"
check 'ANG ACT 가중치' test -s "$checkpoint/pretrained_model/model.safetensors"
check 'ANG 학습 재개 상태' test -s "$checkpoint/training_state/optimizer_state.safetensors"

exit "$failed"
