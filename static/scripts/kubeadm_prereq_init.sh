#!/usr/bin/env bash
set -euo pipefail

# kubeadm_prereq_init.sh
# Initialize host OS prerequisites for kubeadm clusters.
# Supports Debian/Ubuntu and RHEL-family distros.

SCRIPT_NAME="$(basename "$0")"
K8S_MODULES_CONF="/etc/modules-load.d/k8s.conf"
K8S_SYSCTL_CONF="/etc/sysctl.d/99-kubernetes-cri.conf"

DISABLE_FIREWALL="false"
DISABLE_SELINUX="false"
VERBOSE="false"
K8S_VERSION="v1.31"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
  echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
  echo -e "${RED}[ERR]${NC} $*" >&2
}

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Options:
  --k8s-version <vX.Y> Set Kubernetes repo channel version (default: v1.31)
  --disable-firewall    Disable ufw/firewalld for lab environments
  --disable-selinux     Set SELinux to disabled (RHEL-family only)
  -v, --verbose         Print additional runtime details
  -h, --help            Show this help message

Examples:
  sudo bash $SCRIPT_NAME
  sudo bash $SCRIPT_NAME --k8s-version v1.32
  sudo bash $SCRIPT_NAME --k8s-version 1.31 --disable-firewall
  sudo bash $SCRIPT_NAME --disable-firewall
  sudo bash $SCRIPT_NAME --disable-firewall --disable-selinux
USAGE
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    error "Please run as root: sudo bash $SCRIPT_NAME"
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --k8s-version)
        [[ $# -lt 2 ]] && { error "--k8s-version requires a value"; exit 1; }
        K8S_VERSION="$2"
        shift 2
        ;;
      --k8s-version=*)
        K8S_VERSION="${1#*=}"
        shift
        ;;
      --disable-firewall)
        DISABLE_FIREWALL="true"
        shift
        ;;
      --disable-selinux)
        DISABLE_SELINUX="true"
        shift
        ;;
      -v|--verbose)
        VERBOSE="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

normalize_k8s_version() {
  # Accept both "v1.31" and "1.31"
  if [[ "$K8S_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    K8S_VERSION="v${K8S_VERSION}"
  fi

  if [[ ! "$K8S_VERSION" =~ ^v[0-9]+\.[0-9]+$ ]]; then
    error "Invalid --k8s-version: $K8S_VERSION (expected vX.Y or X.Y, e.g. v1.31)"
    exit 1
  fi
}

OS_ID=""
OS_ID_LIKE=""
OS_PRETTY=""
OS_FAMILY="unknown"

detect_os() {
  if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS: /etc/os-release not found"
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release

  OS_ID="${ID:-unknown}"
  OS_ID_LIKE="${ID_LIKE:-}"
  OS_PRETTY="${PRETTY_NAME:-$OS_ID}"

  case "$OS_ID" in
    ubuntu|debian)
      OS_FAMILY="debian"
      ;;
    centos|rhel|rocky|almalinux|ol|fedora)
      OS_FAMILY="rhel"
      ;;
    *)
      if [[ "$OS_ID_LIKE" == *"debian"* ]]; then
        OS_FAMILY="debian"
      elif [[ "$OS_ID_LIKE" == *"rhel"* ]] || [[ "$OS_ID_LIKE" == *"fedora"* ]]; then
        OS_FAMILY="rhel"
      else
        OS_FAMILY="unknown"
      fi
      ;;
  esac

  log "Detected OS: ${OS_PRETTY} (id=${OS_ID}, family=${OS_FAMILY})"

  if [[ "$OS_FAMILY" == "unknown" ]]; then
    warn "Unsupported distro family. Script will run generic steps only."
  fi
}

disable_swap() {
  log "Disabling swap"
  swapoff -a || true

  if [[ -f /etc/fstab ]]; then
    cp /etc/fstab "/etc/fstab.bak.$(date +%F-%H%M%S)"
    sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
  fi

  success "Swap disabled and fstab updated"
}

configure_kernel_modules() {
  log "Configuring kernel modules: overlay, br_netfilter"

  cat > "$K8S_MODULES_CONF" <<'EOF_MOD'
overlay
br_netfilter
EOF_MOD

  modprobe overlay || true
  modprobe br_netfilter || true

  success "Kernel modules configured"
}

