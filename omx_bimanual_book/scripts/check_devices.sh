#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"
require_port_config
ensure_container

status=0
for var in "${required_port_vars[@]}"; do
  value="${!var}"
  if docker exec "$CONTAINER_NAME" test -e "$value"; then
    target="$(docker exec "$CONTAINER_NAME" readlink -f "$value")"
    printf 'OK      %-22s %s -> %s\n' "$var" "$value" "$target"
  else
    printf 'MISSING %-22s %s\n' "$var" "$value"
    status=1
  fi
done

echo
docker exec "$CONTAINER_NAME" bash -lc 'ls -l /dev/serial/by-id 2>/dev/null || true'
exit "$status"

