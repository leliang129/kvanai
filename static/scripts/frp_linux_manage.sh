#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename -- "${0}")"

DEFAULT_FRP_VERSION="0.65.0"
DEFAULT_PROXY_URL="https://ghfast.top/"
DEFAULT_INSTALL_DIR="/usr/local/frp"
DEFAULT_SERVER_ADDR="frp.freefrp.net"
DEFAULT_SERVER_PORT="7000"

TMPDIR_TO_CLEANUP=""
cleanup() {
  if [[ -n "${TMPDIR_TO_CLEANUP}" && -d "${TMPDIR_TO_CLEANUP}" ]]; then
    rm -rf "${TMPDIR_TO_CLEANUP}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

print_usage() {
  cat <<USAGE
Usage:
  ${SCRIPT_NAME} install  frps|frpc [options]
  ${SCRIPT_NAME} uninstall frps|frpc [options]
  ${SCRIPT_NAME} restart frps|frpc
  ${SCRIPT_NAME} status  frps|frpc
  ${SCRIPT_NAME} help

Options:
  --version <v>        frp 版本（默认: 0.65.0）
  --proxy <url>        GitHub 加速前缀（默认: https://ghfast.top/；传空表示禁用）
  --install-dir <dir>  安装目录（默认: /usr/local/frp）
  --config <path>      指定配置文件路径（可包含占位符：__FRP_TOKEN__/__FRP_SERVER_ADDR__/__FRP_SERVER_PORT__）
  --token <token>      FRP Token（也可通过环境变量 FRP_TOKEN 传入；不传则随机生成并打印）
  --server-addr <addr> 仅 frpc：serverAddr（默认: frp.freefrp.net；也可用环境变量 FRP_SERVER_ADDR）
  --server-port <port> 仅 frpc：serverPort（默认: 7000；也可用环境变量 FRP_SERVER_PORT）
  --force              覆盖已存在的二进制/配置/服务

Examples:
  sudo ./${SCRIPT_NAME} install frps --version 0.65.0
  sudo ./${SCRIPT_NAME} install frps --token "12345678"
  sudo ./${SCRIPT_NAME} install frpc --server-addr 1.2.3.4 --token "12345678"
  sudo ./${SCRIPT_NAME} uninstall frpc
USAGE
}

log() {
  printf '%s\n' "$*"
}

err() {
  printf 'ERROR: %s\n' "$*" >&2
}

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "需要 root 权限，请使用 sudo 执行"
    exit 1
  fi
}

ensure_systemctl() {
  if ! have_cmd systemctl; then
    err "未找到 systemctl：该脚本目前仅支持 systemd 系统"
    exit 1
  fi
}

detect_systemd_dir() {
  if [[ -d /etc/systemd/system ]]; then
    echo "/etc/systemd/system"
    return
  fi
  echo "/lib/systemd/system"
}

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) echo "amd64" ;;
    aarch64) echo "arm64" ;;
    armv7|armv7l|armhf) echo "arm" ;;
    *)
      err "不支持的架构: ${arch}"
      exit 1
      ;;
  esac
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

rand_hex() {
  local bytes="${1:-16}"
  if have_cmd openssl; then
    openssl rand -hex "${bytes}"
    return
  fi
  # fallback: /dev/urandom
  od -An -N "${bytes}" -tx1 /dev/urandom | tr -d ' \n'
}

ensure_downloader() {
  if have_cmd curl || have_cmd wget; then
    return
  fi

  if have_cmd apt-get; then
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y curl >/dev/null 2>&1 || apt-get install -y wget >/dev/null 2>&1
  elif have_cmd yum; then
    yum install -y curl >/dev/null 2>&1 || yum install -y wget >/dev/null 2>&1
  fi

  if ! have_cmd curl && ! have_cmd wget; then
    err "缺少下载工具（curl/wget），且无法自动安装"
    exit 1
  fi
}

download_file() {
  local url="$1"
  local out="$2"

  if have_cmd curl; then
    curl -fL --retry 3 --connect-timeout 5 --max-time 600 -o "${out}" "${url}"
    return
  fi

  wget -q --timeout=15 --tries=3 -O "${out}" "${url}"
}

service_exists() {
  local svc="$1"
  systemctl list-unit-files --type=service 2>/dev/null | awk '{print $1}' | grep -qx "${svc}.service"
}

