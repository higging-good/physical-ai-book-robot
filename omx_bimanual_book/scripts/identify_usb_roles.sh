#!/usr/bin/env bash
set -euo pipefail

scan_ids() {
  if [[ ! -d /dev/serial/by-id ]]; then
    return 0
  fi
  find /dev/serial/by-id -maxdepth 1 -type l \
    -name 'usb-ROBOTIS_OpenRB-150_*-if00' -printf '%f\n' | sort
}

print_connected() {
  local ids
  ids="$(scan_ids)"
  if [[ -z "$ids" ]]; then
    echo "  (연결된 ROBOTIS OpenRB 없음)"
  else
    sed 's/^/  - /' <<<"$ids"
  fi
}

roles=(
  LEFT_LEADER_PORT
  RIGHT_LEADER_PORT
  LEFT_FOLLOWER_PORT
  RIGHT_FOLLOWER_PORT
)

role_labels=(
  "왼쪽 리더암"
  "오른쪽 리더암"
  "왼쪽 팔로우암"
  "오른쪽 팔로우암"
)

declare -A known=()
declare -A result=()

echo "OMX 양팔 USB 역할 확인"
echo "이 스크립트는 모터를 실행하거나 torque를 켜지 않습니다."
echo
echo "먼저 네 로봇팔의 USB 케이블을 모두 컴퓨터/허브에서 분리하세요."
read -r -p "모두 분리했으면 Enter를 누르세요. "

mapfile -t initial_ids < <(scan_ids)
if (( ${#initial_ids[@]} != 0 )); then
  echo "ERROR: 아직 연결된 OpenRB가 있습니다:" >&2
  print_connected >&2
  echo "네 로봇팔 USB를 모두 뽑고 다시 실행하세요." >&2
  exit 1
fi

for i in "${!roles[@]}"; do
  role="${roles[$i]}"
  label="${role_labels[$i]}"

  while true; do
    echo
    echo "[${label}] USB 하나만 새로 연결하세요. 이전에 확인한 USB는 그대로 둡니다."
    read -r -p "연결 후 2초 정도 기다리고 Enter를 누르세요 (종료: q). " answer
    if [[ "$answer" == "q" || "$answer" == "Q" ]]; then
      echo "취소했습니다. 설정 파일은 변경되지 않았습니다."
      exit 1
    fi

    mapfile -t current_ids < <(scan_ids)
    new_ids=()
    for id in "${current_ids[@]}"; do
      if [[ -z "${known[$id]:-}" ]]; then
        new_ids+=("$id")
      fi
    done

    if (( ${#new_ids[@]} == 1 )); then
      id="${new_ids[0]}"
      known[$id]=1
      result[$role]="/dev/serial/by-id/$id"
      echo "확인: ${label}"
      echo "  ${id}"
      break
    fi

    echo "ERROR: 새 OpenRB 장치가 정확히 1개가 아닙니다. 감지된 새 장치: ${#new_ids[@]}" >&2
    print_connected >&2
    echo "해당 역할의 USB 하나만 연결됐는지 확인하고 다시 Enter를 누르세요." >&2
  done
done

echo
echo "========== 확인 결과 =========="
for i in "${!roles[@]}"; do
  role="${roles[$i]}"
  label="${role_labels[$i]}"
  printf '%-22s %s\n' "${label}:" "${result[$role]}"
done
echo "==============================="
echo
echo "이 결과를 그대로 보내주세요. 확인 후 프로젝트 .env에 반영하겠습니다."

