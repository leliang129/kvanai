---
title: StatefulSet 与 DaemonSet
sidebar_position: 5
---

# StatefulSet 与 DaemonSet

在 Kubernetes 中，`Deployment` 更适合无状态服务；当应用需要“稳定身份 + 稳定存储”，或组件需要“每个节点部署一个实例”时，分别使用 `StatefulSet` 和 `DaemonSet`。

## 1. 先区分三类控制器

- `Deployment`：面向无状态应用，强调弹性扩缩容与滚动发布。
- `StatefulSet`：面向有状态应用，强调固定标识、固定存储、有序发布。
- `DaemonSet`：面向节点守护进程，强调节点覆盖率（每节点 1 个 Pod）。

## 2. StatefulSet：有状态工作负载

### 2.1 什么时候必须用 StatefulSet

- Pod 需要固定命名（例如 `mysql-0`、`mysql-1`）。
- 每个 Pod 需要独立 PVC，且重建后必须挂回原卷。
- 启动、扩容、缩容、升级顺序需要可控。

### 2.2 关键机制

1. 稳定网络身份：Pod 名称固定，可通过稳定 DNS 访问。
2. 稳定持久化：基于 `volumeClaimTemplates` 为每个 Pod 创建独立 PVC。
3. 有序行为：默认 `OrderedReady`，按序号创建和删除。
4. 可控升级：支持 `RollingUpdate` 与分区更新（`partition`）。

### 2.3 完整资源清单（Headless Service + StatefulSet）

```yaml
apiVersion: v1  # API 版本
kind: Service  # Service 类型：Headless Service
metadata:
  name: nginx-headless  # StatefulSet 对应的服务名
  namespace: default
  labels:
    app.kubernetes.io/name: nginx-sts
spec:
  clusterIP: None  # 关键：Headless Service，不分配 VIP
  publishNotReadyAddresses: true  # 可选：允许未就绪 Pod 也出现在 DNS 中（某些集群组件需要）
  selector:
    app: nginx-sts  # 匹配 StatefulSet Pod 标签
  ports:
  - name: http
    port: 80  # Service 端口
    targetPort: http  # 转发到容器端口名 http
---
apiVersion: apps/v1  # API 版本
kind: StatefulSet  # 控制器类型：StatefulSet
metadata:
  name: web  # StatefulSet 名称
  namespace: default
  labels:
    app.kubernetes.io/name: nginx-sts
spec:
  serviceName: nginx-headless  # 绑定 Headless Service 名称（必填）
  replicas: 2  # 副本数，最终会生成 web-0、web-1
  podManagementPolicy: OrderedReady  # Pod 管理策略：按序创建/删除
  revisionHistoryLimit: 10  # 保留历史版本数，便于回滚
  updateStrategy:
    type: RollingUpdate  # 升级策略：滚动更新
    rollingUpdate:
      partition: 0  # 分区更新阈值，0 表示全部副本都可更新
  selector:
    matchLabels:
      app: nginx-sts  # 选择器，需与 template.labels 完全匹配
  template:
    metadata:
      labels:
        app: nginx-sts
        tier: frontend
      annotations:
        docs.example.com/owner: platform-team  # 示例注解
    spec:
      terminationGracePeriodSeconds: 30  # 优雅退出时间
      containers:
      - name: nginx
        image: nginx:1.25.5  # 镜像版本
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 80
        volumeMounts:
        - name: www  # 挂载 volumeClaimTemplates 中定义的 PVC
          mountPath: /usr/share/nginx/html
        resources:
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
          initialDelaySeconds: 5  # 启动后 5 秒开始探测
          periodSeconds: 10  # 每 10 秒探测一次
          timeoutSeconds: 2  # 单次探测超时 2 秒
          successThreshold: 1  # 连续成功 1 次即 Ready
          failureThreshold: 3  # 连续失败 3 次判定 NotReady
        livenessProbe:  # 存活探针：失败后触发重启
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 15  # 启动后 15 秒开始探测
          periodSeconds: 20  # 每 20 秒探测一次
          timeoutSeconds: 2  # 单次探测超时 2 秒
          failureThreshold: 3  # 连续失败 3 次触发重启
  volumeClaimTemplates:
  - metadata:
      name: www  # PVC 名，最终会生成 www-web-0、www-web-1
    spec:
      accessModes:
      - ReadWriteOnce  # 访问模式
      resources:
        requests:
          storage: 1Gi  # 每个 Pod 独立申请 1Gi
      storageClassName: standard  # 存储类名称，按集群实际情况调整
```

### 2.4 验证命令

```bash
kubectl apply -f nginx-sts.yaml
kubectl get sts web
kubectl get pods -l app=nginx-sts -o wide
kubectl get pvc | grep www-web
```

重点确认：

- Pod 是否按 `web-0 -> web-1` 顺序创建。
- PVC 是否按 `www-web-0`、`www-web-1` 自动生成并绑定。
- 删除某个 Pod 后是否仍使用同名 Pod 和原 PVC。

### 2.5 常用字段补充

- `podManagementPolicy`：
  - `OrderedReady`（默认）：严格顺序。
  - `Parallel`：并行创建/删除（不改变稳定标识）。
- `updateStrategy`：
  - `RollingUpdate`：滚动更新，可配 `partition` 分批。
  - `OnDelete`：仅手动删除旧 Pod 才会更新。

## 3. DaemonSet：节点守护型工作负载

### 3.1 典型场景

- 日志采集 Agent（Fluent Bit、Vector）
- 监控 Agent（node-exporter）
- 网络组件（CNI 插件）
- 节点安全与审计组件

