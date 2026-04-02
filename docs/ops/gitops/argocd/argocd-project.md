---
title: ArgoCD Project介绍与管理
sidebar_position: 4
---

`AppProject` 是 ArgoCD 的权限边界对象。它不直接部署应用，而是约束 `Application` 可以：

- 从哪些 Git 仓库拉取配置（`sourceRepos`）
- 部署到哪些集群/命名空间（`destinations`）
- 管理哪些 Kubernetes 资源类型（白名单/黑名单）
- 哪些角色可以执行哪些动作（`roles + policies`）

在团队场景里，建议始终先设计 `AppProject`，再让应用挂到对应 `project`。

## 1. Project 与 Application 的关系

```text
Git Repo -> Application -> Kubernetes
             │
             ▼
         AppProject
     (仓库/目标/资源/权限边界)
```

如果 `Application` 不满足 `AppProject` 约束，ArgoCD 会直接拒绝同步或操作。

## 2. AppProject 核心字段

常用字段如下：

- `spec.sourceRepos`：允许访问的 Git 仓库白名单。
- `spec.destinations`：允许部署的目标白名单（`server + namespace`）。
- `spec.clusterResourceWhitelist`：允许管理的集群级资源类型。
- `spec.namespaceResourceWhitelist`：允许管理的命名空间级资源类型。
- `spec.roles`：项目级角色，配合 Casbin 策略控制 API 权限。
- `spec.orphanedResources.warn`：是否告警孤儿资源。

说明：

- 白名单优先用于最小权限收敛。
- 黑名单更适合“已放通很多类型后再补充限制”的场景。

## 3. 管理方式

### 3.1 Web UI

路径：`Settings -> Projects -> New Project`。

建议按顺序配置：

1. `Source Repositories`
2. `Destinations`
3. `Resource allow/deny list`
4. `Project Roles`

### 3.2 ArgoCD CLI

```bash
# 登录
argocd login <argocd-server>

# 查看项目
argocd proj list
argocd proj get default

# 创建项目（最小示例）
argocd proj create platform

# 添加允许仓库
argocd proj add-source platform https://github.com/your-org/ops-manifests.git

# 添加允许目标（集群 + 命名空间）
argocd proj add-destination platform https://kubernetes.default.svc dev
argocd proj add-destination platform https://kubernetes.default.svc prod

# 删除项目
argocd proj delete platform
```

### 3.3 声明式 YAML（推荐）

建议把 `AppProject` 纳入 Git 仓库统一管理，和 `Application` 一样走审查与审计流程。

可直接应用：

```bash
kubectl apply -f appproject-platform.yaml
```

`appproject-platform.yaml` 完整示例：

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

## 4. Project Role 与权限控制

`spec.roles[].policies` 使用 Casbin 语法，常见格式：

```text
p, <subject>, <resource>, <action>, <object>, <effect>
```

常见实践：

- 允许开发角色 `get/sync`，禁止 `delete`。
- 发布流水线使用项目级 JWT Token，而不是长期使用 `admin`。
- Token 只在安全系统中保存（CI Secret Manager / Vault），禁止写入文档与仓库。

### 4.1 Role YAML 示例

可直接应用：

```bash
kubectl apply -f appproject-dev1-role.yaml
```

`appproject-dev1-role.yaml` 完整示例：

```yaml
# Project + Role 完整示例：演示项目边界与角色策略
# ArgoCD Project 资源版本
apiVersion: argoproj.io/v1alpha1
# 资源类型：AppProject
kind: AppProject
metadata:
  # Project 名称
  name: dev1
  # AppProject 所在命名空间（固定为 argocd 控制面）
  namespace: argocd
spec:
  # 项目说明
  description: dev1 group

  # 允许访问的 Git 仓库白名单（支持通配）
  sourceRepos:
    - https://jihulab.com/devops_course/**

  # 允许部署目标白名单（server + namespace 必须同时匹配）
  destinations:
    - name: in-cluster
      server: https://kubernetes.default.svc
      namespace: dev1

  # 集群级资源白名单（示例只允许 Namespace）
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace

  # 命名空间级资源白名单（示例放开全部，生产建议收敛）
  namespaceResourceWhitelist:
    - group: "*"
      kind: "*"

  # 项目角色定义
  roles:
    - name: dev1-role
      # Casbin 策略：p, 主体, 资源, 动作, 对象, 允许/拒绝
      policies:
        # 允许读取应用
        - p, proj:dev1:dev1-role, applications, get, dev1/*, allow
        # 允许同步应用
        - p, proj:dev1:dev1-role, applications, sync, dev1/*, allow
        # 显式拒绝删除应用
        - p, proj:dev1:dev1-role, applications, delete, dev1/*, deny
```

### 4.2 Role Token 管理

```bash
# 创建角色（若未创建）
argocd proj role create dev1 dev1-role

# 为角色签发 token（默认不展示历史 token 明文）
argocd proj role create-token dev1 dev1-role

# 查看角色策略
argocd proj role get dev1 dev1-role
```

安全建议：

- 仅在签发当次复制 token，后续不在文档中存储明文。
- 为自动化场景设置 token 过期时间并定期轮换。

## 5. 项目治理建议

- 一团队一项目：避免多个团队共享一个过宽项目。
- 一环境一命名空间：`dev/stage/prod` 强制隔离。
- 仓库白名单精确到组织/项目，不要直接放开 `*`。
- 生产项目默认禁止 `Application delete`。
- 开启孤儿资源告警，防止“集群有资源但 Git 无声明”。

## 6. 常见问题与排查

### Q1：Application 报权限不足（PermissionDenied）

优先检查：

- `spec.project` 是否存在且名称正确。
- `source.repoURL` 是否在 `sourceRepos` 白名单中。
- `destination.server/namespace` 是否在 `destinations` 白名单中。
- 目标资源类型是否在 whitelist 中。

### Q2：能查看应用但不能同步/删除？

通常是 `roles.policies` 仅放通了 `get`，未放通 `sync` 或显式 `deny delete`。这属于预期行为，按角色职责调整即可。

### Q3：Project 更新后为什么不生效？

先确认：

- 是否改对了 `argocd` 命名空间中的 `AppProject`。
- 是否由其他 GitOps 流程回滚了手工变更。
- `argocd-application-controller` 日志是否存在策略拒绝记录。

## 7. 关联文档

- [ArgoCD 安装部署](./argocd-install.md)
- [ArgoCD APP配置](./argocd-app.md)
- [ArgoCD 应用发布工具](./argocd-app-publisher.md)
- ArgoCD 官方 Project 示例：[project.yaml](https://argo-cd.readthedocs.io/en/stable/operator-manual/project.yaml)
