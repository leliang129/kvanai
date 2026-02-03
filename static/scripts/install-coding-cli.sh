#!/usr/bin/env bash
# Periodic checker for Claude / Codex / Gemini CLI installation and latest version.
# Usage:
#   ./install-coding-cli.sh                 # run once
#   ./install-coding-cli.sh --interval 6h   # loop every 6 hours
#   ./install-coding-cli.sh --auto-update   # update if outdated
#
# Environment overrides:
#   CLAUDE_CMD, CLAUDE_NPM_PACKAGE
#   CODEX_CMD,  CODEX_NPM_PACKAGE
#   GEMINI_CMD, GEMINI_NPM_PACKAGE

set -euo pipefail

# Colors (disable with NO_COLOR=1)
if [[ "${NO_COLOR:-}" == "1" ]]; then
  RED=""; GREEN=""; YELLOW=""; CYAN=""; NC=""
else
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  NC='\033[0m'
fi

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

auto_update=false
interval=""
STATUS_SUMMARY=()
ACTION_HINTS=()

usage() {
  cat <<'USAGE'
Usage:
  ./install-coding-cli.sh [--interval 6h] [--auto-update] [--once]

Options:
  --interval <s|m|h|d>   Run in a loop with the given interval (e.g. 30m, 6h, 1d)
  --auto-update          Auto-update when outdated (npm global)
  --once                 Run only once (override interval loop)
USAGE
}

parse_interval_seconds() {
  local raw="$1"
  if [[ ! "$raw" =~ ^[0-9]+[smhd]$ ]]; then
    err "Invalid interval: $raw"
    exit 1
  fi
  local num="${raw%[smhd]}"
  local unit="${raw: -1}"
  case "$unit" in
    s) echo "$num" ;;
    m) echo $((num * 60)) ;;
    h) echo $((num * 3600)) ;;
    d) echo $((num * 86400)) ;;
  esac
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

extract_version() {
  # Extract first semver-like token from input
  echo "$1" | grep -Eo '[0-9]+(\.[0-9]+)+' | head -n1
}

get_installed_version() {
  local cmd="$1"
  local out
  if ! command_exists "$cmd"; then
    echo ""
    return 0
  fi
  if out=$($cmd --version 2>/dev/null); then
    extract_version "$out"
    return 0
  fi
  if out=$($cmd -v 2>/dev/null); then
    extract_version "$out"
    return 0
  fi
  echo ""
}

npm_latest_version() {
  local pkg="$1"
  if ! command_exists npm; then
    echo ""
    return 0
  fi
  npm view "$pkg" version 2>/dev/null || true
}

