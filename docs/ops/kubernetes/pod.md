---
sidebar_position: 3
title: Pod 理论基础与进阶
---

# Pod 使用全景（基础、生命周期与进阶）

Pod 是 Kubernetes 中最小的调度与运行单元。本文将原先分散的基础、生命周期和进阶内容合并为一篇，便于按一条主线学习与排障。

## 1. Pod 基础认知

### 1.1 为什么 Kubernetes 管的是 Pod，而不是单容器

- 调度粒度统一：调度器只处理 Pod。
- 运行上下文共享：同一 Pod 内容器共享网络与数据卷。
- 支持 Sidecar：日志、代理、证书等辅助能力可伴随主容器部署。

### 1.2 Pod 与容器关系

- 一个 Pod 可包含一个或多个容器。
- Pod 内容器共享：
  - 同一个 Pod IP
  - 显式声明并挂载的数据卷
- 不同 Pod 之间不共享上述上下文。

### 1.3 资源清单核心字段

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
```

关键字段：`apiVersion`、`kind`、`metadata`、`spec`。

### 1.4 为什么生产不直接管理裸 Pod

生产一般通过控制器管理 Pod（Deployment/StatefulSet/DaemonSet），因为控制器会负责：

- 副本维持
- 滚动发布
- 自愈恢复

## 2. Pod 生命周期

### 2.1 Pod Phase

- `Pending`：待调度或镜像拉取中
- `Running`：至少一个容器运行中
- `Succeeded`：全部容器成功退出
- `Failed`：至少一个容器失败退出
- `Unknown`：状态暂不可达

排障第一步：

```bash
kubectl get pod <pod-name> -o wide
kubectl describe pod <pod-name>
```

### 2.2 Pod Conditions

重点看：

- `PodScheduled`
- `Initialized`
- `ContainersReady`
- `Ready`

建议始终联合观察：`phase + conditions + events`。

### 2.3 restartPolicy

Pod 级重启策略：

- `Always`（默认）
- `OnFailure`
- `Never`

> 由 Deployment 管理的 Pod，通常使用 `Always`。

### 2.4 Init Containers

Init Container 会在业务容器前顺序执行，常用于：

- 依赖探测
- 配置渲染
- 初始化数据准备

```yaml
initContainers:
- name: init-html
  image: busybox
  command: ["sh", "-c", "echo hello > /work/index.html"]
```

### 2.5 生命周期钩子（Hook）

- `postStart`：容器启动后触发
- `preStop`：容器终止前触发

常用于预热、摘流、优雅停机。

### 2.6 健康检查（Probes）

- `startupProbe`：慢启动保护
- `livenessProbe`：是否需要重启
- `readinessProbe`：是否可接收流量

探针失败是最常见线上故障源之一，建议每个核心服务都显式配置。

### 2.7 优雅终止

删除 Pod 时典型流程：

1. 标记删除，开始 `terminationGracePeriodSeconds`
2. 执行 `preStop`
3. 发送 `SIGTERM`
4. 超时后 `SIGKILL`

建议业务进程必须正确处理 `SIGTERM`。

## 3. Pod 进阶能力

## 3.1 资源配置（requests / limits）

- `requests`：调度依据
- `limits`：运行上限

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### 3.2 CPU 与内存行为差异

- CPU 是可压缩资源：超限通常被限流（throttling）。
- 内存是不可压缩资源：超限可能 OOMKilled。

### 3.3 常见资源问题

- `Pending`：requests 超过节点可用资源
- `OOMKilled`：内存超过 limits
- `CrashLoopBackOff`：启动命令/配置/依赖异常

排查命令：

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous
kubectl get events --sort-by=.lastTimestamp
```

### 3.4 QoS（服务质量）

- `Guaranteed`
- `Burstable`
- `BestEffort`

资源紧张时，通常 `BestEffort` 优先被驱逐。

### 3.5 静态 Pod（Static Pod）

- 由 kubelet 直接管理
- kubeadm 默认目录：`/etc/kubernetes/manifests`
- 常用于控制平面关键组件（如 apiserver/etcd）

### 3.6 Downward API

用于向容器注入 Pod 自身元数据：

- 环境变量注入（如 `metadata.name`）
- Volume 文件挂载（如 labels/annotations）

## 4. Pod 设计与实践建议

### 4.1 Pod 划分

适合同一 Pod：

- 生命周期强绑定
- 强依赖 localhost 通信
- 必须共享卷

不适合同一 Pod：

- 可独立扩缩容
- 发布节奏不同
- 资源模型差异大

### 4.2 生产建议

1. 不直接管理裸 Pod，统一使用控制器。
2. 所有核心业务配置探针与资源边界。
3. 形成标准排障流程：`get -> describe -> logs -> events`。
4. 对关键 Pod 做发布前压测与终止演练（SIGTERM/PreStop）。

## 5. 常用命令速查

```bash
# 查看状态
kubectl get pods -o wide

# 查看详情与事件
kubectl describe pod <pod-name>

# 查看日志
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# 进入容器
kubectl exec -it <pod-name> -- /bin/sh

# 导出资源定义
kubectl get pod <pod-name> -o yaml
```

## 6. 关联文档

- [控制器、ReplicaSet 与 Deployment](./controller-rs-deployment)
- [StatefulSet 与 DaemonSet](./controller-sts-daemonset)
- [Job 与 CronJob](./job-cronjob)
- [kubeadm 搭建 Kubernetes 集群](./kubeadm)