configure_sysctl() {
  log "Applying Kubernetes sysctl params"

  cat > "$K8S_SYSCTL_CONF" <<'EOF_SYSCTL'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF_SYSCTL

  sysctl --system >/dev/null

  success "Sysctl configured"
}

configure_kubernetes_repo() {
  log "Configuring Kubernetes package repository channel: ${K8S_VERSION}"

  if [[ "$OS_FAMILY" == "debian" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null
    apt-get install -y apt-transport-https ca-certificates curl gpg >/dev/null

    mkdir -p /etc/apt/keyrings
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
      | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    cat > /etc/apt/sources.list.d/kubernetes.list <<EOF_DEB
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /
EOF_DEB
    apt-get update -y >/dev/null
    success "Kubernetes apt repo configured: ${K8S_VERSION}"
    return
  fi

  if [[ "$OS_FAMILY" == "rhel" ]]; then
    cat > /etc/yum.repos.d/kubernetes.repo <<EOF_RPM
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/rpm/repodata/repomd.xml.key
EOF_RPM
    success "Kubernetes rpm repo configured: ${K8S_VERSION}"
    return
  fi

  warn "Skipping Kubernetes repo setup for unknown OS family"
}

disable_firewall_if_requested() {
  if [[ "$DISABLE_FIREWALL" != "true" ]]; then
    warn "Firewall not changed. For lab use --disable-firewall."
    return
  fi

  log "Disabling firewall services (lab mode)"

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files | grep -q '^firewalld\.service'; then
      systemctl disable --now firewalld || true
      success "firewalld disabled"
    fi

    if systemctl list-unit-files | grep -q '^ufw\.service'; then
      systemctl disable --now ufw || true
      success "ufw disabled"
    fi
  fi
}

configure_selinux_if_requested() {
  if [[ "$OS_FAMILY" != "rhel" ]]; then
    return
  fi

  if ! command -v getenforce >/dev/null 2>&1; then
    return
  fi

  current_selinux="$(getenforce || true)"
  log "SELinux current mode: ${current_selinux}"

  if [[ "$DISABLE_SELINUX" != "true" ]]; then
    warn "SELinux not changed. Use --disable-selinux only for lab environments."
    return
  fi

  if command -v setenforce >/dev/null 2>&1; then
    setenforce 0 || true
  fi

  if [[ -f /etc/selinux/config ]]; then
    cp /etc/selinux/config "/etc/selinux/config.bak.$(date +%F-%H%M%S)"
    sed -ri 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
  fi

  success "SELinux set to disabled (reboot may be required)"
}

print_summary() {
  echo
  echo "========== kubeadm env summary =========="
  echo "OS          : $OS_PRETTY"
  echo "OS Family   : $OS_FAMILY"
  echo "K8S Repo Ver: $K8S_VERSION"
  echo "Swap        : $(free -h | awk '/Swap/ {print $2" total, "$3" used"}')"
  echo "Kernel mod  : overlay=$(lsmod | awk '$1=="overlay"{print "yes"}' | head -n1 || true), br_netfilter=$(lsmod | awk '$1=="br_netfilter"{print "yes"}' | head -n1 || true)"
  echo "sysctl ipfwd: $(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo unknown)"

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files | grep -q '^firewalld\.service'; then
      echo "firewalld   : $(systemctl is-active firewalld 2>/dev/null || echo unknown)"
    fi
    if systemctl list-unit-files | grep -q '^ufw\.service'; then
      echo "ufw         : $(systemctl is-active ufw 2>/dev/null || echo unknown)"
    fi
  fi

  if command -v getenforce >/dev/null 2>&1; then
    echo "SELinux     : $(getenforce 2>/dev/null || echo unknown)"
  fi

  echo "========================================="
}

main() {
  parse_args "$@"
  normalize_k8s_version
  require_root
  detect_os
  disable_swap
  configure_kernel_modules
  configure_sysctl
  configure_kubernetes_repo
  disable_firewall_if_requested
  configure_selinux_if_requested

  if [[ "$VERBOSE" == "true" ]]; then
    log "Verbose check:"
    ls -l "$K8S_MODULES_CONF" "$K8S_SYSCTL_CONF" || true
  fi

  print_summary
  success "kubeadm environment initialization completed"
}

main "$@"
