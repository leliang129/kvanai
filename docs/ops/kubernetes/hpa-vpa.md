---
title: HPA 与 VPA
sidebar_position: 7
---

Kubernetes 的自动扩缩容，最常见的两类是：

- `HPA`（Horizontal Pod Autoscaler）：横向扩缩，调整 **副本数**
- `VPA`（Vertical Pod Autoscaler）：纵向扩缩，调整 **单个 Pod 的资源请求 / 限额**

很多团队会先接触 `kubectl scale`，再逐步走向 HPA / VPA。但真正在线上落地时，重点不只是“能不能自动扩”，而是：

- 为什么要选 HPA，而不是 VPA？
- 哪些指标适合做扩缩容依据？
- 资源 `requests` 为什么会直接影响 HPA 判断？
- HPA 和 VPA 能不能同时开？
- YAML 里每个字段到底在控制什么？

本文按 **原理 → 选型 → 实例 → 排错** 的顺序重新梳理，并给出带解释的示例。

## 1. 先理解：HPA 与 VPA 的核心区别

| 项目 | HPA | VPA |
|---|---|---|
| 全称 | Horizontal Pod Autoscaler | Vertical Pod Autoscaler |
| 调整对象 | 工作负载副本数 | Pod 的 CPU / Memory requests/limits |
| 适合场景 | Web 服务、API 服务、消费型任务 | 长期资源配置不合理、经常 OOM、请求值拍脑袋设定 |
| 依赖 | 指标源（最常见是 `metrics-server`） | 指标源 + VPA 组件本身 |
| 是否 Kubernetes 内建 API | 是，`autoscaling/v2` | 不是内建资源，需要额外安装 CRD 和控制器 |
| 代价 | 增加 / 减少 Pod 数量 | 可能需要重建 Pod，部分模式支持原地更新 |

一句话理解：

- **HPA 解决“实例不够用”**
- **VPA 解决“单个实例规格配错了”**

## 2. 什么时候选 HPA，什么时候选 VPA？

### 优先选 HPA 的场景

更适合横向扩展的无状态服务，例如：

- Nginx / Gateway / API Server
- Java / Go / Python Web 服务
- 消费 Kafka / RabbitMQ 的 Worker
- 读多写少、可水平拆分的业务

原因很简单：

- 扩副本通常比“改实例规格”更平滑
- 对可用性影响更小
- 和 Deployment、PDB、Ingress 配合更成熟

### 优先选 VPA 的场景

更适合资源规格长期不准的工作负载，例如：

- requests/limits 完全靠经验拍出来
- 经常发生 `OOMKilled`
- CPU 长期很低，但 requests 给得很大，造成资源浪费
- 批处理 / 定时任务 / 中后台服务，希望自动做 rightsizing

### 一个经验判断

如果你的主要问题是：

- **流量波动大** → 先看 HPA
- **资源申请不准** → 先看 VPA
- **两者都存在** → 先把 requests 设计清楚，再决定是否组合使用

## 3. HPA 的工作原理

HPA 会周期性读取目标工作负载的指标，并计算“当前副本数是否需要变多或变少”。

最常见的是基于 CPU 利用率：

```text
desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)
```

例如：

- 当前 `3` 个副本
- 实际平均 CPU 利用率 `105%`
- 目标 CPU 利用率 `70%`

则期望副本数约为：

```text
ceil(3 × 105 / 70) = ceil(4.5) = 5
```

也就是说，HPA 会把副本数从 `3` 扩到 `5`。

### HPA 依赖什么指标源？

HPA 常见依赖以下指标接口：

- `metrics.k8s.io`：CPU / Memory 等资源指标，通常由 `metrics-server` 提供
- `custom.metrics.k8s.io`：自定义指标，通常通过 Prometheus Adapter 等提供
- `external.metrics.k8s.io`：外部指标，例如消息队列长度、云服务指标等

如果你只是做 CPU / 内存扩缩容，通常只需要先安装 `metrics-server`。

### 为什么 HPA 一定要关心 requests？

因为当 HPA 使用 `averageUtilization` 这种“利用率百分比”时，分母来自容器的 `resources.requests`。

举例：

- 某容器 `cpu request = 200m`
- 当前实际 CPU 使用 `140m`
- 则 CPU 利用率 = `140 / 200 = 70%`

所以：

