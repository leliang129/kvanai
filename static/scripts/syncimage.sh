#!/usr/bin/env bash
set -uo pipefail

# =========================================
# 通用安全镜像同步脚本（企业共享版）
# =========================================

# -------------------------------
# SHA256 校验提示
# -------------------------------
EXPECTED_SHA="填写官方 SHA256 校验值"
SCRIPT_URL="https://secure.example.com/sync_images_shared_secure.sh"

# 可选：自动校验自身 SHA（如果想自动化可以启用）
# CURRENT_SHA=$(sha256sum "$0" | awk '{print $1}')
# if [ "$CURRENT_SHA" != "$EXPECTED_SHA" ]; then
#   echo "❌ 脚本校验失败，请确认脚本来源安全"
#   exit 1
# fi

# -------------------------------
# 必需环境变量
# -------------------------------
REQUIRED_VARS=(SRC_REPO DEST_REPO SRC_USER SRC_PASSWORD DEST_USER DEST_PASSWORD)
echo "🔑 本脚本使用以下必需环境变量，请确认已设置："
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR:-}" ]; then
        echo "   ⚠️ 未设置：$VAR"
    else
        echo "   ✅ 已设置：$VAR"
    fi
done
echo ""

# 校验环境变量完整性
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR:-}" ]; then
        echo "❌ 必需环境变量 $VAR 未设置，退出脚本"
        exit 1
    fi
done

# -------------------------------
# Docker 环境检查
# -------------------------------
echo "🐳 检查 Docker 环境..."
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker 命令未找到，开始自动安装..."
    echo "📥 正在下载并安装 Docker..."

    if curl -fsSL https://get.docker.com | bash -s docker; then
        echo "✅ Docker 安装成功"

        # 再次检查 Docker 是否可用
        if ! command -v docker &> /dev/null; then
            echo "❌ Docker 安装后仍无法使用，请检查安装或手动重启终端"
            exit 1
        fi

        # 检查 Docker 服务是否运行
        if ! docker info &> /dev/null; then
            echo "⚠️  Docker 服务未运行，尝试启动..."
            if command -v systemctl &> /dev/null; then
                sudo systemctl start docker
                sudo systemctl enable docker
            elif command -v service &> /dev/null; then
                sudo service docker start
            else
                echo "❌ 无法启动 Docker 服务，请手动启动：sudo systemctl start docker"
                exit 1
            fi
        fi
    else
        echo "❌ Docker 安装失败，请手动安装 Docker"
        exit 1
    fi
else
    echo "✅ Docker 命令已存在"

    # 检查 Docker 服务是否运行
    if ! docker info &> /dev/null; then
        echo "⚠️  Docker 服务未运行，尝试启动..."
        if command -v systemctl &> /dev/null; then
            sudo systemctl start docker
        elif command -v service &> /dev/null; then
            sudo service docker start
        else
            echo "❌ 无法启动 Docker 服务，请手动启动：sudo systemctl start docker"
            exit 1
        fi

        # 再次检查服务状态
        if ! docker info &> /dev/null; then
            echo "❌ Docker 服务启动失败，请检查系统配置"
            exit 1
        fi
    fi
fi

echo "🐳 Docker 环境检查完成"
echo ""

# -------------------------------
# 参数校验
# -------------------------------
IMAGE_FILE="${1:?必须传入镜像列表文件}"

if [ ! -f "$IMAGE_FILE" ]; then
  echo "❌ 镜像文件不存在：$IMAGE_FILE"
  exit 1
fi

FAILED_FILE="failed_images.txt"
: > "$FAILED_FILE"

echo "🚀 开始镜像同步（安全共享版）"
echo "📄 镜像列表：$IMAGE_FILE"
echo "📦 源仓库：$SRC_REPO"
echo "🎯 目标仓库：$DEST_REPO"
echo ""

# -------------------------------
# 登录源仓库
# -------------------------------
echo "🔐 登录源仓库：$SRC_REPO"
if ! echo "$SRC_PASSWORD" | docker login "$SRC_REPO" -u "$SRC_USER" --password-stdin; then
  echo "❌ 登录源仓库失败"
  exit 1
fi

# -------------------------------
# 主循环
# -------------------------------
while IFS= read -r IMAGE || [ -n "$IMAGE" ]; do

  IMAGE="$(echo "$IMAGE" | xargs)"
  [[ -z "$IMAGE" || "$IMAGE" =~ ^# ]] && continue

  SRC_IMAGE="${SRC_REPO}/${IMAGE}"
  DEST_IMAGE="${DEST_REPO}/${IMAGE}"

  echo ""
  echo "======================================"
  echo "📦 处理镜像：$IMAGE"

  # pull
  echo "⬇️  Pull：$SRC_IMAGE"
  if ! docker pull "$SRC_IMAGE"; then
    echo "❌ Pull 失败：$SRC_IMAGE"
    echo "$IMAGE" >> "$FAILED_FILE"
    continue
  fi

  # retag
  echo "🏷️  Retag：$DEST_IMAGE"
  if ! docker tag "$SRC_IMAGE" "$DEST_IMAGE"; then
    echo "❌ Retag 失败：$IMAGE"
    echo "$IMAGE" >> "$FAILED_FILE"
    docker rmi "$SRC_IMAGE" || true
    continue
  fi

  # 登录目标仓库
  echo "🔐 登录目标仓库：$DEST_REPO"
  if ! echo "$DEST_PASSWORD" | docker login "$DEST_REPO" -u "$DEST_USER" --password-stdin; then
    echo "❌ 登录目标仓库失败"
    echo "$IMAGE" >> "$FAILED_FILE"
    docker rmi "$SRC_IMAGE" "$DEST_IMAGE" || true
    continue
  fi

  # push
  echo "⬆️  Push：$DEST_IMAGE"
  if ! docker push "$DEST_IMAGE"; then
    echo "❌ Push 失败：$DEST_IMAGE"
    echo "$IMAGE" >> "$FAILED_FILE"
    docker rmi "$SRC_IMAGE" "$DEST_IMAGE" || true
    continue
  fi

  # cleanup
  echo "🧹 清理本地镜像"
  docker rmi "$SRC_IMAGE" "$DEST_IMAGE" || true

  echo "✅ 成功：$IMAGE"

done < "$IMAGE_FILE"

# -------------------------------
# 汇总
# -------------------------------
echo ""
echo "🎉 镜像同步完成"

if [ -s "$FAILED_FILE" ]; then
  echo "🚫 以下镜像同步失败（已记录）："
  cat "$FAILED_FILE"
  exit 2
else
  echo "✅ 全部镜像同步成功"
fi
