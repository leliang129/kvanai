---
title: ArgoCD 安装部署
sidebar_position: 2
---

本文以 Kubernetes 集群中的标准安装方式为主，覆盖 `非 HA` 与 `HA` 两种部署路径，并补充初始化登录、CLI 安装与生产环境建议，便于快速落地 ArgoCD。

> 参考官方文档：Argo CD Getting Started、Operator Manual / Installation。文末附官方链接。

## 1. 安装前准备

建议先确认以下条件：

- 已有可用的 Kubernetes 集群。
- 本地已安装并配置 `kubectl`，且当前上下文具备集群管理员或等效权限。
- 集群能够拉取 ArgoCD 镜像。
- 规划好暴露方式：测试环境可用 `port-forward`，生产环境建议 `Ingress` 或 `LoadBalancer`。

可先执行以下命令做基础检查：

```bash
kubectl cluster-info
kubectl get nodes
kubectl auth can-i create namespace
```

## 2. 创建命名空间

官方默认将 ArgoCD 安装在 `argocd` 命名空间：

```bash
kubectl create namespace argocd
```

如果命名空间已存在，可以忽略 `AlreadyExists` 提示。

## 3. 标准安装（非 HA）

适合测试环境、小规模集群或初次体验。

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

安装完成后，建议确认核心组件状态：

```bash
kubectl get pods -n argocd
kubectl get svc -n argocd
kubectl get deploy -n argocd
```

常见核心组件包括：

- `argocd-server`
- `argocd-repo-server`
- `argocd-application-controller`
- `argocd-dex-server`
- `argocd-redis`

如果 Pod 长时间未就绪，优先检查：

```bash
kubectl describe pod -n argocd <pod-name>
kubectl logs -n argocd <pod-name>
```

## 4. 高可用安装（HA）

如果用于生产环境，建议直接采用官方 HA 清单：

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml
```

HA 方案通常会对控制器、Repo Server、Redis 等组件做更适合生产的部署调整，但是否真正满足你的生产要求，还要结合以下因素评估：

- 节点数量与可用区分布
- Ingress / LB 可用性
- 外部身份认证（SSO）
- 备份与灾备策略
- 监控、告警与日志采集

## 5. 访问 ArgoCD Server

### 5.1 测试环境：使用端口转发

最快的访问方式是 `port-forward`：

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

然后访问：

- `https://localhost:8080`

默认情况下会使用自签名证书，浏览器出现证书警告属于正常现象。

### 5.2 生产环境：Ingress / LoadBalancer

生产建议将 `argocd-server` 通过以下方式之一暴露：

- `Ingress`
- `LoadBalancer`
- 企业内网网关 / API Gateway

同时建议统一处理：

- TLS 证书
- 域名访问
- SSO / OIDC 登录
- 访问审计

## 6. 获取初始管理员密码

ArgoCD 初始管理员用户名默认为 `admin`。

较新的版本可直接通过以下命令读取初始密码：

```bash
argocd admin initial-password -n argocd
```

如果你的环境暂时没有安装 `argocd` CLI，也可以直接读取 Secret：

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

> 首次登录后，建议立即修改 `admin` 密码，或直接禁用 `admin` 本地账号并切换到 SSO。

## 7. 安装 ArgoCD CLI

### macOS（Homebrew）

```bash
brew install argocd
```

### Linux / 其他平台

建议从官方发布页下载对应二进制，或按官方文档说明安装。

安装完成后可检查版本：

```bash
argocd version
```

## 8. CLI 登录验证

如果使用前文的本地端口转发，可直接执行：

```bash
argocd login localhost:8080 \
  --username admin \
  --password '<初始密码>' \
  --insecure
```

验证是否登录成功：

```bash
argocd account get-user-info
argocd cluster list
```

## 9. 首次安装后的推荐操作

安装完成后，建议至少补齐以下配置：

### 9.1 修改管理员密码

```bash
argocd account update-password
```

### 9.2 接入 Git 仓库

```bash
argocd repo add https://github.com/example/repo.git
```

如果是私有仓库，需补充认证信息（PAT / SSH Key / GitHub App 等）。

### 9.3 注册集群

如果 ArgoCD 管理当前集群，通常安装时已具备默认上下文；若要管理其他集群，需要额外注册：

```bash
argocd cluster add <context-name>
```

### 9.4 创建测试应用

建议尽快创建一个最小 `Application`，验证：

- Repo 连通性
- Manifest 渲染是否正常
- 同步权限是否完整
- 健康检查是否正常

## 10. 生产环境建议

生产环境中，建议不要停留在“装上能用”的状态，而是补齐以下治理项：

- 使用 `HA` 清单，而不是默认单副本方案。
- 为关键组件设置合适的 `resources.requests/limits`。
- 接入 `Ingress`、正式域名与可信 TLS 证书。
- 对接企业统一身份认证（如 OIDC / SSO）。
- 尽量避免长期使用本地 `admin` 账号。
- 接入监控与告警，重点关注 `argocd-server`、`repo-server`、`application-controller`。
- 规划 GitOps 仓库结构、分支策略与环境隔离。
- 对 `AppProject` 做权限边界控制，避免应用越权访问集群资源。

## 11. 卸载方法

如果只是实验环境需要清理，可以删除安装清单对应资源：

```bash
kubectl delete -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

如需彻底清理命名空间：

```bash
kubectl delete namespace argocd
```

## 12. 常见问题

### Q1：`argocd-server` 一直无法访问？

优先检查：

- `svc/argocd-server` 是否存在
- `port-forward` 是否正常监听
- 浏览器是否被证书拦截
- 网络策略 / 防火墙 / Ingress 配置是否阻断

### Q2：初始密码获取失败？

先确认相关 Secret 是否存在：

```bash
kubectl get secret -n argocd
```

若 `argocd-initial-admin-secret` 不存在，可能是版本行为差异或初始化尚未完成，可先查看 `argocd-server` 日志与官方文档说明。

### Q3：应该选默认安装还是 HA？

- 学习 / 测试：默认安装足够
- 生产 / 团队协作：优先 HA

## 参考资料

- Argo CD Getting Started: https://argo-cd.readthedocs.io/en/stable/getting_started/
- Argo CD Installation: https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/
- Argo CD CLI Installation: https://argo-cd.readthedocs.io/en/stable/cli_installation/
