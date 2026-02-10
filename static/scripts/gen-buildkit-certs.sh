#!/usr/bin/env bash
set -euo pipefail

# 生成 BuildKit 远程驱动 TLS 证书（CA / Server / Client）
# 使用官方 BuildKit create-certs bake 定义（基于 mkcert）
# 用法:
#   SAN_LIST="192.168.0.130 buildkitd localhost 127.0.0.1" BASE_DIR=/root/.certs ./gen-buildkit-certs.sh
#   ./gen-buildkit-certs.sh

BASE_DIR="${BASE_DIR:-/root/.certs}"
SAN_LIST="${SAN_LIST:-}"
SAN_CLIENT="${SAN_CLIENT:-client}"
BAKE_REF="${BAKE_REF:-https://github.com/moby/buildkit.git#master:examples/create-certs}"

if [[ -z "$SAN_LIST" ]]; then
  read -rp "请输入 SAN（空格分隔，例如：192.168.0.130 buildkitd localhost 127.0.0.1）: " SAN_LIST
fi
if [[ -z "$SAN_LIST" ]]; then
  echo "❌ SAN_LIST is required"
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "❌ docker buildx not available"
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

(
  cd "$WORK_DIR"
  SAN="$SAN_LIST" SAN_CLIENT="$SAN_CLIENT" docker buildx bake "$BAKE_REF"
)

rm -rf "${BASE_DIR:?}/daemon" "${BASE_DIR:?}/client"
mkdir -p "$BASE_DIR"
cp -a "$WORK_DIR/.certs/daemon" "$BASE_DIR/"
cp -a "$WORK_DIR/.certs/client" "$BASE_DIR/"

echo "✅ Certificates generated:"
echo "  SAN:      ${SAN_LIST}"
echo "  Server:   ${BASE_DIR}/daemon/{ca.pem,cert.pem,key.pem}"
echo "  Client:   ${BASE_DIR}/client/{ca.pem,cert.pem,key.pem}"
