#!/usr/bin/env bash

# =========================================
# 多架构镜像推送脚本
# 将amd64/arm64合并推送成为一个版本
# 比如 busybox:latest 通过 --platform 拉取后推送为 <repo>/busybox:latest-amd64/arm64
# 最后使用 docker manifest push 推送为 <repo>/busybox:latest
# =========================================
set -euo pipefail

DEST_REPO="${DEST_REPO:-swr.cn-east-3.myhuaweicloud.com/laozhongshi}"

usage() {
  cat <<'EOF'
用法:
  export DEST_REPO=127.0.0.1:5000/syncimage
  本地执行：
  ./manifest_push.sh <src_image> <dest_image>
  远程执行：
  curl -fsSL https://example.com/manifest_push.sh | bash -s -- busybox:latest busybox:latest

说明:
  - 默认会使用 amd64/arm64 两个架构
  - 会按架构执行 pull/tag/push/rmi，再创建并推送 manifest
  - <dest_image> 若带 tag，默认追加 -amd64 / -arm64（例如 repo/app:v1 -> repo/app:v1-amd64）
  - 若要自定义，使用 {arch} 占位符，例如 repo/app:v1-{arch}
  - <src_image> 如含 {arch} 占位符，将直接拉取对应镜像，不再使用 --platform
  - 若 <dest_image> 未包含仓库路径，会自动使用 DEST_REPO

可选环境变量:
  ARCHES=amd64,arm64  # 自定义架构列表（逗号分隔）
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

SRC_IMAGE="${1:-}"
DEST_IMAGE="${2:-}"

if [ -z "$SRC_IMAGE" ] || [ -z "$DEST_IMAGE" ]; then
  usage
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ 未找到 docker 命令，请先安装 Docker"
  exit 1
fi

if [[ "$DEST_IMAGE" != *"/"* ]]; then
  DEST_IMAGE="${DEST_REPO}/${DEST_IMAGE}"
fi

ARCHES_CSV="${ARCHES:-amd64,arm64}"
IFS=',' read -r -a ARCHES_LIST <<< "$ARCHES_CSV"

if [ "${#ARCHES_LIST[@]}" -eq 0 ]; then
  echo "❌ ARCHES 为空，请提供有效的架构列表"
  exit 1
fi

build_dest_image() {
  local base="$1"
  local arch="$2"

  if [[ "$base" == *"{arch}"* ]]; then
    echo "${base//\{arch\}/$arch}"
  elif [[ "$base" == *":"* ]]; then
    echo "${base}-${arch}"
  else
    echo "${base}:${arch}"
  fi
}

DEST_IMAGES=()
USE_PLATFORM=1
if [[ "$SRC_IMAGE" == *"{arch}"* ]]; then
  USE_PLATFORM=0
fi

echo "🧩 架构列表: ${ARCHES_LIST[*]}"
echo "🎯 目标镜像: $DEST_IMAGE"
echo ""

for arch in "${ARCHES_LIST[@]}"; do
  if [ "$USE_PLATFORM" -eq 1 ]; then
    SRC_IMAGE_ARCH="$SRC_IMAGE"
  else
    SRC_IMAGE_ARCH="${SRC_IMAGE//\{arch\}/$arch}"
  fi

  DEST_IMAGE_ARCH="$(build_dest_image "$DEST_IMAGE" "$arch")"
  DEST_IMAGES+=("$DEST_IMAGE_ARCH")

  echo "======================================"
  echo "⬇️  Pull: $SRC_IMAGE_ARCH (linux/$arch)"
  if [ "$USE_PLATFORM" -eq 1 ]; then
    docker pull --platform="linux/$arch" "$SRC_IMAGE_ARCH"
  else
    docker pull "$SRC_IMAGE_ARCH"
  fi

  echo "🏷️  Tag: $DEST_IMAGE_ARCH"
  docker tag "$SRC_IMAGE_ARCH" "$DEST_IMAGE_ARCH"

  echo "⬆️  Push: $DEST_IMAGE_ARCH"
  docker push "$DEST_IMAGE_ARCH"

  echo "🧹 清理本地镜像"
  docker rmi "$DEST_IMAGE_ARCH" || true
  docker rmi "$SRC_IMAGE_ARCH" || true
  echo ""
done

docker manifest rm "$DEST_IMAGE" >/dev/null 2>&1 || true

echo "🛠️  创建 manifest..."
docker manifest create "$DEST_IMAGE" "${DEST_IMAGES[@]}"

echo "📝  标注架构..."
for i in "${!ARCHES_LIST[@]}"; do
  arch="${ARCHES_LIST[$i]}"
  img="${DEST_IMAGES[$i]}"
  docker manifest annotate --os linux --arch "$arch" "$DEST_IMAGE" "$img"
done

echo "⬆️  推送 manifest..."
docker manifest push "$DEST_IMAGE"

echo "✅ 完成"
