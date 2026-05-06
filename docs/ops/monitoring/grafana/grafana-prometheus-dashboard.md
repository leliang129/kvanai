---
title: Grafana 面板
sidebar_position: 4
---

# Grafana 面板


## 7.1 Grafana 作用

Grafana 用于展示 Prometheus 指标，并提供仪表盘、变量筛选、告警可视化和 Explore 查询能力。

常见用途：

- 主机监控大盘。
- Kubernetes 集群大盘。
- 数据库和中间件大盘。
- 业务服务 SLI / SLO 面板。
- 告警排查入口。

## 7.2 配置 Prometheus 数据源

页面路径：

```text
Connections -> Data sources -> Add data source -> Prometheus
```

配置：

| 配置项 | 示例 |
| --- | --- |
| `Name` | `Prometheus` |
| `URL` | `http://prometheus:9090` |
| `Access` | `Server` |

保存后点击：

```text
Save & test
```

## 7.3 Provisioning 数据源

适合自动化部署。

```yaml title="provisioning/datasources/prometheus.yml"
apiVersion: 1  # Grafana provisioning API 版本

datasources:  # 数据源列表
  - name: Prometheus  # 数据源名称
    type: prometheus  # 数据源类型为 Prometheus
    access: proxy  # 由 Grafana 服务端代理访问 Prometheus
    url: http://prometheus:9090  # Prometheus 访问地址
    isDefault: true  # 设置为默认数据源
    editable: true  # 允许在 Grafana 页面中编辑
```

挂载：

```yaml
volumes:  # Grafana 容器挂载配置
  - ./provisioning/datasources:/etc/grafana/provisioning/datasources:ro  # 只读挂载数据源 provisioning 配置
```

## 7.4 Dashboard 组织

建议按层级组织：

```text
Platform
├── Node Overview
├── Kubernetes Overview
├── Kafka Overview
└── Prometheus Overview

Application
├── Service Overview
├── API Latency
└── Error Rate

Database
├── MySQL
├── Redis
└── PostgreSQL
```

命名建议：

- 面板名称包含系统、环境或服务类型。
- 生产和测试可以通过变量区分。
- 团队共用面板减少重复建设。

## 7.5 常用变量

环境变量：

```promql
label_values(up, env)
```

Job 变量：

```promql
label_values(up{env="$env"}, job)
```

Instance 变量：

```promql
label_values(up{env="$env", job="$job"}, instance)
```

Service 变量：

```promql
label_values(http_requests_total{env="$env"}, service)
```

建议：

- 常用变量顺序为 `env`、`cluster`、`job`、`service`、`instance`。
- 变量依赖标签规划，标签不统一会直接影响面板可用性。
- 避免变量查询扫全量高基数指标。

## 7.6 主机面板常用查询

CPU 使用率：

```promql
100 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle", instance=~"$instance"}[5m])) * 100
```

内存使用率：

```promql
(1 - node_memory_MemAvailable_bytes{instance=~"$instance"} / node_memory_MemTotal_bytes{instance=~"$instance"}) * 100
```

磁盘使用率：

```promql
(1 - node_filesystem_avail_bytes{instance=~"$instance", fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{instance=~"$instance", fstype!~"tmpfs|overlay"}) * 100
```

网络入口：

```promql
rate(node_network_receive_bytes_total{instance=~"$instance", device!~"lo|docker.*|veth.*"}[5m])
```

网络出口：

```promql
rate(node_network_transmit_bytes_total{instance=~"$instance", device!~"lo|docker.*|veth.*"}[5m])
```

## 7.7 应用面板常用查询

QPS：

```promql
sum by (service) (rate(http_requests_total{service=~"$service"}[5m]))
```

5xx 错误率：

```promql
sum by (service) (rate(http_requests_total{service=~"$service", status=~"5.."}[5m]))
/
sum by (service) (rate(http_requests_total{service=~"$service"}[5m]))
```

P95 延迟：

```promql
histogram_quantile(
  0.95,
  sum by (le, service) (rate(http_request_duration_seconds_bucket{service=~"$service"}[5m]))
)
```

## 7.8 面板设计建议

推荐结构：

- 第一行：服务状态、QPS、错误率、P95、当前告警数。
- 第二行：请求量、延迟、错误趋势。
- 第三行：实例级 CPU、内存、网络、重启。
- 第四行：依赖系统指标，如 DB、Redis、Kafka。

设计原则：

- 先看整体，再下钻实例。
- 关键指标放首屏。
- 同一类面板使用统一单位和颜色阈值。
- 面板变量保持一致。
- 不在一个图里塞太多维度。

## 7.9 导入社区 Dashboard

常见 Dashboard 来源：

```text
https://grafana.com/grafana/dashboards/
```

导入路径：

```text
Dashboards -> New -> Import
```

注意：

- 社区 Dashboard 的指标名可能和当前 Exporter 不一致。
- 导入后需要检查数据源变量和 job 标签。
- 不建议直接把社区面板作为生产标准面板，需裁剪。

## 7.10 常见问题

### 7.10.1 面板无数据

排查：

- 数据源是否连接成功。
- PromQL 在 Explore 中是否有结果。
- 变量是否为空。
- 标签名是否和查询一致。
- 时间范围是否正确。

### 7.10.2 查询很慢

处理：

- 缩小时间范围。
- 减少变量全量扫描。
- 使用 recording rules。
- 避免高基数标签聚合。

### 7.10.3 数值单位不对

处理：

- 字节使用 `bytes`。
- 百分比使用 `percent`。
- QPS 使用 `ops/sec` 或 `reqps`。
- 延迟使用 `seconds` 或 `milliseconds`，表达式要统一单位。

## 7.11 参考资料

- [Grafana Prometheus Data Source](https://grafana.com/docs/grafana/latest/datasources/prometheus/)
- [Grafana Dashboards](https://grafana.com/docs/grafana/latest/dashboards/)
- [Grafana Variables](https://grafana.com/docs/grafana/latest/dashboards/variables/)
