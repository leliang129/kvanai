#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
ArgoCD Application publisher

Usage:
  argocd-app-publisher.sh render [options]
  argocd-app-publisher.sh apply [options]

Common options:
  --type <directory|helm|kustomize>   Application source type (required)
  --name <app-name>                   Application name (required)
  --argocd-namespace <ns>             Namespace of Application CR (default: argocd)
  --project <name>                    ArgoCD project (default: default)
  --repo-url <url>                    Git repo URL (required)
  --path <path>                       Source path in repo (required)
  --revision <rev>                    Git revision/tag/branch (default: master)
  --dest-namespace <ns>               Target workload namespace (required)
  --dest-server <url>                 Destination cluster API (default: https://kubernetes.default.svc)
  --create-namespace <true|false>     Add CreateNamespace sync option (default: true)
  --auto-sync <true|false>            Enable automated.prune/selfHeal (default: false)
  --output <file|->                   Output file for render (default: stdout)

Type specific options:
  directory:
    --recurse <true|false>            Recurse manifests in subdirs (default: true)
  helm:
    --release-name <name>             Helm release name (default: app name)
  kustomize:
    --name-prefix <prefix>            Kustomize namePrefix (optional)

Examples:
  ./argocd-app-publisher.sh render \
    --type directory \
    --name directory-guestbook \
    --repo-url https://jihulab.com/devops_course/argocd-example-apps.git \
    --path guestbook \
    --dest-namespace directory-guestbook \
    --output docs/ops/gitops/argocd/resources/publish-tool/examples/directory-guestbook.yaml

  ./argocd-app-publisher.sh apply \
    --type helm \
    --name helm-app \
    --repo-url https://jihulab.com/devops_course/argocd-example-apps.git \
    --path helm-guestbook \
    --dest-namespace helm-app \
    --release-name my-release \
    --create-namespace true
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

validate_bool() {
  case "$1" in
    true|false) ;;
    *)
      echo "Expected boolean true/false, got: $1" >&2
      exit 1
      ;;
  esac
}

render_source() {
  case "$TYPE" in
    directory)
      cat <<EOF_SRC
  source:
    path: $SOURCE_PATH
    repoURL: $REPO_URL
    targetRevision: $REVISION
    directory:
      recurse: $RECURSE
EOF_SRC
      ;;
    helm)
      local release_name="${RELEASE_NAME:-$APP_NAME}"
      cat <<EOF_SRC
  source:
    path: $SOURCE_PATH
    repoURL: $REPO_URL
    targetRevision: $REVISION
    helm:
      releaseName: $release_name
EOF_SRC
      ;;
    kustomize)
      cat <<EOF_SRC
  source:
    path: $SOURCE_PATH
    repoURL: $REPO_URL
    targetRevision: $REVISION
EOF_SRC
      if [[ -n "$NAME_PREFIX" ]]; then
        cat <<EOF_SRC
    kustomize:
      namePrefix: "$NAME_PREFIX"
EOF_SRC
      fi
      ;;
    *)
      echo "Unsupported type: $TYPE" >&2
      exit 1
      ;;
  esac
}

render_sync_policy() {
  if [[ "$CREATE_NAMESPACE" == "false" && "$AUTO_SYNC" == "false" ]]; then
    echo "  syncPolicy: {}"
    return
  fi

  echo "  syncPolicy:"
  if [[ "$CREATE_NAMESPACE" == "true" ]]; then
    echo "    syncOptions:"
    echo "      - CreateNamespace=true"
  fi

  if [[ "$AUTO_SYNC" == "true" ]]; then
    cat <<'EOF_SYNC'
    automated:
      prune: true
      selfHeal: true
EOF_SYNC
  fi
}

render_application() {
  cat <<EOF_APP
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: $ARGOCD_NAMESPACE
spec:
  project: $PROJECT
EOF_APP

  render_source

  cat <<EOF_APP
  destination:
    namespace: $DEST_NAMESPACE
    server: $DEST_SERVER
EOF_APP

  render_sync_policy
}

run_render() {
  if [[ "$OUTPUT" == "" || "$OUTPUT" == "-" ]]; then
    render_application
  else
    mkdir -p "$(dirname "$OUTPUT")"
    render_application > "$OUTPUT"
    echo "Rendered: $OUTPUT"
  fi
}

run_apply() {
  require_cmd kubectl
  local tmp_file
  tmp_file="$(mktemp)"
  trap 'rm -f "$tmp_file"' EXIT
  render_application > "$tmp_file"
  kubectl apply -f "$tmp_file"

  if [[ -n "$OUTPUT" && "$OUTPUT" != "-" ]]; then
    mkdir -p "$(dirname "$OUTPUT")"
    cp "$tmp_file" "$OUTPUT"
    echo "Saved applied manifest: $OUTPUT"
  fi
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

COMMAND="$1"
shift

TYPE=""
APP_NAME=""
ARGOCD_NAMESPACE="argocd"
PROJECT="default"
REPO_URL=""
SOURCE_PATH=""
REVISION="master"
DEST_NAMESPACE=""
DEST_SERVER="https://kubernetes.default.svc"
CREATE_NAMESPACE="true"
AUTO_SYNC="false"
OUTPUT=""
RECURSE="true"
RELEASE_NAME=""
NAME_PREFIX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      TYPE="$2"
      shift 2
      ;;
    --name)
      APP_NAME="$2"
      shift 2
      ;;
    --argocd-namespace)
      ARGOCD_NAMESPACE="$2"
      shift 2
      ;;
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --repo-url)
      REPO_URL="$2"
      shift 2
      ;;
    --path)
      SOURCE_PATH="$2"
      shift 2
      ;;
    --revision)
      REVISION="$2"
      shift 2
      ;;
    --dest-namespace)
      DEST_NAMESPACE="$2"
      shift 2
      ;;
    --dest-server)
      DEST_SERVER="$2"
      shift 2
      ;;
    --create-namespace)
      CREATE_NAMESPACE="$2"
      shift 2
      ;;
    --auto-sync)
      AUTO_SYNC="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --recurse)
      RECURSE="$2"
      shift 2
      ;;
    --release-name)
      RELEASE_NAME="$2"
      shift 2
      ;;
    --name-prefix)
      NAME_PREFIX="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TYPE" || -z "$APP_NAME" || -z "$REPO_URL" || -z "$SOURCE_PATH" || -z "$DEST_NAMESPACE" ]]; then
  echo "Missing required options." >&2
  usage
  exit 1
fi

case "$TYPE" in
  directory|helm|kustomize) ;;
  *)
    echo "Invalid --type: $TYPE" >&2
    exit 1
    ;;
esac

validate_bool "$CREATE_NAMESPACE"
validate_bool "$AUTO_SYNC"
validate_bool "$RECURSE"

case "$COMMAND" in
  render)
    run_render
    ;;
  apply)
    run_apply
    ;;
  *)
    echo "Unsupported command: $COMMAND" >&2
    usage
    exit 1
    ;;
esac