apply_placeholders() {
  local file="$1"
  local token="$2"
  local server_addr="$3"
  local server_port="$4"

  local esc_token esc_addr esc_port
  esc_token="$(printf '%s' "${token}" | sed -e 's/[\\/&|]/\\\\&/g')"
  esc_addr="$(printf '%s' "${server_addr}" | sed -e 's/[\\/&|]/\\\\&/g')"
  esc_port="$(printf '%s' "${server_port}" | sed -e 's/[\\/&|]/\\\\&/g')"

  # macOS 的 sed 也支持 -i ''，但该脚本仅面向 Linux；依然用临时文件保证兼容性
  local tmp
  tmp="$(mktemp)"
  sed \
    -e "s|__FRP_TOKEN__|${esc_token}|g" \
    -e "s|__FRP_SERVER_ADDR__|${esc_addr}|g" \
    -e "s|__FRP_SERVER_PORT__|${esc_port}|g" \
    "${file}" >"${tmp}"
  mv "${tmp}" "${file}"
}

write_default_frps_config() {
  local out="$1"
  local token="$2"

  cat >"${out}" <<EOF
bindAddr = "0.0.0.0"
bindPort = 7000
quicBindPort = 7000

vhostHTTPPort = 80
vhostHTTPSPort = 443

transport.maxPoolCount = 2000
transport.tcpMux = true
transport.tcpMuxKeepaliveInterval = 60
transport.tcpKeepalive = 7200
transport.tls.force = false

webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "admin"
webServer.password = "admin"
webServer.pprofEnable = false

log.to = "./frps.log"
log.level = "info"
log.maxDays = 3
log.disablePrintColor = false

auth.method = "token"
auth.token = "${token}"

allowPorts = [
  { start = 10001, end = 50000 }
]

maxPortsPerClient = 8
udpPacketSize = 1500
natholeAnalysisDataReserveHours = 168
EOF
}

write_default_frpc_config() {
  local out="$1"
  local token="$2"
  local server_addr="$3"
  local server_port="$4"
  local suffix="$5"

  cat >"${out}" <<EOF
serverAddr = "${server_addr}"
serverPort = ${server_port}
auth.method = "token"
auth.token = "${token}"

# 示例：按需修改 localIP/localPort/customDomains/remotePort
[[proxies]]
name = "web_${suffix}"
type = "http"
localIP = "127.0.0.1"
localPort = 8080
customDomains = ["example.com"]

[[proxies]]
name = "ssh_${suffix}"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 22222
EOF
}