- **不写 requests，HPA 无法正确按利用率工作**
- **requests 写得太大，HPA 可能不敏感**
- **requests 写得太小，HPA 可能过度敏感**

这也是为什么自动扩缩容并不是“只写一个 HPA YAML”就结束，前面的资源建模同样重要。

## 4. HPA 实战示例

### 4.1 前置条件：安装 metrics-server

如果集群里还没有 `metrics-server`，可以先安装：

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

验证方式：

```bash
kubectl top nodes
kubectl top pods -A
```

如果 `kubectl top` 还拿不到数据，HPA 基于 CPU / Memory 的扩缩容也不会正常工作。

### 4.2 创建一个可被 HPA 管理的 Deployment

下面这个例子里，重点不是镜像，而是 **必须显式设置 requests / limits**。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-autoscale-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-autoscale-demo
  template:
    metadata:
      labels:
        app: web-autoscale-demo
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
```

应用：

```bash
kubectl apply -f web-autoscale-demo.yaml
```

### 4.3 完整资源清单（含注释）

```yaml
apiVersion: autoscaling/v2  # API 版本，推荐使用 autoscaling/v2
kind: HorizontalPodAutoscaler  # 资源类型：水平自动扩缩容
metadata:
  name: web-autoscale-demo  # HPA 名称
  namespace: default  # 命名空间，不写时默认 default
  labels:
    app.kubernetes.io/name: web-autoscale-demo
spec:
  scaleTargetRef:  # HPA 要管理的目标工作负载
    apiVersion: apps/v1
    kind: Deployment
    name: web-autoscale-demo
  minReplicas: 2  # 最小副本数，低于这个值时不会再缩容
  maxReplicas: 10  # 最大副本数，高于这个值时不会再扩容
  metrics:  # 扩缩容判断依据，可配置一个或多个指标
    - type: Resource
      resource:
        name: cpu  # 使用 CPU 作为资源指标
        target:
          type: Utilization  # 目标类型：按 requests 计算利用率百分比
          averageUtilization: 70  # 平均 CPU 利用率目标值 70%
  behavior:  # 控制扩容/缩容速度，避免过于激进或频繁抖动
    scaleUp:
      stabilizationWindowSeconds: 0  # 扩容不额外等待，指标达到就可快速扩容
      policies:
        - type: Percent  # 按百分比扩容
          value: 100  # 每 15 秒最多扩容 100%
          periodSeconds: 15
        - type: Pods  # 按绝对 Pod 数扩容
          value: 4  # 每 15 秒最多增加 4 个 Pod
          periodSeconds: 15
      selectPolicy: Max  # 多条策略同时存在时，取更激进的一条
    scaleDown:
      stabilizationWindowSeconds: 300  # 缩容前观察 300 秒，避免抖动
      policies:
        - type: Percent
          value: 20  # 每 60 秒最多缩容当前副本数的 20%
          periodSeconds: 60
      selectPolicy: Max
