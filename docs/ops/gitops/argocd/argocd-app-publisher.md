---
title: ArgoCD 应用发布工具
sidebar_position: 3
---

本文提供一个轻量的 `ArgoCD Application` 发布工具脚本，支持 `Directory`、`Helm`、`Kustomize` 三种模式，便于快速生成并发布应用。

参考资料：

- Application 配置参考：[application.yaml](https://argo-cd.readthedocs.io/en/stable/operator-manual/application.yaml)
- 实验代码库：[argocd-example-apps](https://jihulab.com/devops_course/argocd-example-apps)

## 1. 工具目录

```text
publish-tool/
├── argocd-app-publisher.sh
└── examples/
    ├── directory-guestbook.yaml
    ├── helm-app.yaml
    └── guestbook-kustomize.yaml
```

## 2. 快速开始

以下命令假设在 `publish-tool` 目录下执行。

### 2.1 生成并查看 YAML

```bash
# 按目录模式渲染 Application YAML 到文件
bash ./argocd-app-publisher.sh render \
  --type directory \
  --name directory-guestbook \
  --repo-url https://jihulab.com/devops_course/argocd-example-apps.git \
  --path guestbook \
  --revision master \
  --dest-namespace directory-guestbook \
  --output ./examples/directory-guestbook.yaml
```

### 2.2 直接发布到集群

```bash
# 按 Helm 模式直接生成并 apply 到集群
bash ./argocd-app-publisher.sh apply \
  --type helm \
  --name helm-app \
  --repo-url https://jihulab.com/devops_course/argocd-example-apps.git \
  --path helm-guestbook \
  --revision master \
  --dest-namespace helm-app \
  --release-name my-release \
  --create-namespace true
```

## 3. 三种模式示例

### 3.1 Directory

```bash
# Directory 模式：递归读取 guestbook 目录下清单
bash ./argocd-app-publisher.sh render \
  --type directory \
  --name directory-guestbook \
  --repo-url https://jihulab.com/devops_course/argocd-example-apps.git \
  --path guestbook \
  --dest-namespace directory-guestbook \
  --recurse true
```

对应示例文件：`directory-guestbook.yaml`

Directory 高级字段参考：

```yaml
spec:
  source:
    directory:
      # true 表示递归扫描子目录中的清单文件
      recurse: true
      jsonnet:
        # Jsonnet 外部变量（ext-code/ext-str）
        extVars:
          - name: foo
            value: bar
          - code: true
            name: baz
            value: "true"
        tlas:
          - code: false
            name: foo
            value: bar
      # 显式排除某些文件/目录（优先级高于 include）
      exclude: "config.yaml"
      # 仅包含匹配的清单文件
      include: "*.yaml"
```

### 3.2 Helm

```bash
# Helm 模式：从仓库 helm-guestbook 目录生成 Application
bash ./argocd-app-publisher.sh render \
  --type helm \
  --name helm-app \
  --repo-url https://jihulab.com/devops_course/argocd-example-apps.git \
  --path helm-guestbook \
  --dest-namespace helm-app \
  --release-name my-release
```

对应示例文件：`helm-app.yaml`

Helm 高级字段参考：

```yaml
spec:
  source:
    helm:
      # 向所有 chart 依赖域透传凭证（默认 false）
      passCredentials: false
      # 以 --set 方式覆盖 values
      parameters:
        - name: "nginx-ingress.controller.service.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
          value: mydomain.example.com
        - name: "ingress.annotations.kubernetes\\.io/tls-acme"
          value: "true"
          forceString: true
      # 以 --set-file 注入文件内容
      fileParameters:
        - name: config
          path: files/config.json
      # 覆盖 release 名称（默认 Application 名称）
      releaseName: guestbook
      # 额外 values 文件（相对 spec.source.path）
      valueFiles:
        - values-prod.yaml
      # 是否忽略缺失的 values 文件
      ignoreMissingValueFiles: false
      # 直接内联 values 配置
      values: |
        ingress:
          enabled: true
          path: /
          hosts:
            - mydomain.example.com
          annotations:
            kubernetes.io/ingress.class: nginx
            kubernetes.io/tls-acme: "true"
          tls:
            - secretName: mydomain-tls
              hosts:
                - mydomain.example.com
      # 若 chart 自带 CRD，是否跳过 CRD 安装
      skipCrds: false
      # 指定 Helm 模板版本（通常使用 v3）
      version: v3
```

### 3.3 Kustomize

```bash
# Kustomize 模式：生成带 namePrefix 的应用配置
bash ./argocd-app-publisher.sh render \
  --type kustomize \
  --name guestbook-kustomize \
  --repo-url https://jihulab.com/devops_course/argocd-example-apps.git \
  --path kustomize-guestbook \
  --dest-namespace kustomize-guestbook \
  --name-prefix staging-
```

对应示例文件：`guestbook-kustomize.yaml`

Kustomize 高级字段参考：

```yaml
spec:
  source:
    kustomize:
      # 指定 Kustomize 版本（需在 argocd-cm 里预配置）
      version: v3.5.4
      # 统一资源名称前后缀
      namePrefix: prod-
      nameSuffix: -some-suffix
      # 给所有资源追加公共标签/注解
      commonLabels:
        foo: bar
      commonAnnotations:
        beep: boop
      # 批量重写镜像
      images:
        - gcr.io/heptio-images/ks-guestbook-demo:0.2
        - my-app=gcr.io/my-repo/my-app:0.1
```

## 4. 完整示例文件

### 4.1 directory-guestbook.yaml（完整示例）

```yaml
# ArgoCD Application 资源版本
apiVersion: argoproj.io/v1alpha1
# 资源类型：声明一个 ArgoCD 应用
kind: Application
metadata:
  # Application 名称（ArgoCD 内唯一）
  name: directory-guestbook
  # Application CR 必须位于 argocd 命名空间
  namespace: argocd
spec:
  # 目标集群与命名空间
  destination:
    namespace: directory-guestbook
    server: https://kubernetes.default.svc
  # 归属项目（受 AppProject 权限边界约束）
  project: default
  # 应用来源（Git + path）
  source:
    path: guestbook
    repoURL: https://jihulab.com/devops_course/argocd-example-apps.git
    targetRevision: master
    directory:
      # 递归扫描子目录中的 YAML/Jsonnet 清单
      recurse: true
  # 同步策略
  syncPolicy:
    syncOptions:
      # 目标命名空间不存在时自动创建
      - CreateNamespace=true
```

### 4.2 helm-app.yaml（完整示例）

```yaml
# ArgoCD Application 资源版本
apiVersion: argoproj.io/v1alpha1
# 资源类型：声明一个 ArgoCD 应用
kind: Application
metadata:
  # 应用名称
  name: helm-app
  # ArgoCD 控制面命名空间
  namespace: argocd
spec:
  # 应用所属 Project
  project: default
  # 应用来源（Git 仓库中的 Helm 目录）
  source:
    path: helm-guestbook
    repoURL: https://jihulab.com/devops_course/argocd-example-apps.git
    targetRevision: master
    helm:
      # Helm release 名称（不指定时通常默认应用名）
      releaseName: my-release
  # 发布目标集群与命名空间
  destination:
    server: https://kubernetes.default.svc
    namespace: helm-app
  # 同步策略
  syncPolicy:
    syncOptions:
      # 目标命名空间不存在时自动创建
      - CreateNamespace=true
```

### 4.3 guestbook-kustomize.yaml（完整示例）

```yaml
# ArgoCD Application 资源版本
apiVersion: argoproj.io/v1alpha1
# 资源类型：声明一个 ArgoCD 应用
kind: Application
metadata:
  # 应用名称
  name: guestbook-kustomize
  # ArgoCD 控制面命名空间
  namespace: argocd
spec:
  # 应用来源（Git + Kustomize 目录）
  source:
    repoURL: https://jihulab.com/devops_course/argocd-example-apps.git
    targetRevision: master
    path: kustomize-guestbook
    kustomize:
      # 为生成资源统一添加名称前缀
      namePrefix: "staging-"
  # 发布目标集群与命名空间
  destination:
    namespace: kustomize-guestbook
    server: https://kubernetes.default.svc
  # 应用所属 Project
  project: default
  # 同步策略
  syncPolicy:
    syncOptions:
      # 目标命名空间不存在时自动创建
      - CreateNamespace=true
```

## 5. 发布脚本完整示例

脚本文件：`argocd-app-publisher.sh`

```bash
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
    --output ./examples/directory-guestbook.yaml

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
```

## 6. 参数说明

通用参数：

- `--type`：`directory|helm|kustomize`
- `--name`：Application 名称
- `--argocd-namespace`：Application CR 所在命名空间，默认 `argocd`
- `--project`：ArgoCD 项目，默认 `default`
- `--repo-url`：Git 仓库地址
- `--path`：仓库内路径
- `--revision`：分支/Tag/Commit，默认 `master`
- `--dest-namespace`：目标工作负载命名空间
- `--dest-server`：目标集群 API，默认 `https://kubernetes.default.svc`
- `--create-namespace`：是否追加 `CreateNamespace=true`
- `--auto-sync`：是否开启 `automated.prune/selfHeal`
- `--output`：渲染输出路径，`-` 表示 stdout

类型参数：

- `Directory`：`--recurse`
- `Helm`：`--release-name`
- `Kustomize`：`--name-prefix`

## 7. 高级字段扩展建议

脚本默认输出最常用字段。若要启用高级参数，建议在生成后的 YAML 上补充：

- `directory.jsonnet.extVars/tlas`
- `directory.include/exclude`
- `helm.parameters/fileParameters/valueFiles/values`
- `helm.skipCrds/version`
- `kustomize.images/commonLabels/commonAnnotations`

这些字段的完整定义请以官方文档为准：

- [application.yaml](https://argo-cd.readthedocs.io/en/stable/operator-manual/application.yaml)

## 8. 验证命令

```bash
# 查看 Application CR 列表
kubectl get applications.argoproj.io -n argocd
# 查看 ArgoCD 管理的应用列表
argocd app list
# 查看某个应用的详细状态
argocd app get directory-guestbook
```
