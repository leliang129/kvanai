---
sidebar_position: 1
title: Kubernetes 概念
---

# Kubernetes 概念

Kubernetes（简称 K8s）是一个用于自动化部署、扩缩容和运维容器化应用的平台。  
它通过声明式 API 把“应用应该处于什么状态”交给系统持续收敛，减少人工运维成本。

## 1. Kubernetes 是什么

- 核心思想：声明式配置 + 控制器循环（Control Loop）。
- 典型收益：
  - 统一应用部署方式（YAML/API）。
  - 支持滚动发布、自动恢复、弹性伸缩。
  - 将应用运行时与底层机器解耦。

## 2. 核心架构

### 控制平面（Control Plane）

- `kube-apiserver`：集群统一入口，所有操作都经由 API Server。
- `etcd`：保存集群状态的键值存储。
- `kube-scheduler`：为新 Pod 选择合适节点。
- `kube-controller-manager`：运行 Deployment/Node/Job 等控制器，持续对齐“期望状态”。

### 工作节点（Worker Node）

- `kubelet`：负责节点上 Pod 的生命周期管理。
- `container runtime`（如 `containerd`）：实际运行容器。
- `kube-proxy`：实现 Service 转发与负载均衡规则。

## 3. 对象模型（常用资源）

- `Pod`：最小调度单元，通常包含一个或多个紧耦合容器。
- `Deployment`：无状态应用管理，支持滚动更新与回滚。
- `StatefulSet`：有状态应用管理，强调稳定网络标识与持久存储。
- `DaemonSet`：在每个（或指定）节点上运行一个 Pod 副本。
- `Job/CronJob`：一次性任务与定时任务。
- `Service`：稳定访问入口，解耦 Pod IP 变化。
- `Ingress`：七层流量入口（域名/路径路由）。
- `ConfigMap/Secret`：配置与敏感信息管理。

## 4. 网络与服务发现

- 每个 Pod 都有独立 IP（由 CNI 负责实现）。
- `Service` 提供稳定虚拟 IP 和服务发现能力。
- CoreDNS 提供集群内 DNS 解析（例如 `svc.namespace.svc.cluster.local`）。
- 常见 Service 类型：
  - `ClusterIP`：集群内部访问。
  - `NodePort`：通过节点端口对外暴露。
  - `LoadBalancer`：依赖云厂商负载均衡。

## 5. 调度与资源管理

- `requests/limits`：定义容器资源请求与上限。
- QoS 类别：`Guaranteed` / `Burstable` / `BestEffort`。
- `taints/tolerations`：控制“哪些 Pod 能调度到哪些节点”。
- `nodeSelector/affinity`：按标签和亲和性做调度约束。
- 自动伸缩：`HPA`（按指标扩缩容副本数）。

## 6. 应用生命周期

- 健康检查：
  - `livenessProbe`：判断是否需要重启容器。
  - `readinessProbe`：决定是否接收流量。
  - `startupProbe`：给慢启动应用预热时间。
- 发布策略：
  - `RollingUpdate`（默认滚动发布）。
  - `Recreate`（先删后建）。
- 观测入口：
  - `kubectl get/describe` 看资源状态与事件。
  - `kubectl logs` 看容器日志。
  - `kubectl top` 看资源使用（需 metrics-server）。

## 7. 学习路径建议

1. 先掌握对象模型：`Pod`、`Deployment`、`Service`。
2. 再理解 Pod 生命周期与资源治理：探针、重启策略、requests/limits、优雅终止。
3. 学习工作负载控制器：ReplicaSet/Deployment、StatefulSet/DaemonSet、Job/CronJob。
4. 最后进入集群搭建与运维：kubeadm 安装、升级、备份与排障。

## 延伸阅读

- [Pod 基础与资源清单](./pod)
- [控制器、ReplicaSet 与 Deployment](./controller-rs-deployment)
- [StatefulSet 与 DaemonSet](./controller-sts-daemonset)
- [Job 与 CronJob](./job-cronjob)
- [kubeadm 搭建 Kubernetes 集群](./kubeadm)
- [Kubernetes 官方文档](https://kubernetes.io/docs/)
- [CNCF Landscape](https://landscape.cncf.io/)