```

应用：

```bash
kubectl apply -f web-autoscale-demo-hpa.yaml
```

### 4.4 HPA 关键字段解释

- `scaleTargetRef`：指定 HPA 管理的对象，最终调整的是目标对象的副本数。
- `minReplicas`：副本数下限，防止缩容过头导致服务容量不足。
- `maxReplicas`：副本数上限，防止异常指标导致无限扩容。
- `metrics`：HPA 的判断依据。可以是资源指标、自定义指标、对象指标或外部指标。
- `metrics[].resource.name`：指定资源类型，最常见的是 `cpu` 或 `memory`。
- `target.type: Utilization`：表示按利用率扩缩容，依赖容器的 `requests`。
- `averageUtilization: 70`：表示目标平均 CPU 利用率为 `70%`。
- `behavior.scaleUp`：控制扩容节奏，决定“扩多快”。
- `behavior.scaleDown`：控制缩容节奏，决定“缩多快”。
- `stabilizationWindowSeconds`：稳定窗口，用来减少频繁扩缩带来的抖动。
- `policies`：具体的扩缩容限速策略，可以按百分比或按 Pod 数量控制。
- `selectPolicy`：当存在多条策略时，决定最终采用哪条策略。

可以把这一段理解为：

- `scaleTargetRef` 决定“改谁”
- `metrics` 决定“为什么改”
- `minReplicas/maxReplicas` 决定“改到什么范围”
- `behavior` 决定“改得有多快”

### 4.5 如何验证 HPA 是否生效？

```bash
kubectl get hpa
kubectl describe hpa web-autoscale-demo
kubectl get deploy web-autoscale-demo -w
```

重点看：

- 当前指标是否有值
- `TARGETS` 是否显示类似 `85%/70%`
- `Events` 是否出现扩容 / 缩容记录

如果 `TARGETS` 显示 `<unknown>`，通常不是 HPA 本身有问题，而是指标链路没打通。

## 5. VPA 的工作原理

VPA 的核心目标不是增加副本，而是 **根据历史与当前资源使用情况，自动给 Pod 推荐更合适的 CPU / Memory requests（可选 limits）**。

它通常由三个部分组成：

- `Recommender`：分析历史和当前资源使用，给出推荐值
- `Updater`：在需要时触发 Pod 更新 / 驱逐
- `Admission Controller`：在 Pod 创建时把推荐值注入进去

与 HPA 不同，VPA 不是 Kubernetes 核心内建资源，需要额外安装。

## 6. VPA 的常见模式

根据当前官方说明，VPA 常见 `updateMode` 有：

- `Off`：只给建议，不自动改
- `Initial`：只在 Pod 初次创建时注入建议
- `Recreate`：通过驱逐 Pod 让新 Pod 带着新资源规格重建
- `InPlaceOrRecreate`：尽量原地更新，做不到再回退到重建
- `Auto`：**已废弃**，当前等价于 `Recreate`

对生产环境的建议通常是：

- **第一次上线 VPA：先用 `Off` 看建议是否合理**
- 稳定后再考虑 `Initial` 或 `Recreate`
- 不要一开始就盲目用自动改配置模式

## 7. VPA 实战示例

### 7.1 安装 VPA

VPA 不是内建对象，通常需要先安装 VPA 组件。

一种常见的上游安装方式是使用 autoscaler 仓库中的脚本：

```bash
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-up.sh
```

安装完成后，可检查组件状态：

```bash
kubectl get pods -n kube-system | grep vpa
kubectl get crd | grep verticalpodautoscaler
```

> 不同发行版或托管 Kubernetes 平台，安装方式可能会不同；如果你使用云厂商托管集群，优先以平台推荐方案为准。

### 7.2 创建一个 Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-vpa-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-vpa-demo
  template:
    metadata:
      labels:
        app: api-vpa-demo
    spec:
      containers:
        - name: api
          image: registry.k8s.io/nginx-slim:0.27
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

### 7.3 完整资源清单（含注释，推荐先用 Off 模式）

```yaml
apiVersion: autoscaling.k8s.io/v1  # VPA API 版本
kind: VerticalPodAutoscaler  # 资源类型：垂直自动扩缩容
metadata:
  name: api-vpa-demo  # VPA 名称
  namespace: default
  labels:
    app.kubernetes.io/name: api-vpa-demo
spec:
  targetRef:  # VPA 要分析/管理的目标工作负载
    apiVersion: apps/v1
    kind: Deployment
    name: api-vpa-demo
  updatePolicy:
    updateMode: Off  # 只给建议，不自动修改 Pod
  resourcePolicy:  # 控制推荐范围与生效资源类型
    containerPolicies:
      - containerName: api  # 只对容器 api 生效
        minAllowed:
          cpu: 100m  # 推荐值下限，避免建议过小
          memory: 128Mi
        maxAllowed:
          cpu: "2"  # 推荐值上限，避免建议过大
          memory: 1Gi
        controlledResources:
          - cpu  # VPA 可管理 CPU
          - memory  # VPA 可管理内存
        controlledValues: RequestsOnly  # 只调整 requests，不改 limits
