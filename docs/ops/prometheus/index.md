---
sidebar_position: 1
---

# Prometheus 可观测矩阵

该章节整理多集群 Prometheus 以及相关生态（Alertmanager、Grafana、Loki、Tempo）的落地实践，从指标/日志/追踪三栈构建统一的可观测平台。

## 监控栈拓扑

1. `Prometheus`：Scrape Kubernetes、主机与业务指标。
2. `Thanos / VictoriaMetrics`：跨集群长时存储与查询。
3. `Alertmanager`：分级告警 + 抑制链路。
4. `Grafana`：可视化与 SLO 仪表盘。

## 指标采集清单

- Kubernetes：kube-state-metrics、node-exporter、APIServer。
- 系统服务：promtail、blackbox-exporter。
- 数据库：mysqld_exporter、redis_exporter。

## 告警模板示例

```yaml
- alert: KubeAPIDown
  expr: absent(up{job="apiserver"} == 1)
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: API Server 不可达
    runbook_url: https://ops-track.example.com/docs/platform/kubernetes
```

## 联邦与多租户

- 使用 Thanos Sidecar + Querier 聚合多集群指标，SLO 监控统一查询入口。
- Alertmanager 通过 `inhibit_rules` 抑制重复告警，并与 OnCall/ChatOps 集成。

## 日志与追踪

- Loki：Promtail 以 DaemonSet 部署，借助 label rewrite 控制索引基数。
- Tempo：与 OpenTelemetry Collector 集成，采集链路追踪数据。
- Grafana 中配置 Explore 面板，实现指标跳转到日志/追踪。

## 常用命令

```bash
# 快速校验 Prometheus Targets
kubectl port-forward svc/prometheus-k8s 9090:9090 -n monitoring &
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets | length'
```

## 延伸阅读

- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Grafana Playlists](https://grafana.com/docs/grafana/latest/)

