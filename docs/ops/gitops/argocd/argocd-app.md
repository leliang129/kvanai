---
title: ArgoCD APP配置
sidebar_position: 2
---

本文聚焦 ArgoCD 中最核心的两个资源：`AppProject` 与 `Application`。目标是让你能快速看懂 APP 配置结构，并直接复用一套可落地的资源文件。

## 1. 配置关系先看懂

在 ArgoCD 里，通常是这样的关系：

```text
Git Repo (manifests/helm/kustomize)
        │
        ▼
AppProject（定义权限边界）
        │
        ▼
Application（定义“从哪里拉、部署到哪里、如何同步”）
```

如果把 `Application` 当成“发布任务”，那 `AppProject` 就是这个任务的“权限围栏”。

## 2. Application 关键字段梳理

一个 `Application` 主要看 5 块：

- `metadata`：应用名、命名空间、回收策略（finalizer）。
- `spec.project`：挂到哪个 `AppProject`，决定它能去哪些仓库、哪些集群/命名空间。
- `spec.source`：Git/Helm 来源配置。
- `spec.destination`：目标集群与目标命名空间。
- `spec.syncPolicy`：同步策略（手动/自动、是否 prune/self-heal、重试策略等）。

### 2.1 source 常见写法

`Kustomize/纯 YAML`：

```yaml
spec:
  source:
    # Git 仓库地址（应用声明来源）
    repoURL: https://github.com/your-org/ops-manifests.git
    # 分支/Tag/Commit，建议生产用固定 tag 或 commit
    targetRevision: main
    # 仓库内清单路径（支持目录、Kustomize overlay）
    path: apps/nginx/overlays/dev
```

`Helm Chart 仓库`：

```yaml
spec:
  source:
    # Helm Chart 仓库地址（也可用 Git + path）
    repoURL: https://charts.bitnami.com/bitnami
    # Chart 名称
    chart: nginx
    # Chart 版本
    targetRevision: 18.1.5
    helm:
      # Helm release 名称，默认可使用 Application 名称
      releaseName: nginx
      # 内联 values，用于覆盖 chart 默认值
      values: |
        service:
          type: ClusterIP
```

### 2.2 syncPolicy 常见开关

- `automated.prune`：删除 Git 中已移除的资源。
- `automated.selfHeal`：集群被手改后自动拉回 Git 声明状态。
- `syncOptions.CreateNamespace=true`：目标命名空间不存在时自动创建。
- `syncOptions.ApplyOutOfSyncOnly=true`：只 apply 漂移资源，减少不必要操作。
- `syncOptions.ServerSideApply=true`：使用 SSA，适合复杂字段合并场景。

## 3. 资源文件组织建议

本文提供了一组示例资源文件：

```text
00-appproject-platform.yaml
10-app-nginx-dev.yaml
20-app-nginx-prod.yaml
```

推荐约定：

- `00-` 放项目级资源（如 `AppProject`），先于应用对象创建。
- `10-` 放开发/测试环境应用。
- `20-` 放生产环境应用。

## 4. 新增资源文件说明

### 4.1 00-appproject-platform.yaml

用途：定义 `platform` 项目，限制应用只能从指定 Git 仓库拉取，并且只能部署到 `dev/prod` 命名空间。

关键点：

- `sourceRepos`：白名单 Git 仓库。
- `destinations`：白名单目标集群 + 命名空间。
- `clusterResourceWhitelist`：允许管理的集群级资源（示例仅放开 `Namespace`）。
- `namespaceResourceWhitelist`：允许管理的命名空间级资源类型。

完整示例：

```yaml
# 项目级权限边界：先创建 AppProject，再创建挂载到该项目的 Application
# ArgoCD Project 资源版本
apiVersion: argoproj.io/v1alpha1
# 资源类型：AppProject
kind: AppProject
metadata:
  # Project 名称（Application 通过 spec.project 引用）
  name: platform
  # AppProject 必须位于 argocd 控制面命名空间
  namespace: argocd
spec:
  # 项目描述，便于 UI 识别
  description: "Platform team managed applications"

  # 允许拉取清单的 Git 仓库白名单
  sourceRepos:
    - https://github.com/your-org/ops-manifests.git

  # 允许部署到的目标白名单（集群 + 命名空间）
  destinations:
    # 开发环境命名空间
    - namespace: dev
      # in-cluster API 地址
      server: https://kubernetes.default.svc
    # 生产环境命名空间
    - namespace: prod
      server: https://kubernetes.default.svc

  # 集群级资源白名单，示例只允许 Namespace
  clusterResourceWhitelist:
    # group 为空表示 core API 组
    - group: ""
      kind: Namespace

  # 命名空间级资源白名单，按需收敛权限
  namespaceResourceWhitelist:
    - group: ""
      kind: ConfigMap
    - group: ""
      kind: Secret
    - group: ""
      kind: Service
    - group: apps
      kind: Deployment
    - group: networking.k8s.io
      kind: Ingress

  # 开启孤儿资源告警（资源存在于集群但不在 Git 声明中）
  orphanedResources:
    warn: true
```

### 4.2 10-app-nginx-dev.yaml

用途：开发环境应用，默认手动同步，避免变更自动进入 dev 集群。

关键点：

