#!/usr/bin/env bash
set -euo pipefail

# ===== 基本变量 =====
DEFAULT_BUILDER="multi-remote"
DEFAULT_DRIVER="remote"
CLIENT_CERT_DIR="${CLIENT_CERT_DIR:-$PWD/.certs/client}"
SERVER_NAME="${SERVER_NAME:-buildkitd}"

# ===== 函数 =====
usage() {
  cat <<EOF
用法:
  $0 create  <builder-name> <endpoint>
  $0 append  <builder-name> <endpoint>

示例:
  $0 create mybuilder tcp://127.0.0.1:1234
  $0 append mybuilder tcp://192.168.0.130:1234

环境变量:
  CLIENT_CERT_DIR=/path/to/.certs/client  (默认: ./.certs/client)
  SERVER_NAME=buildkitd                  (默认: buildkitd)
EOF
}

ensure_buildx() {
  if ! docker buildx version >/dev/null 2>&1; then
    echo "❌ docker buildx not available"
    exit 1
  fi
}

ensure_client_certs() {
  for f in ca.pem cert.pem key.pem; do
    if [ ! -f "${CLIENT_CERT_DIR}/${f}" ]; then
      echo "❌ 缺少客户端证书文件: ${CLIENT_CERT_DIR}/${f}"
      exit 1
    fi
  done
}

builder_exists() {
  docker buildx ls | awk '{print $1}' | grep -qx "$1"
}

# ===== 参数解析 =====
ACTION="${1:-}"
BUILDER="${2:-$DEFAULT_BUILDER}"
ENDPOINT="${3:-}"

if [[ -z "$ACTION" ]]; then
  echo "请选择操作:"
  select ACTION in create append; do
    [[ -n "$ACTION" ]] && break
  done
fi

if [[ -z "$ENDPOINT" ]]; then
  read -rp "请输入 BuildKit 端点（例如 tcp://host:1234）: " ENDPOINT
fi

ensure_buildx
ensure_client_certs

# ===== 主逻辑 =====
case "$ACTION" in
  create)
    if builder_exists "$BUILDER"; then
      echo "❌ Builder '$BUILDER' already exists"
      exit 1
    fi

    echo "▶ Creating builder '$BUILDER' with endpoint $ENDPOINT"
    docker buildx create \
      --name "$BUILDER" \
      --driver "$DEFAULT_DRIVER" \
      --driver-opt cacert="${CLIENT_CERT_DIR}/ca.pem" \
      --driver-opt cert="${CLIENT_CERT_DIR}/cert.pem" \
      --driver-opt key="${CLIENT_CERT_DIR}/key.pem" \
      --driver-opt servername="${SERVER_NAME}" \
      "$ENDPOINT"

    ;;

  append)
    if ! builder_exists "$BUILDER"; then
      echo "❌ Builder '$BUILDER' does not exist"
      exit 1
    fi

    echo "▶ Appending node to builder '$BUILDER': $ENDPOINT"
    docker buildx create \
      --append \
      --name "$BUILDER" \
      --driver "$DEFAULT_DRIVER" \
      --driver-opt cacert="${CLIENT_CERT_DIR}/ca.pem" \
      --driver-opt cert="${CLIENT_CERT_DIR}/cert.pem" \
      --driver-opt key="${CLIENT_CERT_DIR}/key.pem" \
      --driver-opt servername="${SERVER_NAME}" \
      "$ENDPOINT"
    ;;

  *)
    usage
    exit 1
    ;;
esac

# ===== Bootstrap & Show =====
echo "▶ Bootstrapping builder..."
docker buildx inspect "$BUILDER" --bootstrap

echo
echo "✅ Current builder status:"
docker buildx ls | sed -n "1p;/${BUILDER}/,/^$/p"
