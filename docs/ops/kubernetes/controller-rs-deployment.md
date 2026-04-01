---
sidebar_position: 4
title: ReplicaSet 与 Deployment
---

# ReplicaSet 与 Deployment

在 Kubernetes 中，Pod 是最小运行单元，但生产环境通常不会直接维护裸 Pod。
真正承担“稳定运行、发布升级、故障恢复”的是控制器，其中最常用的就是 `ReplicaSet` 和 `Deployment`。

## 1. 先理解控制器模型

Kubernetes 的核心是声明式管理：

- 用户在 `spec` 描述期望状态。
- 控制器持续观察当前状态。
- 两者不一致时，触发调谐（Reconcile）并收敛。

简单理解就是一个持续运行的控制循环：

```go
for {
  desired := getDesiredState()
  current := getCurrentState()

  if current != desired {
    reconcile(current, desired)
  }
}
```

这也是为什么即使你手动删掉 Pod，它也可能被自动补回来。

## 2. ReplicaSet：保证副本数量

`ReplicaSet`（RS）的职责很单一也很重要：
**确保一组满足标签选择器的 Pod，始终保持指定副本数。**

### 2.1 核心字段

- `spec.replicas`：期望副本数。
- `spec.selector`：匹配并接管 Pod 的标签选择器。
- `spec.template`：新建 Pod 时使用的模板。

### 2.2 完整示例（含注释）

```yaml
apiVersion: apps/v1  # API 版本，ReplicaSet 使用 apps/v1
kind: ReplicaSet  # 资源类型：副本控制器
metadata:
  name: nginx-rs  # RS 名称
  namespace: default  # 命名空间
  labels:  # 资源自身标签，便于筛选与治理
    app.kubernetes.io/name: nginx
    app.kubernetes.io/component: web
spec:
  replicas: 3  # 期望副本数
  minReadySeconds: 5  # Pod Ready 后至少稳定 5 秒才视为可用
  selector:  # 选择器：必须与 template.metadata.labels 匹配
    matchLabels:
      app: nginx
      tier: frontend
  template:
    metadata:
      labels:
        app: nginx
        tier: frontend
      annotations:
        docs.example.com/owner: platform-team  # 示例注解：可用于审计/治理
    spec:
      restartPolicy: Always  # 控制器管理的 Pod 应保持 Always
      terminationGracePeriodSeconds: 30  # 优雅退出宽限期
      containers:
      - name: nginx  # 容器名
        image: nginx:1.25.5  # 容器镜像
        imagePullPolicy: IfNotPresent  # 镜像拉取策略
        ports:
        - name: http
          containerPort: 80  # 容器监听端口
          protocol: TCP
        resources:  # 资源请求与限制
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:  # 就绪探针：决定是否接收流量
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5  # 容器启动后，延迟 5 秒再开始首次探测
          periodSeconds: 10  # 每 10 秒探测一次
          timeoutSeconds: 2  # 单次探测超时时间 2 秒
          successThreshold: 1  # 就绪探针连续成功 1 次即判定 Ready（最小值 1）
          failureThreshold: 3  # 连续失败 3 次判定 NotReady（从 Endpoints 摘除）
        livenessProbe:  # 存活探针：失败后触发重启
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 15  # 容器启动后，延迟 15 秒再做存活检查
          periodSeconds: 20  # 每 20 秒探测一次
          timeoutSeconds: 2  # 单次探测超时时间 2 秒
          failureThreshold: 3  # 连续失败 3 次判定不存活，触发容器重启
        env:
        - name: TZ
          value: Asia/Shanghai  # 示例环境变量
```

```bash
kubectl apply -f nginx-rs.yaml
kubectl get rs,pods -l app=nginx
```

### 2.3 你会观察到的行为

- 删除一个受管 Pod：RS 会自动创建新 Pod 补齐。
- 把 `replicas: 3` 改为 `2`：RS 会主动缩容 1 个 Pod。

常用排查命令：

```bash
kubectl describe rs nginx-rs
kubectl describe pod <pod-name>
```

## 3. Deployment：管理发布过程

`Deployment` 是比 RS 更高一层的控制器，核心价值是“管理 Pod 版本演进”。

- 滚动更新（RollingUpdate）
- 历史版本记录（Revision）
- 回滚（Rollback）
- 声明式扩缩容

关系可以记为：
**Deployment -> ReplicaSet -> Pod**

### 3.1 完整示例（含注释）

