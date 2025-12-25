---
sidebar_position: 1
---

# Kubernetes 集群巡检手册

Kubernetes 是 OpsTrack 的核心领域。该章节提供从控制平面至工作负载的巡检清单，帮助运维工程师在日常值守、变更窗口以及故障时快速定位问题。

## 控制平面巡检

- `kube-apiserver`
  - 检查 `apiserver_request_duration_seconds` P99 是否在 SLA 内。
  - 通过 `kubectl get --raw /readyz` 校验健康状态。
- `etcd`
  - 指标：`etcd_server_is_leader`、`etcd_mvcc_db_total_size_in_bytes`。
  - 定期压缩与快照备份脚本：`scripts/etcd-snapshot.sh`。
- 调度与控制器
  - 核心指标 `scheduler_e2e_scheduling_latency_microseconds`。
  - 控制器管理器租约是否正常续约。

## 节点与网络

- 节点资源
  - `kubectl top nodes` + `node_memory_MemAvailable_bytes`。
  - 容量告警阈值建议：CPU 80%、内存 85%。
- 网络组件
  - CNI（Calico/Cilium）BGP/隧道会话情况。
  - `kube-proxy` conntrack 消耗以及 iptables sync 延迟。

## 工作负载

- Deployment 滚动升级
  - 使用 `kubectl rollout status` 与 Argo Rollouts 实现渐进式发布。
- DaemonSet 状态
  - 关注 `NumberUnavailable` 与 `Misscheduled` 指标。
- Job/CronJob
  - 失败重试策略与 `kubectl describe` 详情记录在 Playbook 中。

## 常用脚本片段

```bash
# 快速导出命名空间内异常 Pod 日志
ns=$1
kubectl get pods -n "$ns" --field-selector=status.phase!=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | while read -r pod; do
  kubectl logs "$pod" -n "$ns" --tail=200 > logs/$pod.log
  echo "saved logs/$pod.log"
done
```

## 延伸阅读

- [Kubernetes 官方文档](https://kubernetes.io/docs/)
- [CNCF Landscape](https://landscape.cncf.io/)

