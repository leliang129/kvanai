#!/usr/bin/env bash
set -euo pipefail

# One-click GitLab deployment with Docker Compose.
#
# Optional environment overrides:
#   DEPLOY_ROOT=/opt/gitlab
#   GITLAB_IMAGE=gitlab/gitlab-ce:latest
#   GITLAB_HTTP_PORT=80
#   GITLAB_SSH_PORT=2222
#   HOST_IP=192.168.1.10
#
# CLI examples:
#   ./deploy-gitlab.sh
#   ./deploy-gitlab.sh --image gitlab/gitlab-ce:16.11.6-ce.0
#   ./deploy-gitlab.sh -i gitlab/gitlab-ee:latest -p 8080 -s 2222

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/gitlab}"
GITLAB_IMAGE="${GITLAB_IMAGE:-gitlab/gitlab-ce:latest}"
GITLAB_HTTP_PORT="${GITLAB_HTTP_PORT:-80}"
GITLAB_SSH_PORT="${GITLAB_SSH_PORT:-2222}"
GITLAB_PASSWORD_WAIT_SECONDS="${GITLAB_PASSWORD_WAIT_SECONDS:-600}"
CONTAINER_NAME="${CONTAINER_NAME:-gitlab}"
HOST_IP="${HOST_IP:-}"
HOST_NAME="${HOST_NAME_OVERRIDE:-$(hostname -s 2>/dev/null || echo gitlab)}"
COMPOSE_FILE="${DEPLOY_ROOT}/docker-compose.yml"
DOCKER=(docker)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -i, --image <image>       GitLab image, default: ${GITLAB_IMAGE}
  -p, --http-port <port>    Host HTTP port, default: ${GITLAB_HTTP_PORT}
  -s, --ssh-port <port>     Host SSH port, default: ${GITLAB_SSH_PORT}
      --host-ip <ip>        Explicit host IP for external_url
  -d, --deploy-root <path>  Deployment root, default: ${DEPLOY_ROOT}
  -h, --help                Show this help message
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--image)
        [[ $# -ge 2 ]] || { error "Missing value for $1"; usage; exit 1; }
        GITLAB_IMAGE="$2"
        shift 2
        ;;
      -p|--http-port)
        [[ $# -ge 2 ]] || { error "Missing value for $1"; usage; exit 1; }
        GITLAB_HTTP_PORT="$2"
        shift 2
        ;;
      -s|--ssh-port)
        [[ $# -ge 2 ]] || { error "Missing value for $1"; usage; exit 1; }
        GITLAB_SSH_PORT="$2"
        shift 2
        ;;
      --host-ip)
        [[ $# -ge 2 ]] || { error "Missing value for $1"; usage; exit 1; }
        HOST_IP="$2"
        shift 2
        ;;
      -d|--deploy-root)
        [[ $# -ge 2 ]] || { error "Missing value for $1"; usage; exit 1; }
        DEPLOY_ROOT="$2"
        COMPOSE_FILE="${DEPLOY_ROOT}/docker-compose.yml"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done
}

is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

run_privileged() {
  if is_root; then
    "$@"
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is required for this step. Please run as root or install sudo."
    exit 1
  fi

  sudo "$@"
}

require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    error "This script only supports Linux hosts."
    exit 1
  fi
}

install_docker_if_needed() {
  if command -v docker >/dev/null 2>&1; then
    success "Docker is already installed."
    return
  fi

  if ! command -v curl >/dev/null 2>&1; then
    error "curl is required to install Docker automatically."
    exit 1
  fi

  info "Docker not found. Installing Docker with get.docker.com ..."
  if is_root; then
    curl -fsSL https://get.docker.com | bash -s docker
  else
    curl -fsSL https://get.docker.com | sudo bash -s docker
  fi
  success "Docker installation finished."
}

ensure_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    run_privileged systemctl enable --now docker >/dev/null 2>&1 || true
  fi

  if command -v service >/dev/null 2>&1; then
    run_privileged service docker start >/dev/null 2>&1 || true
  fi
}

prepare_docker_runner() {
  if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
  elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER=(sudo docker)
  else
    error "Docker daemon is not reachable. Please check whether Docker is running."
    exit 1
  fi

  if ! "${DOCKER[@]}" compose version >/dev/null 2>&1; then
    error "docker compose is not available. Please install the Docker Compose plugin and retry."
    exit 1
  fi
}

detect_host_ip() {
  local ip_addr=""

  if command -v ip >/dev/null 2>&1; then
    ip_addr="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}')"
  fi

  if [[ -z "$ip_addr" ]] && command -v hostname >/dev/null 2>&1; then
    ip_addr="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi

  if [[ -z "$ip_addr" ]] && command -v ip >/dev/null 2>&1; then
    ip_addr="$(ip -4 addr show scope global 2>/dev/null | awk '/inet / {sub(/\/.*/, "", $2); print $2; exit}')"
  fi

  printf '%s' "$ip_addr"
}

port_in_use() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ss -lnt 2>/dev/null | awk -v port=":${port}" 'NR > 1 && $4 ~ port "$" {found = 1} END {exit found ? 0 : 1}'
    return
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
    return
  fi

  return 1
}

wait_for_file() {
  local file="$1"
  local timeout="$2"
  local waited=0

  while (( waited < timeout )); do
    if run_privileged test -s "$file"; then
      return 0
    fi

    sleep 5
    waited=$((waited + 5))
  done

  return 1
}

warn_if_ports_busy() {
  if port_in_use "$GITLAB_HTTP_PORT"; then
    warn "Host port ${GITLAB_HTTP_PORT} is already in use. docker compose may fail to start GitLab."
  fi

  if port_in_use "$GITLAB_SSH_PORT"; then
    warn "Host port ${GITLAB_SSH_PORT} is already in use. docker compose may fail to start GitLab SSH."
  fi
}

write_compose_file() {
  local external_url="$1"
  local tmp_compose

  tmp_compose="$(mktemp)"
  cat >"$tmp_compose" <<EOF
services:
  gitlab:
    image: ${GITLAB_IMAGE}
    container_name: ${CONTAINER_NAME}
    restart: always
    hostname: '${HOST_NAME}'
    shm_size: '256m'
    ports:
      - '${GITLAB_HTTP_PORT}:80'
      - '${GITLAB_SSH_PORT}:22'
    volumes:
      - '${DEPLOY_ROOT}/config:/etc/gitlab'
      - '${DEPLOY_ROOT}/logs:/var/log/gitlab'
      - '${DEPLOY_ROOT}/data:/var/opt/gitlab'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url '${external_url}'
        gitlab_rails['gitlab_shell_ssh_port'] = ${GITLAB_SSH_PORT}
EOF

  run_privileged mkdir -p "${DEPLOY_ROOT}/config" "${DEPLOY_ROOT}/logs" "${DEPLOY_ROOT}/data"
  run_privileged install -m 644 "$tmp_compose" "$COMPOSE_FILE"
  rm -f "$tmp_compose"
  success "Compose file written to ${COMPOSE_FILE}"
}

deploy_gitlab() {
  info "Pulling GitLab image ..."
  "${DOCKER[@]}" pull "$GITLAB_IMAGE"

  info "Starting GitLab with docker compose ..."
  "${DOCKER[@]}" compose -f "$COMPOSE_FILE" up -d
  "${DOCKER[@]}" compose -f "$COMPOSE_FILE" ps
}

read_gitlab_initial_password() {
  local password_file="${DEPLOY_ROOT}/config/initial_root_password"
  local password=""

  info "Waiting for GitLab initial root password ..."
  if ! wait_for_file "$password_file" "$GITLAB_PASSWORD_WAIT_SECONDS"; then
    return 1
  fi

  password="$(run_privileged awk '/^Password:/ {sub(/^Password:[[:space:]]*/, "", $0); print; exit}' "$password_file" 2>/dev/null || true)"
  [[ -n "$password" ]] || return 1

  printf '%s' "$password"
}

show_result() {
  local external_url="$1"
  local initial_password="${2:-}"

  echo
  success "GitLab deployment has been started."
  echo "Web URL      : ${external_url}"
  echo "SSH clone    : ssh://git@${HOST_IP}:${GITLAB_SSH_PORT}/<group>/<project>.git"
  echo "Deploy root  : ${DEPLOY_ROOT}"
  echo "Compose file : ${COMPOSE_FILE}"
  echo "Logs         : ${DOCKER[*]} compose -f ${COMPOSE_FILE} logs -f"
  if [[ -n "$initial_password" ]]; then
    echo "Root password: ${initial_password}"
  else
    echo "Root password: not ready yet"
    echo "Password cmd : ${DOCKER[*]} exec ${CONTAINER_NAME} grep 'Password:' /etc/gitlab/initial_root_password"
  fi
  echo
  echo "Note: the first GitLab bootstrap can take several minutes."
}

main() {
  local external_url=""
  local initial_password=""

  parse_args "$@"
  require_linux
  install_docker_if_needed
  ensure_docker_service
  prepare_docker_runner
  warn_if_ports_busy

  if [[ -z "$HOST_IP" ]]; then
    HOST_IP="$(detect_host_ip)"
  fi

  if [[ -z "$HOST_IP" ]]; then
    error "Unable to detect the host IP automatically. Please rerun with HOST_IP=<your-ip>."
    exit 1
  fi

  if [[ "$GITLAB_HTTP_PORT" == "80" ]]; then
    external_url="http://${HOST_IP}"
  else
    external_url="http://${HOST_IP}:${GITLAB_HTTP_PORT}"
  fi

  info "Using host IP: ${HOST_IP}"
  info "Using external_url: ${external_url}"

  write_compose_file "$external_url"
  deploy_gitlab
  initial_password="$(read_gitlab_initial_password 2>/dev/null || true)"
  if [[ -z "$initial_password" ]]; then
    warn "GitLab initial root password was not ready within ${GITLAB_PASSWORD_WAIT_SECONDS} seconds."
  fi
  show_result "$external_url" "$initial_password"
}

main "$@"