compare_versions() {
  # returns 0 if v1 < v2, 1 if v1 == v2, 2 if v1 > v2, 3 if unknown
  local v1="$1"
  local v2="$2"
  if [[ -z "$v1" || -z "$v2" ]]; then
    echo 3
    return 0
  fi
  local IFS='.'
  local -a a1 a2
  read -r -a a1 <<< "$v1"
  read -r -a a2 <<< "$v2"
  local len=${#a1[@]}
  if [[ ${#a2[@]} -gt $len ]]; then
    len=${#a2[@]}
  fi
  local i n1 n2
  for ((i=0; i<len; i++)); do
    n1=${a1[i]:-0}
    n2=${a2[i]:-0}
    if (( n1 < n2 )); then
      echo 0
      return 0
    elif (( n1 > n2 )); then
      echo 2
      return 0
    fi
  done
  echo 1
}

install_or_update_npm() {
  local pkg="$1"
  if [[ -z "$pkg" ]]; then
    return 0
  fi
  if ! command_exists npm; then
    warn "npm not found, cannot install $pkg"
    return 0
  fi
  if npm install -g "$pkg" >/dev/null 2>&1; then
    ok "npm install -g $pkg"
  else
    warn "Need sudo for npm -g, retrying..."
    sudo npm install -g "$pkg"
    ok "sudo npm install -g $pkg"
  fi
}

choose_first_working_pkg() {
  local -a candidates=("$@")
  local pkg
  for pkg in "${candidates[@]}"; do
    if [[ -n "$pkg" ]]; then
      local v
      v=$(npm_latest_version "$pkg")
      if [[ -n "$v" ]]; then
        echo "$pkg"
        return 0
      fi
    fi
  done
  echo ""
}

check_tool() {
  local name="$1"
  local cmd="$2"
  local pkg="$3"
  local pkg_env_var=""
  local status="未知"
  local installed=""
  local latest=""
  local cmp=""
  if [[ "$name" == "Gemini" ]]; then
    pkg_env_var="GEMINI_NPM_PACKAGE"
  elif [[ "$name" == "Claude" ]]; then
    pkg_env_var="CLAUDE_NPM_PACKAGE"
  elif [[ "$name" == "Codex" ]]; then
    pkg_env_var="CODEX_NPM_PACKAGE"
  fi

  if command_exists "$cmd"; then
    installed=$(get_installed_version "$cmd")
    if [[ -z "$installed" ]]; then
      warn "$name: installed but version not detected (cmd: $cmd)"
    else
      ok "$name: installed (v$installed)"
    fi

    if [[ -n "$pkg" ]]; then
      latest=$(npm_latest_version "$pkg")
    fi

    if [[ -n "$latest" ]]; then
      cmp=$(compare_versions "$installed" "$latest")
      if [[ "$cmp" == "1" ]]; then
        ok "$name: latest ($latest)"
        status="已是最新"
      elif [[ "$cmp" == "0" ]]; then
        warn "$name: outdated (installed $installed < latest $latest)"
        status="需要更新"
        if [[ "$auto_update" == true ]]; then
          info "$name: updating via npm..."
          install_or_update_npm "$pkg"
        fi
      elif [[ "$cmp" == "2" ]]; then
        warn "$name: newer than registry? (installed $installed > latest $latest)"
        status="已高于最新"
      else
        warn "$name: latest unknown"
        status="最新未知"
      fi
    else
      warn "$name: latest unknown (no npm package or npm unavailable)"
      status="最新未知"
    fi
  else
    warn "$name: not installed (cmd: $cmd)"
    status="未安装"
    if [[ "$auto_update" == true && -n "$pkg" ]]; then
      info "$name: installing via npm..."
      install_or_update_npm "$pkg"
    fi
  fi

  # Re-evaluate status after auto update/install attempt
  if [[ "$auto_update" == true && ( "$status" == "需要更新" || "$status" == "未安装" ) && -n "$pkg" ]]; then
    if command_exists "$cmd"; then
      installed=$(get_installed_version "$cmd")
      latest=$(npm_latest_version "$pkg")
      if [[ -n "$installed" && -n "$latest" ]]; then
        cmp=$(compare_versions "$installed" "$latest")
        if [[ "$cmp" == "1" ]]; then
          status="已是最新（已更新）"
        elif [[ "$cmp" == "0" ]]; then
          status="仍需更新"
        elif [[ "$cmp" == "2" ]]; then
          status="已高于最新"
        else
          status="最新未知"
        fi
      elif [[ -n "$installed" ]]; then
        status="已安装（最新未知）"
      else
        status="安装失败"
      fi
    else
      status="安装失败"
    fi
  fi

  STATUS_SUMMARY+=("$name: $status")

  if [[ "$status" == "需要更新" || "$status" == "仍需更新" ]]; then
    if [[ -n "$pkg" ]]; then
      ACTION_HINTS+=("$name: 需要更新，运行 --auto-update 或手动执行: npm install -g $pkg")
    else
      ACTION_HINTS+=("$name: 需要更新，但未检测到 npm 包名，可先设置 $pkg_env_var 后再运行 --auto-update")
    fi
  elif [[ "$status" == "未安装" || "$status" == "安装失败" ]]; then
    if [[ -n "$pkg" ]]; then
      ACTION_HINTS+=("$name: 未安装，运行 --auto-update 或手动执行: npm install -g $pkg")
    else
      ACTION_HINTS+=("$name: 未安装，未检测到 npm 包名，可先设置 $pkg_env_var 后再运行 --auto-update")
    fi
  fi
}

run_check() {
  info "Checking coding CLIs..."
  STATUS_SUMMARY=()
  ACTION_HINTS=()

  local claude_cmd="${CLAUDE_CMD:-claude}"
  local codex_cmd="${CODEX_CMD:-codex}"

  local claude_pkg="${CLAUDE_NPM_PACKAGE:-@anthropic-ai/claude-code}"
  local codex_pkg="${CODEX_NPM_PACKAGE:-@openai/codex}"

  # Gemini: try multiple package candidates if not explicitly set
  local gemini_cmd="${GEMINI_CMD:-gemini}"
  local gemini_pkg="${GEMINI_NPM_PACKAGE:-}"
  if [[ -z "$gemini_pkg" ]]; then
    gemini_pkg=$(choose_first_working_pkg "@google/gemini-cli" "gemini-cli" "google-gemini-cli")
  fi

  check_tool "Claude" "$claude_cmd" "$claude_pkg"
  check_tool "Codex" "$codex_cmd" "$codex_pkg"
  check_tool "Gemini" "$gemini_cmd" "$gemini_pkg"

  info "Summary:"
  local item
  for item in "${STATUS_SUMMARY[@]}"; do
    echo "  - $item"
  done

  if [[ ${#ACTION_HINTS[@]} -gt 0 ]]; then
    info "Next steps:"
    for item in "${ACTION_HINTS[@]}"; do
      echo "  - $item"
    done
  fi

  info "Done."
}

once=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)
      interval="$2"
      shift 2
      once=false
      ;;
    --auto-update)
      auto_update=true
      shift
      ;;
    --once)
      once=true
      interval=""
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
 done

if [[ "$once" == true || -z "$interval" ]]; then
  run_check
  exit 0
fi

sleep_seconds=$(parse_interval_seconds "$interval")
info "Running in loop every $interval (sleep ${sleep_seconds}s)"
while true; do
  run_check
  sleep "$sleep_seconds"
done