### 3.2 完整资源清单（Node Exporter DaemonSet）

```yaml
apiVersion: apps/v1  # API 版本
kind: DaemonSet  # 控制器类型：DaemonSet
metadata:
  name: node-exporter  # DaemonSet 名称
  namespace: kube-system  # 通常运行在 kube-system
  labels:
    app.kubernetes.io/name: node-exporter
spec:
  revisionHistoryLimit: 10  # 历史版本保留数量
  updateStrategy:
    type: RollingUpdate  # 更新策略：滚动更新
    rollingUpdate:
      maxUnavailable: 1  # 升级时最多允许 1 个节点上的实例不可用
  selector:
    matchLabels:
      app: node-exporter  # 选择器，需与 template.labels 匹配
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      serviceAccountName: default  # 示例值，生产建议使用最小权限 SA
      hostNetwork: true  # 使用主机网络，便于暴露主机指标端口
      hostPID: true  # 可选：允许访问主机 PID 命名空间
      dnsPolicy: ClusterFirstWithHostNet  # hostNetwork=true 时建议使用该策略
      tolerations:
      - operator: Exists  # 容忍所有污点，保证尽可能覆盖所有节点
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.8.1  # 镜像版本
        imagePullPolicy: IfNotPresent
        args:
        - --path.rootfs=/host  # 指定主机根文件系统挂载路径
        ports:
        - name: metrics
          containerPort: 9100
          hostPort: 9100  # 将指标端口映射到宿主机
          protocol: TCP
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:  # 存活探针：接口异常时自动重启
          httpGet:
            path: /metrics
            port: metrics
          initialDelaySeconds: 15  # 启动 15 秒后开始探测
          periodSeconds: 20  # 每 20 秒探测一次
          timeoutSeconds: 2  # 探测超时 2 秒
          failureThreshold: 3  # 连续 3 次失败触发重启
        readinessProbe:  # 就绪探针：通过后再纳入抓取目标
          httpGet:
            path: /metrics
            port: metrics
          initialDelaySeconds: 5  # 启动 5 秒后开始探测
          periodSeconds: 10  # 每 10 秒探测一次
          timeoutSeconds: 2  # 探测超时 2 秒
          successThreshold: 1  # 连续成功 1 次即 Ready
          failureThreshold: 3  # 连续失败 3 次判定 NotReady
        securityContext:
          readOnlyRootFilesystem: true  # 根文件系统只读
          allowPrivilegeEscalation: false  # 禁止提权
        volumeMounts:
        - name: root
          mountPath: /host
          readOnly: true
      volumes:
      - name: root
        hostPath:
          path: /  # 挂载宿主机根目录
          type: Directory
```

### 3.3 验证命令

```bash
kubectl apply -f node-exporter-ds.yaml
kubectl get ds -n kube-system node-exporter
kubectl get pods -n kube-system -l app=node-exporter -o wide
```

重点确认：

- `DESIRED/CURRENT/READY` 是否与可调度节点数量基本一致。
- 新增节点后是否自动拉起新 Pod。
- 控制面节点有污点时，是否通过 `tolerations` 正常覆盖。

### 3.4 常用字段补充

- `updateStrategy.rollingUpdate.maxUnavailable`：控制升级时可同时不可用的节点数。
- `nodeSelector` / `nodeAffinity`：只在特定节点部署守护进程。
- `tolerations`：决定能否调度到带污点节点。

## 4. StatefulSet 与 DaemonSet 快速对比

- 副本模型：
  - StatefulSet：固定副本数 + 固定序号。
  - DaemonSet：按节点自动铺开。
- 核心诉求：
  - StatefulSet：状态与数据一致性。
  - DaemonSet：节点覆盖率。
- 存储模型：
  - StatefulSet：常配 PVC。
  - DaemonSet：多数直接读取宿主机数据，不依赖 PVC。

## 5. 常见问题排查

### 5.1 StatefulSet Pod 一直 Pending

- PVC 未绑定（存储类、容量、访问模式不匹配）
- 节点资源不足或调度约束过严

```bash
kubectl describe pod <pod-name>
kubectl get pvc,pv
kubectl describe pvc <pvc-name>
```

### 5.2 StatefulSet 升级卡住

- 前序 Pod 未 Ready，阻塞后续滚动
- 探针过严，导致长时间 NotReady

```bash
kubectl rollout status sts/<sts-name>
kubectl describe pod <pod-name>
kubectl get events --sort-by=.lastTimestamp
```

### 5.3 DaemonSet 未覆盖全部节点

- 节点污点未被容忍
- `nodeSelector`/`affinity` 过滤过多
- 节点处于 `NotReady` 或 `SchedulingDisabled`

```bash
kubectl get ds <ds-name> -n <ns>
kubectl describe ds <ds-name> -n <ns>
kubectl get nodes -o wide
```

## 6. 实践建议

1. 有状态服务优先 StatefulSet，不要用 Deployment 手工模拟固定身份。
2. StatefulSet 必须同时设计 Headless Service、存储类和备份恢复策略。
3. DaemonSet 发布前要先明确节点范围（`tolerations`、`nodeSelector`、`affinity`）。
4. 对节点级组件同样配置资源限制与探针，避免守护进程反向拖垮节点。

## 7. 关联文档

- [控制器、ReplicaSet 与 Deployment](./controller-rs-deployment)
- [Job 与 CronJob](./job-cronjob)
- [Pod 理论基础与进阶](./pod)
- [kubeadm 搭建 Kubernetes 集群](./kubeadm)
