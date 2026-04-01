---
title: Job 与 CronJob
sidebar_position: 6
---

# Job 与 CronJob

`Deployment/StatefulSet/DaemonSet` 适合长生命周期服务；  
`Job` 和 `CronJob` 则负责“跑完即结束”或“按计划执行”的批处理任务。

- `Job`：执行一次或有限次数，成功后结束。
- `CronJob`：按 Cron 表达式周期性创建 Job。

## 1. 什么时候用 Job，什么时候用 CronJob

- `Job`：数据修复、离线计算、一次性迁移、初始化补偿任务。
- `CronJob`：定时备份、周期对账、定时清理、周期报表。

## 2. Job：一次性或批量并行任务

### 2.1 完整资源清单（含注释）

```yaml
apiVersion: batch/v1  # API 版本
kind: Job  # 资源类型：一次性任务
metadata:
  name: report-job  # Job 名称
  namespace: default  # 命名空间
  labels:
    app.kubernetes.io/name: report-job
spec:
  completions: 6  # 期望成功完成次数，总共需要成功 6 次才算完成
  parallelism: 2  # 最大并发 Pod 数量，最多同时跑 2 个
  completionMode: Indexed  # 完成模式：Indexed 会给每个任务分配唯一索引
  backoffLimit: 3  # 单个 Pod 失败后最大重试次数
  activeDeadlineSeconds: 900  # Job 最长运行 900 秒，超时会终止
  ttlSecondsAfterFinished: 3600  # 完成 1 小时后自动清理 Job 和 Pod
  template:
    metadata:
      labels:
        app: report-job  # Pod 标签
    spec:
      restartPolicy: OnFailure  # Job 只允许 Never/OnFailure
      terminationGracePeriodSeconds: 30  # 优雅退出时间
      containers:
      - name: worker
        image: busybox:1.36  # 示例镜像
        imagePullPolicy: IfNotPresent
        command: ["sh", "-c"]  # 启动命令
        args:
        - |
          echo "start index=$JOB_COMPLETION_INDEX"
          sleep 5
          echo "done index=$JOB_COMPLETION_INDEX"
        env:
        - name: TZ
          value: Asia/Shanghai
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

### 2.2 验证命令

```bash
kubectl apply -f report-job.yaml
kubectl get job report-job
kubectl get pods -l job-name=report-job -o wide
kubectl logs -l job-name=report-job --tail=100
```

### 2.3 Job 关键字段解释

- `parallelism`：控制“同时执行多少个 Pod”。
- `completions`：控制“总共要成功多少次”。
- `completionMode: Indexed`：每个 Pod 带唯一索引，可用于分片处理。
- `backoffLimit`：失败重试上限，避免无限重试。
- `activeDeadlineSeconds`：全局执行超时保护。
- `ttlSecondsAfterFinished`：任务完成后自动清理，防止对象堆积。

## 3. CronJob：定时创建 Job

### 3.1 完整资源清单（含注释）

```yaml
apiVersion: batch/v1  # API 版本
kind: CronJob  # 资源类型：定时任务
metadata:
  name: db-backup-cron  # CronJob 名称
  namespace: default
  labels:
    app.kubernetes.io/name: db-backup-cron
spec:
  schedule: "0 */6 * * *"  # Cron 表达式：每 6 小时执行一次（整点）
  timeZone: "Asia/Shanghai"  # 任务调度时区
  concurrencyPolicy: Forbid  # 并发策略：上一次没结束则跳过本次
  startingDeadlineSeconds: 300  # 错过调度后允许补执行的时间窗口（秒）
  suspend: false  # true 表示暂停调度
  successfulJobsHistoryLimit: 3  # 保留最近成功任务数
  failedJobsHistoryLimit: 1  # 保留最近失败任务数
  jobTemplate:
    spec:
      backoffLimit: 2  # 每次调度生成的 Job 重试上限
      activeDeadlineSeconds: 1800  # 每次调度任务最长运行时间
      ttlSecondsAfterFinished: 86400  # 每次任务完成 24 小时后自动清理
      template:
        metadata:
          labels:
            app: db-backup-job
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: busybox:1.36
            imagePullPolicy: IfNotPresent
            command: ["sh", "-c"]
            args:
            - |
              echo "$(date '+%F %T') backup start"
              sleep 10
              echo "$(date '+%F %T') backup done"
            env:
            - name: TZ
              value: Asia/Shanghai
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 500m
                memory: 512Mi
```

### 3.2 验证命令

```bash
kubectl apply -f db-backup-cron.yaml
kubectl get cronjob db-backup-cron
kubectl get jobs --sort-by=.metadata.creationTimestamp
kubectl get pods -l app=db-backup-job -o wide
```

### 3.3 手动触发一次 CronJob

```bash
kubectl create job --from=cronjob/db-backup-cron db-backup-manual-$(date +%s)
```

## 4. 常见失败与排障

### 4.1 Job 失败常见原因

- `ImagePullBackOff`：镜像拉取失败（仓库权限、镜像不存在）。
- `CrashLoopBackOff`：命令或依赖失败导致反复重启。
- `DeadlineExceeded`：超过 `activeDeadlineSeconds`。
- `BackoffLimitExceeded`：重试次数超过 `backoffLimit`。

排查命令：

```bash
kubectl describe job <job-name>
kubectl get pods -l job-name=<job-name>
kubectl logs <pod-name> --previous
kubectl get events --sort-by=.lastTimestamp
```

### 4.2 CronJob 不触发常见原因

- `suspend: true` 导致调度暂停。
- `schedule/timeZone` 配置不符合预期。
- 控制器时间漂移或集群时间不同步。
- `concurrencyPolicy: Forbid` 下上一个任务未结束。

排查命令：

```bash
kubectl describe cronjob <cronjob-name>
kubectl get cronjob <cronjob-name> -o yaml
kubectl get jobs --sort-by=.metadata.creationTimestamp
```

## 5. 生产实践建议

1. Job/CronJob 一律配置 `requests/limits`，避免批处理任务抢占集群资源。
2. 关键任务使用 `concurrencyPolicy: Forbid` 或 `Replace`，避免重复执行。
3. 关键任务逻辑必须幂等，确保重试或补偿不会产生脏数据。
4. 强烈建议设置 `ttlSecondsAfterFinished`，避免历史对象无限增长。
5. 对耗时任务设置 `activeDeadlineSeconds`，防止“卡死任务”长期占资源。

## 6. 常用命令速查

```bash
# 查看任务资源
kubectl get job
kubectl get cronjob

# 任务日志
kubectl logs -l job-name=<job-name> --tail=100

# 暂停 / 恢复 CronJob
kubectl patch cronjob <cronjob-name> -p '{"spec":{"suspend":true}}'
kubectl patch cronjob <cronjob-name> -p '{"spec":{"suspend":false}}'

# 删除资源
kubectl delete job <job-name>
kubectl delete cronjob <cronjob-name>
```

## 7. 关联文档

- [控制器、ReplicaSet 与 Deployment](./controller-rs-deployment)
- [StatefulSet 与 DaemonSet](./controller-sts-daemonset)
- [Pod 理论基础与进阶](./pod)
- [kubeadm 搭建 Kubernetes 集群](./kubeadm)