```yaml
apiVersion: apps/v1  # API 版本
kind: Deployment  # 控制器类型：Deployment
metadata:
  name: nginx-deploy  # Deployment 名称
  namespace: default  # 命名空间
  labels:
    app.kubernetes.io/name: nginx
    app.kubernetes.io/part-of: demo-app
spec:
  replicas: 3  # 期望副本数
  revisionHistoryLimit: 10  # 保留历史 RS 数量，便于回滚
  progressDeadlineSeconds: 600  # 发布超时时间（秒）
  minReadySeconds: 5  # 新 Pod Ready 后稳定 5 秒才计为 Available
  selector:  # 选择器：创建后不可随意变更
    matchLabels:
      app: nginx
      tier: frontend
  strategy:
    type: RollingUpdate  # 更新策略：滚动更新（默认）
    rollingUpdate:
      maxSurge: 1  # 升级时最多可额外多 1 个 Pod
      maxUnavailable: 1  # 升级时最多不可用 1 个 Pod
  template:
    metadata:
      labels:
        app: nginx
        tier: frontend
      annotations:
        docs.example.com/release: "v1"  # 示例发布标记
    spec:
      terminationGracePeriodSeconds: 30  # 优雅退出时间
      containers:
      - name: nginx  # 容器名
        image: nginx:1.25.5  # 镜像版本（变更此值会触发滚动更新）
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:  # 就绪探针：通过后才进入 Service Endpoints
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5  # 容器启动后，延迟 5 秒再开始首次探测
          periodSeconds: 10  # 每 10 秒探测一次
          timeoutSeconds: 2  # 单次探测超时时间 2 秒
          successThreshold: 1  # 连续成功 1 次即标记 Ready（就绪探针可 >1）
          failureThreshold: 3  # 连续失败 3 次从负载均衡后端摘除
        livenessProbe:  # 存活探针：连续失败会重启容器
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 15  # 容器启动后，延迟 15 秒再做存活检查
          periodSeconds: 20  # 每 20 秒探测一次
          timeoutSeconds: 2  # 单次探测超时时间 2 秒
          failureThreshold: 3  # 连续失败 3 次触发 kubelet 重启容器
        lifecycle:
          preStop:
            exec:
              command: ["sh", "-c", "sleep 5"]  # 示例：预留摘流时间
        env:
        - name: TZ
          value: Asia/Shanghai
```

```bash
kubectl apply -f nginx-deploy.yaml
kubectl get deploy,rs,pods -l app=nginx
```

你会看到 Pod 的 `Controlled By` 是某个 ReplicaSet；
而该 ReplicaSet 的 `Controlled By` 是这个 Deployment。

## 4. Deployment 常用发布动作

### 4.1 扩缩容

```bash
kubectl scale deploy nginx-deploy --replicas=4
```

### 4.2 触发滚动更新

常见方式：更新镜像。

```bash
kubectl set image deploy/nginx-deploy nginx=nginx:1.27
kubectl rollout status deploy/nginx-deploy
```

### 4.3 暂停与恢复

```bash
kubectl rollout pause deploy/nginx-deploy
kubectl rollout resume deploy/nginx-deploy
```

### 4.4 查看历史与回滚

```bash
kubectl rollout history deploy/nginx-deploy
kubectl rollout undo deploy/nginx-deploy
kubectl rollout undo deploy/nginx-deploy --to-revision=1
```

## 5. RollingUpdate 参数怎么配

- `maxSurge`：升级期间允许临时超出的副本数。
- `maxUnavailable`：升级期间允许不可用的副本数。
- `minReadySeconds`：Pod Ready 后需稳定多久才视为可用。

建议：

- 线上有流量服务，优先设置 `maxUnavailable: 0` 或较小值。
- 有慢启动应用时，搭配 `readinessProbe + minReadySeconds`。

注意：`maxSurge` 与 `maxUnavailable` 不能同时为 `0`。

## 6. 常见误区

1. 直接改 Deployment 生成的 RS。
这类改动常会被 Deployment 后续行为覆盖，应统一改 Deployment。

2. selector 与 template labels 不匹配。
不匹配会导致控制器无法正确接管或创建 Pod。

3. 没有健康检查就滚动更新。
没有 `readinessProbe` 时，Pod 可能“进程启动了但服务不可用”，造成发布抖动。

4. 历史版本保留过多或过少。
`revisionHistoryLimit` 太小会影响回滚，太大则增加对象数量。

## 7. 排障清单

发布异常时优先执行：

```bash
kubectl get deploy,rs,pods -o wide
kubectl describe deploy <deploy-name>
kubectl describe rs <rs-name>
kubectl describe pod <pod-name>
kubectl get events --sort-by=.lastTimestamp
```

重点关注：

- Deployment Conditions（`Progressing`、`Available`）
- Events 中的镜像拉取、探针失败、调度失败信息
- 新旧 RS 的副本变化是否符合预期

## 8. 实践建议

1. 业务服务默认使用 Deployment，而不是直接使用裸 Pod 或手工 RS。
2. 发布策略必须和探针一起设计，避免“更新成功但服务不可用”。
3. 生产集群保留可回滚窗口，建议显式设置 `revisionHistoryLimit`。
4. 将 `rollout status/history/undo` 固化进发布流程。
