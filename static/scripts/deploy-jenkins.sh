#!/usr/bin/env bash
set -euo pipefail

# One-click Jenkins deployment with Docker Compose.
#
# Optional environment overrides:
#   DEPLOY_ROOT=/opt/jenkins
#   JENKINS_IMAGE=jenkins/jenkins:lts
#   JENKINS_HTTP_PORT=8080
#   JENKINS_AGENT_PORT=50000
#
# CLI examples:
#   ./deploy-jenkins.sh
#   ./deploy-jenkins.sh --image jenkins/jenkins:lts-jdk17
#   ./deploy-jenkins.sh -i jenkins/jenkins:2.504.3-lts-jdk17 -p 8081 -a 50001

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/jenkins}"
JENKINS_IMAGE="${JENKINS_IMAGE:-jenkins/jenkins:lts}"
JENKINS_HTTP_PORT="${JENKINS_HTTP_PORT:-8080}"
JENKINS_AGENT_PORT="${JENKINS_AGENT_PORT:-50000}"
JENKINS_PREFIX="${JENKINS_PREFIX:-/}"
JENKINS_PASSWORD_WAIT_SECONDS="${JENKINS_PASSWORD_WAIT_SECONDS:-300}"
CONTAINER_NAME="${CONTAINER_NAME:-jenkins}"
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
  -i, --image <image>        Jenkins image, default: ${JENKINS_IMAGE}
  -p, --http-port <port>     Host HTTP port, default: ${JENKINS_HTTP_PORT}
  -a, --agent-port <port>    Jenkins agent port, default: ${JENKINS_AGENT_PORT}
  -x, --prefix <path>        Jenkins URL prefix, default: ${JENKINS_PREFIX}
  -d, --deploy-root <path>   Deployment root, default: ${DEPLOY_ROOT}
  -h, --help                 Show this help message
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--image)
        [[ $# -ge 2 ]] || { error "Missing value for $1"; usage; exit 1; }
        JENKINS_IMAGE="$2"
        shift 2
        ;;
      -p|--http-port)
        [[ $# -ge 2 ]] || { error "Missing value for $1"; usage; exit 1; }
        JENKINS_HTTP_PORT="$2"
        shift 2
        ;;
      -a|--agent-port)
        [[ $# -ge 2 ]] || { error "Missing value for $1"; usage; exit 1; }
        JENKINS_AGENT_PORT="$2"
        shift 2
        ;;
      -x|--prefix)
        [[ $# -ge 2 ]] || { error "Missing value for $1"; usage; exit 1; }
        JENKINS_PREFIX="$2"
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
  if port_in_use "$JENKINS_HTTP_PORT"; then
    warn "Host port ${JENKINS_HTTP_PORT} is already in use. docker compose may fail to start Jenkins."
  fi

  if port_in_use "$JENKINS_AGENT_PORT"; then
    warn "Host port ${JENKINS_AGENT_PORT} is already in use. docker compose may fail to start Jenkins agents."
  fi
}

normalize_prefix() {
  if [[ -z "$JENKINS_PREFIX" ]]; then
    JENKINS_PREFIX="/"
    return
  fi

  if [[ "$JENKINS_PREFIX" != /* ]]; then
    JENKINS_PREFIX="/${JENKINS_PREFIX}"
  fi

  if [[ "$JENKINS_PREFIX" != "/" ]]; then
    JENKINS_PREFIX="${JENKINS_PREFIX%/}"
  fi
}

write_compose_file() {
  local tmp_compose

  tmp_compose="$(mktemp)"
  cat >"$tmp_compose" <<EOF
services:
  jenkins:
    image: ${JENKINS_IMAGE}
    container_name: ${CONTAINER_NAME}
    restart: always
    environment:
      JENKINS_OPTS: --prefix=${JENKINS_PREFIX}
    ports:
      - '${JENKINS_HTTP_PORT}:8080'
      - '${JENKINS_AGENT_PORT}:50000'
    volumes:
      - '${DEPLOY_ROOT}/jenkins_home:/var/jenkins_home'
EOF

  run_privileged mkdir -p "${DEPLOY_ROOT}/jenkins_home"
  run_privileged chown -R 1000:1000 "${DEPLOY_ROOT}/jenkins_home"
  run_privileged install -m 644 "$tmp_compose" "$COMPOSE_FILE"
  rm -f "$tmp_compose"
  success "Compose file written to ${COMPOSE_FILE}"
}

deploy_jenkins() {
  info "Pulling Jenkins image ..."
  "${DOCKER[@]}" pull "$JENKINS_IMAGE"

  info "Starting Jenkins with docker compose ..."
  "${DOCKER[@]}" compose -f "$COMPOSE_FILE" up -d
  "${DOCKER[@]}" compose -f "$COMPOSE_FILE" ps
}

read_jenkins_initial_password() {
  local password_file="${DEPLOY_ROOT}/jenkins_home/secrets/initialAdminPassword"
  local password=""

  info "Waiting for Jenkins initial admin password ..."
  if ! wait_for_file "$password_file" "$JENKINS_PASSWORD_WAIT_SECONDS"; then
    return 1
  fi

  password="$(run_privileged cat "$password_file" 2>/dev/null || true)"
  [[ -n "$password" ]] || return 1

  printf '%s' "$password"
}

show_result() {
  local web_url="http://<host>:${JENKINS_HTTP_PORT}"
  local initial_password="${1:-}"

  if [[ "$JENKINS_PREFIX" != "/" ]]; then
    web_url="${web_url}${JENKINS_PREFIX}"
  fi

  echo
  success "Jenkins deployment has been started."
  echo "Web URL        : ${web_url}"
  echo "Agent port     : ${JENKINS_AGENT_PORT}"
  echo "Deploy root    : ${DEPLOY_ROOT}"
  echo "Compose file   : ${COMPOSE_FILE}"
  echo "Logs           : ${DOCKER[*]} compose -f ${COMPOSE_FILE} logs -f"
  if [[ -n "$initial_password" ]]; then
    echo "Admin password : ${initial_password}"
  else
    echo "Admin password : not ready yet"
    echo "Password cmd   : ${DOCKER[*]} exec ${CONTAINER_NAME} cat /var/jenkins_home/secrets/initialAdminPassword"
  fi
  echo
  echo "Note: the first Jenkins bootstrap can take a few minutes."
}

main() {
  local initial_password=""

  parse_args "$@"
  normalize_prefix
  require_linux
  install_docker_if_needed
  ensure_docker_service
  prepare_docker_runner
  warn_if_ports_busy
  write_compose_file
  deploy_jenkins
  initial_password="$(read_jenkins_initial_password 2>/dev/null || true)"
  if [[ -z "$initial_password" ]]; then
    warn "Jenkins initial admin password was not ready within ${JENKINS_PASSWORD_WAIT_SECONDS} seconds."
  fi
  show_result "$initial_password"
}

main "$@"
