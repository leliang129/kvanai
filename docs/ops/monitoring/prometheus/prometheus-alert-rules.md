---
title: Prometheus 告警规则
sidebar_position: 5
---

# Prometheus 告警规则


## 5.1 规则类型

Prometheus 规则分为两类：

| 类型 | 说明 |
| --- | --- |
| Alerting Rules | 告警规则，满足条件后发送到 Alertmanager |
| Recording Rules | 记录规则，提前计算复杂表达式并保存为新指标 |

配置入口：

```yaml
rule_files:  # Prometheus 规则文件列表
  - /etc/prometheus/rules/*.yml  # 加载 rules 目录下所有 yml 规则文件
```

规则文件修改后校验：

```bash
promtool check rules /etc/prometheus/rules/*.yml  # 校验规则文件语法
curl -X POST http://localhost:9090/-/reload  # 重新加载 Prometheus 规则
```

## 5.2 告警规则结构

```yaml title="node-alerts.yml"
groups:  # 规则组列表
  - name: node  # 规则组名称
    rules:  # 当前规则组内的规则列表
      - alert: NodeDown  # 告警名称
        expr: up{job="node"} == 0  # node 任务目标不可达时表达式为真
        for: 1m  # 条件持续 1 分钟后触发告警
        labels:  # 告警标签，用于路由、分级和聚合
          severity: critical  # 告警级别
          team: platform  # 负责团队
        annotations:  # 告警说明，用于通知内容
          summary: "Node exporter is down"  # 告警摘要
          description: "{{ $labels.instance }} has been down for more than 1 minute"  # 告警详情
```

字段说明：

| 字段 | 说明 |
| --- | --- |
| `alert` | 告警名称 |
| `expr` | PromQL 表达式 |
| `for` | 条件持续多久后触发 |
| `labels` | 告警标签，用于路由和分级 |
| `annotations` | 告警说明，用于通知内容 |

## 5.3 主机告警示例

### 5.3.1 节点不可达

```yaml
- alert: NodeDown  # 告警名称
  expr: up{job="node"} == 0  # node 任务目标不可达
  for: 1m  # 持续 1 分钟后触发
  labels:  # 告警标签
    severity: critical  # 告警级别为严重
  annotations:  # 告警说明
    summary: "Node exporter is down"  # 告警摘要
    description: "{{ $labels.instance }} is down"  # 告警详情
```

### 5.3.2 CPU 使用率高

```yaml
- alert: NodeCPUUsageHigh  # 告警名称
  expr: 100 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100 > 85  # CPU 使用率超过 85%
  for: 10m  # 持续 10 分钟后触发
  labels:  # 告警标签
    severity: warning  # 告警级别为警告
  annotations:  # 告警说明
    summary: "Node CPU usage is high"  # 告警摘要
    description: "{{ $labels.instance }} CPU usage is over 85%"  # 告警详情
```

### 5.3.3 内存使用率高

```yaml
- alert: NodeMemoryUsageHigh  # 告警名称
  expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 85  # 内存使用率超过 85%
  for: 10m  # 持续 10 分钟后触发
  labels:  # 告警标签
    severity: warning  # 告警级别为警告
  annotations:  # 告警说明
    summary: "Node memory usage is high"  # 告警摘要
    description: "{{ $labels.instance }} memory usage is over 85%"  # 告警详情
```

### 5.3.4 磁盘使用率高

```yaml
- alert: NodeDiskUsageHigh  # 告警名称
  expr: (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) * 100 > 85  # 非临时文件系统磁盘使用率超过 85%
  for: 5m  # 持续 5 分钟后触发
  labels:  # 告警标签
    severity: warning  # 告警级别为警告
  annotations:  # 告警说明
    summary: "Node disk usage is high"  # 告警摘要
    description: "{{ $labels.instance }} {{ $labels.mountpoint }} disk usage is over 85%"  # 告警详情
```

### 5.3.5 磁盘即将写满

```yaml
- alert: NodeDiskWillFillIn24Hours  # 告警名称
  expr: predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}[6h], 24 * 3600) < 0  # 预测 24 小时内磁盘可用空间小于 0
  for: 10m  # 持续 10 分钟后触发
  labels:  # 告警标签
    severity: warning  # 告警级别为警告
  annotations:  # 告警说明
    summary: "Node disk may fill within 24 hours"  # 告警摘要
    description: "{{ $labels.instance }} {{ $labels.mountpoint }} may fill within 24 hours"  # 告警详情
```

