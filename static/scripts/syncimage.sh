#!/usr/bin/env bash
set -uo pipefail

# ===============================
# 必需环境变量（敏感信息）
# ===============================
: "${SRC_REPO:?必须设置 SRC_REPO，例如 docker.io/library}"
: "${DEST_REPO:?必须设置 DEST_REPO，例如 registry.example.com/base}"

: "${SRC_USER:?必须设置 SRC_USER}"
: "${SRC_PASSWORD:?必须设置 SRC_PASSWORD}"

: "${DEST_USER:?必须设置 DEST_USER}"
: "${DEST_PASSWORD:?必须设置 DEST_PASSWORD}"

IMAGE_FILE="${1:?必须传入镜像列表文件}"

if [ ! -f "$IMAGE_FILE" ]; then
  echo "❌ 镜像文件不存在：$IMAGE_FILE"
  exit 1
fi

FAILED_FILE="failed_images.txt"
: > "$FAILED_FILE"

echo "🚀 开始镜像同步"
echo "📄 镜像列表：$IMAGE_FILE"
echo "📦 源仓库：$SRC_REPO"
echo "🎯 目标仓库：$DEST_REPO"
echo ""

# ===============================
# 登录源仓库（一次）
# ===============================
echo "🔐 登录源仓库：$SRC_REPO"
if ! echo "$SRC_PASSWORD" | docker login "$SRC_REPO" -u "$SRC_USER" --password-stdin; then
  echo "❌ 登录源仓库失败"
  exit 1
fi

# ===============================
# 主循环（失败继续）
# ===============================
while IFS= read -r IMAGE || [ -n "$IMAGE" ]; do

  IMAGE="$(echo "$IMAGE" | xargs)"
  [[ -z "$IMAGE" || "$IMAGE" =~ ^# ]] && continue

  SRC_IMAGE="${SRC_REPO}/${IMAGE}"
  DEST_IMAGE="${DEST_REPO}/${IMAGE}"

  echo ""
  echo "======================================"
  echo "📦 处理镜像：$IMAGE"

  # -------------------------------
  # pull
  # -------------------------------
  echo "⬇️  Pull：$SRC_IMAGE"
  if ! docker pull "$SRC_IMAGE"; then
    echo "❌ Pull 失败：$SRC_IMAGE"
    echo "$IMAGE" >> "$FAILED_FILE"
    continue
  fi

  # -------------------------------
  # retag
  # -------------------------------
  echo "🏷️  Retag：$DEST_IMAGE"
  if ! docker tag "$SRC_IMAGE" "$DEST_IMAGE"; then
    echo "❌ Retag 失败：$IMAGE"
    echo "$IMAGE" >> "$FAILED_FILE"
    docker rmi "$SRC_IMAGE" || true
    continue
  fi

  # -------------------------------
  # 登录目标仓库（按你要求：在 push 前）
  # -------------------------------
  echo "🔐 登录目标仓库：$DEST_REPO"
  if ! echo "$DEST_PASSWORD" | docker login "$DEST_REPO" -u "$DEST_USER" --password-stdin; then
    echo "❌ 登录目标仓库失败"
    echo "$IMAGE" >> "$FAILED_FILE"
    docker rmi "$SRC_IMAGE" "$DEST_IMAGE" || true
    continue
  fi

  # -------------------------------
  # push
  # -------------------------------
  echo "⬆️  Push：$DEST_IMAGE"
  if ! docker push "$DEST_IMAGE"; then
    echo "❌ Push 失败：$DEST_IMAGE"
    echo "$IMAGE" >> "$FAILED_FILE"
    docker rmi "$SRC_IMAGE" "$DEST_IMAGE" || true
    continue
  fi

  # -------------------------------
  # cleanup
  # -------------------------------
  echo "🧹 清理本地镜像"
  docker rmi "$SRC_IMAGE" "$DEST_IMAGE" || true

  echo "✅ 成功：$IMAGE"

done < "$IMAGE_FILE"

# ===============================
# 汇总
# ===============================
echo ""
echo "🎉 镜像同步完成"

if [ -s "$FAILED_FILE" ]; then
  echo "🚫 以下镜像同步失败（已记录）："
  cat "$FAILED_FILE"
  exit 2
else
  echo "✅ 全部镜像同步成功"
fi