install_one() {
  local name="$1"
  local frp_version="$2"
  local proxy_url="$3"
  local install_dir="$4"
  local config_src="$5"
  local token="$6"
  local server_addr="$7"
  local server_port="$8"
  local force="$9"

  need_root
  ensure_systemctl
  ensure_downloader

  local arch file_name tgz_url tgz_url_proxy tmpdir
  arch="$(detect_arch)"
  file_name="frp_${frp_version}_linux_${arch}"
  tgz_url="https://github.com/fatedier/frp/releases/download/v${frp_version}/${file_name}.tar.gz"
  tgz_url_proxy=""
  if [[ -n "${proxy_url}" ]]; then
    tgz_url_proxy="${proxy_url}${tgz_url}"
  fi

  local systemd_dir service_path service_path_etc service_path_lib bin_dst cfg_dst
  systemd_dir="$(detect_systemd_dir)"
  service_path="${systemd_dir}/${name}.service"
  service_path_etc="/etc/systemd/system/${name}.service"
  service_path_lib="/lib/systemd/system/${name}.service"
  bin_dst="${install_dir}/${name}"
  cfg_dst="${install_dir}/${name}.toml"

  if [[ "${force}" != "true" ]]; then
    local existing=()
    [[ -e "${bin_dst}" ]] && existing+=("${bin_dst}")
    [[ -e "${service_path_etc}" ]] && existing+=("${service_path_etc}")
    [[ -e "${service_path_lib}" ]] && existing+=("${service_path_lib}")
    if [[ ${#existing[@]} -gt 0 ]]; then
      err "检测到已存在：${existing[*]}（可加 --force 覆盖）"
      exit 2
    fi
  fi

  tmpdir="$(mktemp -d)"
  TMPDIR_TO_CLEANUP="${tmpdir}"

  log "下载: ${tgz_url}"
  if ! download_file "${tgz_url}" "${tmpdir}/${file_name}.tar.gz"; then
    if [[ -n "${tgz_url_proxy}" ]]; then
      log "直连下载失败，尝试代理: ${tgz_url_proxy}"
      download_file "${tgz_url_proxy}" "${tmpdir}/${file_name}.tar.gz"
    else
      err "下载失败"
      exit 1
    fi
  fi

  tar -xzf "${tmpdir}/${file_name}.tar.gz" -C "${tmpdir}"

  mkdir -p "${install_dir}"
  install -m 0755 "${tmpdir}/${file_name}/${name}" "${bin_dst}"

  local suffix
  suffix="$(rand_hex 4)"

  if [[ -e "${cfg_dst}" && "${force}" == "true" ]]; then
    cp -a "${cfg_dst}" "${cfg_dst}.bak.$(date +%Y%m%d%H%M%S)"
  fi

  # 如果配置已存在且未指定 --force，则优先复用现有配置，不覆盖
  if [[ -f "${cfg_dst}" && "${force}" != "true" ]]; then
    log "检测到配置已存在，跳过覆盖：${cfg_dst}（如需覆盖/重写可加 --force）"
  fi

  if [[ -n "${config_src}" ]]; then
    if [[ ! -f "${config_src}" ]]; then
      err "找不到配置文件: ${config_src}"
      exit 1
    fi
    if [[ ! -f "${cfg_dst}" || "${force}" == "true" ]]; then
      if [[ -z "${token}" ]]; then
        token="$(rand_hex 12)"
      fi
      install -m 0644 "${config_src}" "${cfg_dst}"
      apply_placeholders "${cfg_dst}" "${token}" "${server_addr}" "${server_port}"
    fi
  else
    if [[ ! -f "${cfg_dst}" || "${force}" == "true" ]]; then
      if [[ -z "${token}" ]]; then
        token="$(rand_hex 12)"
      fi
      if [[ "${name}" == "frps" ]]; then
        write_default_frps_config "${cfg_dst}" "${token}"
      else
        write_default_frpc_config "${cfg_dst}" "${token}" "${server_addr}" "${server_port}" "${suffix}"
      fi
      chmod 0644 "${cfg_dst}"
    fi
  fi

  cat >"${service_path}" <<EOF
[Unit]
Description=frp ${name} service
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=${install_dir}
Restart=on-failure
RestartSec=5s
ExecStart=${bin_dst} -c ${cfg_dst}

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "${name}"

  # 尝试从现有配置中读取 token（当我们没有覆盖配置时）
  if [[ -z "${token}" && -f "${cfg_dst}" ]]; then
    token="$(awk -F'"' '/^[[:space:]]*auth\.token[[:space:]]*=/ {print $2; exit}' "${cfg_dst}" 2>/dev/null || true)"
  fi

  log "安装完成：${name}"
  log "- 二进制：${bin_dst}"
  log "- 配置：${cfg_dst}"
  log "- 服务：${service_path}"
  if [[ -n "${token}" ]]; then
    log "- Token：${token}"
  else
    log "- Token：<未从配置中解析到，请检查 ${cfg_dst}>"
  fi
  if [[ "${name}" == "frpc" ]]; then
    local cfg_server_addr cfg_server_port
    cfg_server_addr="$(awk -F'"' '/^[[:space:]]*serverAddr[[:space:]]*=/ {print $2; exit}' "${cfg_dst}" 2>/dev/null || true)"
    cfg_server_port="$(awk -F'=' '/^[[:space:]]*serverPort[[:space:]]*=/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' "${cfg_dst}" 2>/dev/null || true)"
    log "- serverAddr/serverPort：${cfg_server_addr:-${server_addr}}:${cfg_server_port:-${server_port}}"
  fi
  log "修改配置后执行：systemctl restart ${name}"

  rm -rf "${tmpdir}" >/dev/null 2>&1 || true
  TMPDIR_TO_CLEANUP=""
}

uninstall_one() {
  local name="$1"
  local install_dir="$2"
  local force="$3"

  need_root
  ensure_systemctl

  local systemd_dir service_path service_path_etc service_path_lib bin_dst cfg_dst
  systemd_dir="$(detect_systemd_dir)"
  service_path="${systemd_dir}/${name}.service"
  service_path_etc="/etc/systemd/system/${name}.service"
  service_path_lib="/lib/systemd/system/${name}.service"
  bin_dst="${install_dir}/${name}"
  cfg_dst="${install_dir}/${name}.toml"

  if service_exists "${name}"; then
    systemctl disable --now "${name}" >/dev/null 2>&1 || true
  else
    systemctl stop "${name}" >/dev/null 2>&1 || true
  fi

  rm -f "${service_path}" "${service_path_etc}" "${service_path_lib}"
  rm -f "${bin_dst}"

  if [[ -f "${cfg_dst}" ]]; then
    if [[ "${force}" == "true" ]]; then
      rm -f "${cfg_dst}"
    else
      log "保留配置文件：${cfg_dst}（如需删除可加 --force）"
    fi
  fi

  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl reset-failed "${name}" >/dev/null 2>&1 || true

  if [[ -d "${install_dir}" ]]; then
    if [[ -z "$(ls -A "${install_dir}" 2>/dev/null || true)" ]]; then
      rmdir "${install_dir}" >/dev/null 2>&1 || true
    fi
  fi

  log "卸载完成：${name}"
}

action="${1:-help}"
target="${2:-}"
shift $(( $# > 0 ? 1 : 0 )) || true
shift $(( $# > 0 ? 1 : 0 )) || true

frp_version="${DEFAULT_FRP_VERSION}"
proxy_url="${DEFAULT_PROXY_URL}"
install_dir="${DEFAULT_INSTALL_DIR}"
config_src=""
token="${FRP_TOKEN:-}"
server_addr="${FRP_SERVER_ADDR:-${DEFAULT_SERVER_ADDR}}"
server_port="${FRP_SERVER_PORT:-${DEFAULT_SERVER_PORT}}"
force="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      frp_version="${2:-}"; shift 2 ;;
    --proxy)
      proxy_url="${2:-}"; shift 2 ;;
    --install-dir)
      install_dir="${2:-}"; shift 2 ;;
    --config)
      config_src="${2:-}"; shift 2 ;;
    --token)
      token="${2:-}"; shift 2 ;;
    --server-addr)
      server_addr="${2:-}"; shift 2 ;;
    --server-port)
      server_port="${2:-}"; shift 2 ;;
    --force)
      force="true"; shift 1 ;;
    -h|--help|help)
      action="help"; shift 1 ;;
    *)
      err "未知参数: $1"
      print_usage
      exit 2
      ;;
  esac
