#!/usr/bin/env bash
set -euo pipefail

SRC_REPO="${SRC_REPO:-}"
DEST_REPO="${DEST_REPO:-}"
COPY_ALL="${COPY_ALL:-true}"
SRC_TLS_VERIFY="${SRC_TLS_VERIFY:-true}"
DEST_TLS_VERIFY="${DEST_TLS_VERIFY:-true}"

log() {
  echo "[$(date +'%F %T')] $*"
}

require_env_vars() {
  local required_vars=(
    SRC_REPO
    SRC_USER
    SRC_PASSWORD
    DEST_REPO
    DEST_USER
    DEST_PASSWORD
  )
  local missing=()
  local var_name

  for var_name in "${required_vars[@]}"; do
    if [ -z "${!var_name:-}" ]; then
      missing+=("$var_name")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "❌ 缺少必填环境变量: ${missing[*]}"
    echo "请先设置以下变量后再运行脚本："
    echo "export SRC_REPO='registry.example.com/source-namespace'"
    echo "export SRC_USER='source-user'"
    echo "export SRC_PASSWORD='******'"
    echo "export DEST_REPO='registry.example.com/dest-namespace'"
    echo "export DEST_USER='dest-user'"
    echo "export DEST_PASSWORD='******'"
    exit 1
  fi
}

usage() {
  cat <<'USAGE'
用法:
  1) 单镜像模式
     ./skopeo-imagepush.sh <src_image> <dest_image>

  2) 文件批量模式
     ./skopeo-imagepush.sh <image_list_file>

示例:
  ./skopeo-imagepush.sh version.txt
  ./skopeo-imagepush.sh docker.io/library/nginx:latest harbor.example.com/demo/nginx:latest
  DEST_REPO=harbor.example.com/demo ./skopeo-imagepush.sh docker.io/library/nginx:latest nginx:latest
  SRC_REPO=docker.io DEST_REPO=harbor.example.com/demo ./skopeo-imagepush.sh version.txt

文件模式说明:
  - 支持空行和 # 注释行
  - 每行只写一个镜像名，例如:
      nginx:latest
      project/backend:v1.2.3
  - 脚本会自动拼接成:
      docker://SRC_REPO/<line>  ->  docker://DEST_REPO/<line>
  - 因此文件模式下必须同时设置 SRC_REPO 和 DEST_REPO

可选环境变量:
  COPY_ALL=true|false                   是否携带多架构/manifest 一起复制，默认 true
  SRC_TLS_VERIFY=true|false             源仓库 TLS 校验，默认 true
  DEST_TLS_VERIFY=true|false            目标仓库 TLS 校验，默认 true

必填环境变量:
  export SRC_REPO='registry.example.com/source-namespace'
  export SRC_USER='source-user'
  export SRC_PASSWORD='******'
  export DEST_REPO='registry.example.com/dest-namespace'
  export DEST_USER='dest-user'
  export DEST_PASSWORD='******'

脚本内固定附加参数:
  --insecure-policy
USAGE
}

ensure_skopeo() {
  if ! command -v skopeo >/dev/null 2>&1; then
    echo "❌ 未找到 skopeo 命令，请先自行安装后再运行此脚本"
    exit 1
  fi
}

build_dest_image() {
  local dest_image="$1"

  if [[ "$dest_image" == *"/"* || -z "$DEST_REPO" ]]; then
    printf '%s\n' "$dest_image"
  else
    printf '%s/%s\n' "$DEST_REPO" "$dest_image"
  fi
}

build_prefixed_image() {
  local repo="$1"
  local image="$2"

  if [ -z "$repo" ]; then
    printf '%s\n' "$image"
  else
    printf '%s/%s\n' "$repo" "$image"
  fi
}

run_copy() {
  local src_image="$1"
  local dest_image="$2"

  local -a cmd
  cmd=(skopeo copy --insecure-policy)

  if [ "$COPY_ALL" = "true" ]; then
    cmd+=(--all)
  fi

  cmd+=(--src-tls-verify="$SRC_TLS_VERIFY" --dest-tls-verify="$DEST_TLS_VERIFY")

  if [ -n "${SRC_USER:-}" ] || [ -n "${SRC_PASSWORD:-}" ]; then
    cmd+=(--src-creds "${SRC_USER:-}:${SRC_PASSWORD:-}")
  fi

  if [ -n "${DEST_USER:-}" ] || [ -n "${DEST_PASSWORD:-}" ]; then
    cmd+=(--dest-creds "${DEST_USER:-}:${DEST_PASSWORD:-}")
  fi

  cmd+=("docker://$src_image" "docker://$dest_image")

  log "开始推送镜像"
  log "源镜像: $src_image"
  log "目标镜像: $dest_image"
  "${cmd[@]}"
  log "镜像推送完成"
}

parse_and_push_line() {
  local line="$1"
  local image_name=""
  local src_image=""
  local dest_image=""

  line="${line%%#*}"
  line="$(echo "$line" | xargs)"
  [ -z "$line" ] && return 0

  if [ -z "$SRC_REPO" ] || [ -z "$DEST_REPO" ]; then
    echo "❌ 文件模式要求同时设置 SRC_REPO 和 DEST_REPO"
    exit 1
  fi

  if [[ "$line" == *" "* || "$line" == *$'\t'* || "$line" == *"->"* || "$line" == *"=>"* ]]; then
    echo "❌ 文件模式每行只能填写一个镜像名称，出错行: $line"
    exit 1
  fi

  image_name="$line"
  src_image="$(build_prefixed_image "$SRC_REPO" "$image_name")"
  dest_image="$(build_prefixed_image "$DEST_REPO" "$image_name")"
  run_copy "$src_image" "$dest_image"
}

push_from_file() {
  local image_file="$1"

  if [ ! -f "$image_file" ]; then
    echo "❌ 文件不存在: $image_file"
    exit 1
  fi

  log "开始批量推送，文件: $image_file"
  while IFS= read -r line || [ -n "$line" ]; do
    parse_and_push_line "$line"
  done < "$image_file"
  log "批量推送完成"
}

main() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
  fi

  if [ $# -eq 0 ]; then
    echo "❌ 未传入 txt 文件，请按以下方式运行："
    echo "   ./skopeo-imagepush.sh version.txt"
    echo
    usage
    exit 1
  fi

  require_env_vars
  ensure_skopeo

  if [ $# -eq 1 ]; then
    if [[ "$1" != *.txt ]]; then
      echo "❌ 文件模式请传入 .txt 文件，例如：./skopeo-imagepush.sh version.txt"
      exit 1
    fi

    if [ ! -f "$1" ]; then
      echo "❌ txt 文件不存在: $1"
      echo "请确认文件路径是否正确，例如：./skopeo-imagepush.sh version.txt"
      exit 1
    fi

    push_from_file "$1"
    exit 0
  fi

  local src_image="${1:-}"
  local dest_image_raw="${2:-}"

  if [ -z "$src_image" ] || [ -z "$dest_image_raw" ]; then
    usage
    exit 1
  fi

  local dest_image
  dest_image="$(build_dest_image "$dest_image_raw")"
  run_copy "$src_image" "$dest_image"
}

main "$@"
