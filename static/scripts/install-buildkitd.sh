#!/usr/bin/env bash
set -euo pipefail

# ========= 基础配置 =========
CONTAINER_NAME="buildkitd"
IMAGE="moby/buildkit:buildx-stable-1"
LISTEN_ADDR="0.0.0.0"
PORT="1234"

# 数据目录
DATA_DIR="${DATA_DIR:-/var/lib/buildkit}"
CERT_DIR="${CERT_DIR:-$PWD/.certs/daemon}"

# ========= 检查 =========
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker 未安装"
  exit 1
fi

for f in ca.pem cert.pem key.pem; do
  if [ ! -f "${CERT_DIR}/${f}" ]; then
    echo "❌ 缺少证书文件: ${CERT_DIR}/${f}"
    exit 1
  fi
done

# ========= 清理旧容器 =========
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "⚠️ 已存在 buildkitd 容器，正在替换..."
  docker rm -f "$CONTAINER_NAME"
fi

# ========= 拉取镜像 =========
echo "📦 拉取 buildkit 镜像..."
docker pull "$IMAGE"

# ========= 启动 buildkitd =========
echo "🚀 启动 buildkitd..."

docker run -d \
  --name "$CONTAINER_NAME" \
  --restart always \
  --privileged \
  -p ${PORT}:${PORT} \
  -v ${DATA_DIR}:/var/lib/buildkit \
  -v ${CERT_DIR}:/certs:ro \
  "$IMAGE" \
  --addr tcp://${LISTEN_ADDR}:${PORT} \
  --tlscacert /certs/ca.pem \
  --tlscert /certs/cert.pem \
  --tlskey /certs/key.pem

# ========= 验证 =========
sleep 2
docker ps | grep "$CONTAINER_NAME" >/dev/null

echo "✅ buildkitd 部署完成"
IP_ADDR=""
if hostname -I >/dev/null 2>&1; then
  IP_ADDR="$(hostname -I | awk '{print $1}')"
elif command -v ip >/dev/null 2>&1; then
  IP_ADDR="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1;i<=NF;i++) if ($i==\"src\") {print $(i+1); exit}}')"
elif command -v ipconfig >/dev/null 2>&1; then
  IP_ADDR="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
if [ -n "$IP_ADDR" ]; then
  echo "👉 监听地址: tcp://${IP_ADDR}:${PORT}"
else
  echo "👉 监听地址: tcp://<host>:${PORT}"
fi