done

case "${action}" in
  install)
    if [[ "${target}" != "frps" && "${target}" != "frpc" ]]; then
      print_usage
      exit 2
    fi
    if [[ "${target}" == "frpc" ]]; then
      if [[ -z "${server_addr}" || -z "${server_port}" ]]; then
        err "frpc 需要 server-addr/server-port（可用 --server-addr/--server-port 或环境变量 FRP_SERVER_ADDR/FRP_SERVER_PORT）"
        exit 2
      fi
      if ! [[ "${server_port}" =~ ^[0-9]+$ ]]; then
        err "frpc 的 server-port 必须是数字: ${server_port}"
        exit 2
      fi
    fi
    install_one "${target}" "${frp_version}" "${proxy_url}" "${install_dir}" "${config_src}" "${token}" "${server_addr}" "${server_port}" "${force}"
    ;;
  uninstall)
    if [[ "${target}" != "frps" && "${target}" != "frpc" ]]; then
      print_usage
      exit 2
    fi
    uninstall_one "${target}" "${install_dir}" "${force}"
    ;;
  restart)
    if [[ "${target}" != "frps" && "${target}" != "frpc" ]]; then
      print_usage
      exit 2
    fi
    need_root
    ensure_systemctl
    systemctl restart "${target}"
    ;;
  status)
    if [[ "${target}" != "frps" && "${target}" != "frpc" ]]; then
      print_usage
      exit 2
    fi
    ensure_systemctl
    systemctl status "${target}" --no-pager
    ;;
  help|--help|-h|"")
    print_usage
    ;;
  *)
    err "未知动作: ${action}"
    print_usage
    exit 2
    ;;
esac