## 5.4 服务告警示例

### 5.4.1 HTTP 5xx 错误率高

```yaml
- alert: ServiceHTTP5xxRateHigh  # 告警名称
  expr: |  # 多行 PromQL 表达式
    sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
    /
    sum by (service) (rate(http_requests_total[5m]))
    > 0.05
  for: 5m  # 持续 5 分钟后触发
  labels:  # 告警标签
    severity: warning  # 告警级别为警告
  annotations:  # 告警说明
    summary: "HTTP 5xx rate is high"  # 告警摘要
    description: "{{ $labels.service }} 5xx rate is over 5%"  # 告警详情
```

### 5.4.2 P95 延迟高

```yaml
- alert: ServiceP95LatencyHigh  # 告警名称
  expr: |  # 多行 PromQL 表达式
    histogram_quantile(
      0.95,
      sum by (le, service) (rate(http_request_duration_seconds_bucket[5m]))
    ) > 1
  for: 10m  # 持续 10 分钟后触发
  labels:  # 告警标签
    severity: warning  # 告警级别为警告
  annotations:  # 告警说明
    summary: "Service P95 latency is high"  # 告警摘要
    description: "{{ $labels.service }} P95 latency is over 1 second"  # 告警详情
```

## 5.5 Recording Rules

复杂表达式建议提前计算，减少查询和告警压力。

```yaml title="recording-rules.yml"
groups:  # 规则组列表
  - name: node-recording  # 记录规则组名称
    rules:  # 当前规则组内的规则列表
      - record: instance:node_cpu_usage:ratio  # 新生成的 CPU 使用率指标名
        expr: 1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))  # 预计算实例维度 CPU 使用率

      - record: instance:node_memory_usage:ratio  # 新生成的内存使用率指标名
        expr: 1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes  # 预计算内存使用率
```

使用：

```promql
instance:node_cpu_usage:ratio * 100
```

## 5.6 告警分级

建议分级：

| severity | 说明 | 响应 |
| --- | --- | --- |
| `critical` | 明确影响服务或即将中断 | 立即处理 |
| `warning` | 有风险但未立即中断 | 工作时间或低优先级处理 |
| `info` | 观察类信息 | 通知或记录 |

示例：

```yaml
labels:  # 告警标签
  severity: critical  # 告警级别
  team: platform  # 负责团队
  service: node  # 服务或组件名称
```

## 5.7 告警降噪

建议：

- 使用合理的 `for`，避免瞬时抖动触发。
- Alertmanager 中配置分组和抑制。
- 不为同一问题配置多个重复告警。
- 告警表达式加入必要标签过滤。
- 对离线批任务和实时服务使用不同阈值。

不建议：

- 所有告警都设为 critical。
- 所有服务共用同一阈值。
- 对高基数标签直接按全量维度告警。

## 5.8 测试告警

创建测试规则：

```yaml
- alert: AlwaysFiringTest  # 测试告警名称
  expr: vector(1)  # 永远返回 1，用于测试告警链路
  for: 10s  # 持续 10 秒后触发
  labels:  # 告警标签
    severity: info  # 告警级别为信息
  annotations:  # 告警说明
    summary: "Test alert"  # 告警摘要
```

检查页面：

```text
http://prometheus.example.com:9090/alerts
```

## 5.9 常见问题

### 5.9.1 告警不触发

排查：

```bash
promtool check rules /etc/prometheus/rules/*.yml  # 校验规则
curl http://localhost:9090/api/v1/rules  # 查看 Prometheus 已加载规则
curl http://localhost:9090/api/v1/alerts  # 查看当前告警
```

常见原因：

- 规则文件未被 `rule_files` 引用。
- reload 失败。
- 表达式没有返回结果。
- `for` 时间还没满足。

### 5.9.2 告警太多

处理：

- 调整阈值。
- 增加 `for`。
- Alertmanager 配置 group 和 inhibit。
- 合并重复告警。
- 删除低价值告警。

## 5.10 参考资料

- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Prometheus Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/)
- [Prometheus Template Reference](https://prometheus.io/docs/prometheus/latest/configuration/template_reference/)