- `project: platform`：继承项目级权限边界。
- `path: apps/nginx/overlays/dev`：明确 dev overlay 路径。
- 未开启 `automated`：保留人工审核节奏。
- `CreateNamespace=true`：首次部署可自动建命名空间。

完整示例：

```yaml
# 开发环境 Application：默认手动同步，适合变更频繁阶段
# ArgoCD Application 资源版本
apiVersion: argoproj.io/v1alpha1
# 资源类型：Application
kind: Application
metadata:
  # 应用名称（ArgoCD 内唯一）
  name: nginx-dev
  # Application CR 所在命名空间（通常固定为 argocd）
  namespace: argocd
  finalizers:
    # 删除 Application 时级联删除其管理的资源
    - resources-finalizer.argocd.argoproj.io
spec:
  # 绑定到前面定义的 AppProject
  project: platform

  # 发布源配置（Git）
  source:
    # Git 仓库地址
    repoURL: https://github.com/your-org/ops-manifests.git
    # 分支/Tag/Commit
    targetRevision: main
    # 仓库内清单路径
    path: apps/nginx/overlays/dev

  # 发布目标配置
  destination:
    # 目标集群 API 地址
    server: https://kubernetes.default.svc
    # 目标工作负载命名空间
    namespace: dev

  # 开发环境示例：只配置同步选项，不开启 automated
  syncPolicy:
    syncOptions:
      # 命名空间不存在时自动创建
      - CreateNamespace=true
      # 删除操作放在同步末尾，避免顺序导致的依赖问题
      - PruneLast=true
      # 仅同步漂移资源，减少重复 apply
      - ApplyOutOfSyncOnly=true

  # 保留最近 5 次部署历史
  revisionHistoryLimit: 5
```

### 4.3 20-app-nginx-prod.yaml

用途：生产环境应用，开启自动同步 + 自愈，适合稳定场景。

关键点：

- `automated.prune/selfHeal`：自动对齐 Git 与集群状态。
- `retry`：同步失败时指数退避重试。
- `ignoreDifferences`：忽略 `Deployment.spec.replicas` 漂移，避免和 HPA 打架。

完整示例：

```yaml
# 生产环境 Application：开启自动同步 + 自愈 + 重试
# ArgoCD Application 资源版本
apiVersion: argoproj.io/v1alpha1
# 资源类型：Application
kind: Application
metadata:
  # 应用名称
  name: nginx-prod
  # Application CR 所在命名空间
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  # 绑定项目，受项目白名单与角色策略约束
  project: platform

  source:
    # Git 仓库地址
    repoURL: https://github.com/your-org/ops-manifests.git
    # 分支/Tag/Commit
    targetRevision: main
    # 生产环境 overlay 路径
    path: apps/nginx/overlays/prod

  destination:
    # 目标集群 API
    server: https://kubernetes.default.svc
    # 目标命名空间
    namespace: prod

  syncPolicy:
    # 自动同步策略
    automated:
      # 清理 Git 中已删除的资源
      prune: true
      # 发现漂移后自动回正
      selfHeal: true
      # 禁止空应用（防止误删全部资源）
      allowEmpty: false
    # 同步失败重试策略
    retry:
      limit: 5
      backoff:
        # 首次重试等待时间
        duration: 10s
        # 指数退避系数
        factor: 2
        # 最大退避时间
        maxDuration: 3m
    syncOptions:
      # 自动创建命名空间
      - CreateNamespace=true
      # 删除传播策略：前台删除，等待依赖资源清理完成
      - PrunePropagationPolicy=foreground
      # 启用 ignoreDifferences 配置
      - RespectIgnoreDifferences=true
      # 使用 Server Side Apply
      - ServerSideApply=true

  # 忽略副本数差异，避免与 HPA 控制冲突
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        # 忽略 Deployment 副本数字段
        - /spec/replicas

  # 保存最近 10 次部署历史，便于回滚与审计
  revisionHistoryLimit: 10
```

## 5. 示例资源应用方式

首次创建（按顺序）：

```bash
# 先创建 Project（权限边界）
kubectl apply -f 00-appproject-platform.yaml
# 再创建 dev 环境应用
kubectl apply -f 10-app-nginx-dev.yaml
# 最后创建 prod 环境应用
kubectl apply -f 20-app-nginx-prod.yaml
```

检查状态：

```bash
# 查看 Project 是否创建成功
kubectl get appproject -n argocd
# 查看 Application 列表
kubectl get applications.argoproj.io -n argocd
# 查看 ArgoCD 侧应用状态
argocd app list
# 查看单个应用详情
argocd app get nginx-dev
argocd app get nginx-prod
```

## 6. 常见配置坑位

- `Application` 在 `argocd` 命名空间之外创建，导致控制器不处理。
- `project` 名称不匹配，或 `AppProject` 权限白名单没有放通目标仓库/命名空间。
- `path` 指向错误目录，Repo Server 渲染失败。
- 生产环境开了 `prune`，但没有做资源命名稳定性设计，导致误删。
- 已使用 HPA 却没有设置 `ignoreDifferences`，导致副本数持续抖动。

## 7. 应用发布工具

如果你希望通过统一命令快速生成/发布 `Application`，可直接使用本文配套的发布工具：

- [ArgoCD 应用发布工具](./argocd-app-publisher.md)