```

应用：

```bash
kubectl apply -f api-vpa-demo.yaml
kubectl apply -f api-vpa-demo-vpa.yaml
```

### 7.4 VPA 关键字段解释

- `targetRef`：指定 VPA 管理的对象，VPA 会基于该工作负载下 Pod 的资源使用情况给出推荐。
- `updatePolicy.updateMode`：决定 VPA 是“只推荐”还是“自动生效”。
- `updateMode: Off`：最稳妥的起步方式，只看推荐，不自动改 Pod。
- `resourcePolicy`：用于限制 VPA 推荐与生效的边界，避免推荐结果失控。
- `containerPolicies`：按容器维度配置策略，适合多容器 Pod 分别治理。
- `containerName`：指定策略作用到哪个容器；可避免 sidecar 与主容器被混在一起推荐。
- `minAllowed`：资源下限，防止 VPA 推荐过低导致应用被饿死。
- `maxAllowed`：资源上限，防止 VPA 推荐过高挤占集群资源。
- `controlledResources`：指定由 VPA 管理哪些资源，最常见是 `cpu` 和 `memory`。
- `controlledValues: RequestsOnly`：表示只改 `requests`，不自动调整 `limits`。

为什么这里推荐先用 `RequestsOnly`：

- 很多线上环境把 `limits` 当作更强的安全边界
- VPA 先只修正 `requests`，风险更低
- 更适合先观察推荐效果，再决定是否进一步放开控制范围

### 7.5 如何查看 VPA 推荐值？

```bash
kubectl describe vpa api-vpa-demo
kubectl get vpa api-vpa-demo -o yaml
```

重点关注：

- `.status.recommendation`
- `target` / `lowerBound` / `upperBound`

如果经过一段时间采样后，推荐值开始出现，你就可以基于这些建议决定是否切换到自动更新模式。

## 8. HPA 与 VPA 能不能一起用？

能，但要非常谨慎。

### 为什么会冲突？

如果：

- HPA 按 CPU / Memory 利用率扩缩容
- VPA 又在动态修改 CPU / Memory requests

那就会出现一个问题：

- HPA 的判断依据（利用率分母）被 VPA 改了
- HPA 的扩缩容结果会被 VPA 间接影响

这会让扩缩行为变得更难预测。

### 更稳妥的组合方式

常见建议是：

- **HPA 用自定义业务指标**（如 QPS、队列长度、并发数）
- **VPA 管 requests**，先用 `Off` 或 `Initial`

或者：

- 对同一个工作负载，优先只用 HPA
- VPA 先只做“建议器”，不自动执行

### 一个经验结论

对于在线 API 服务：

- 先 HPA
- 再看是否需要 VPA 做 rightsizing
- 两者同时自动接管 CPU / Memory 时，通常不是最省心的方案

## 9. 常见问题与排错

### 9.1 HPA 显示 `<unknown>`

优先检查：

```bash
kubectl top pods -A
kubectl get apiservice | grep metrics
kubectl describe hpa <name>
```

常见原因：

- `metrics-server` 没装
- `metrics-server` 不健康
- 容器没写 `resources.requests`
- 指标链路有权限 / 证书 / 网络问题

### 9.2 HPA 不扩容

先检查：

- 指标是否真的高于目标值
- `minReplicas` / `maxReplicas` 是否限制了扩容空间
- `behavior` 是否把扩容速度压得太慢
- 工作负载是否真的可扩（例如 DaemonSet 不能被 HPA 管理）

### 9.3 VPA 没有推荐值

优先检查：

```bash
kubectl get pods -n kube-system | grep vpa
kubectl describe vpa <name>
kubectl top pods
```

常见原因：

- VPA 组件没正常运行
- `metrics-server` 没装或没有数据
- 目标工作负载运行时间太短，数据不足

### 9.4 VPA 改配置导致 Pod 重建

这是正常现象，尤其是在 `Recreate` 模式下。

所以生产上要特别关注：

- PodDisruptionBudget 是否合理
- Deployment 滚动更新策略是否合理
- 服务是否能承受单 Pod 重建带来的瞬时波动

## 10. 实际落地建议

如果你是在真实生产环境中落地，建议按下面顺序推进：

### 第一步：先把 requests/limits 写规范

不论 HPA 还是 VPA，都建立在基础资源配置合理的前提上。

### 第二步：无状态服务先上 HPA

优先用 CPU 或业务指标，解决副本数量自动调整问题。

### 第三步：再用 VPA 做推荐

先 `Off`，观察一段时间，再决定是否自动应用。

### 第四步：避免“一上来就全自动”

自动扩缩容真正难的不是 YAML，而是：

- 指标是否可靠
- 边界是否合理
- 扩缩速度是否可控
- 应用本身是否真的支持被扩缩

## 参考资料

- Kubernetes HPA 概念文档：
  - https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/
- Kubernetes HPA 演练：
  - https://kubernetes.io/zh-cn/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
- Kubernetes VPA 概念文档：
  - https://kubernetes.io/docs/concepts/workloads/autoscaling/vertical-pod-autoscale/
- Metrics Server：
  - https://github.com/kubernetes-sigs/metrics-server
- VPA 上游仓库：
  - https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler
