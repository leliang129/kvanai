---
title: PromQL 常用查询
sidebar_position: 4
---

# PromQL 常用查询


## 4.1 PromQL 基础

PromQL 是 Prometheus 的查询语言，用于查询、聚合和计算时序指标。

常见表达式类型：

| 类型 | 示例 | 说明 |
| --- | --- | --- |
| Instant Vector | `up` | 当前时刻的一组时间序列 |
| Range Vector | `up[5m]` | 最近 5 分钟的一组时间序列 |
| Scalar | `1` | 单个数字 |
| String | `"text"` | 字符串，使用较少 |

常用查询入口：

```text
http://prometheus.example.com:9090/graph
```

API 查询：

```bash
curl 'http://localhost:9090/api/v1/query?query=up'  # 即时查询
curl 'http://localhost:9090/api/v1/query_range?query=up&start=1714970000&end=1714973600&step=30'  # 区间查询
```

## 4.2 标签过滤

精确匹配：

```promql
up{job="node"}
```

不等于：

```promql
up{job!="node"}
```

正则匹配：

```promql
up{job=~"node|prometheus"}
```

正则排除：

```promql
up{instance!~"10.0.0.1.*"}
```

## 4.3 聚合查询

按 job 聚合：

```promql
sum by (job) (up)
```

按 instance 聚合：

```promql
sum by (instance) (rate(node_network_receive_bytes_total[5m]))
```

去掉某些标签聚合：

```promql
sum without (cpu, mode) (rate(node_cpu_seconds_total[5m]))
```

常用聚合函数：

| 函数 | 说明 |
| --- | --- |
| `sum` | 求和 |
| `avg` | 平均值 |
| `min` | 最小值 |
| `max` | 最大值 |
| `count` | 计数 |
| `topk` | Top N |
| `bottomk` | Bottom N |

## 4.4 rate 与 increase

Counter 类型指标通常需要使用 `rate` 或 `increase`。

每秒速率：

```promql
rate(http_requests_total[5m])
```

5 分钟增量：

```promql
increase(http_requests_total[5m])
```

建议：

- 看趋势和 QPS 用 `rate`。
- 看一段时间总增量用 `increase`。
- 区间不要太短，通常至少覆盖 2-4 个 scrape interval。

## 4.5 主机 CPU

CPU 使用率：

```promql
100 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100
```

按 CPU 核查看：

```promql
100 - avg by (instance, cpu) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100
```

系统态 CPU：

```promql
avg by (instance) (rate(node_cpu_seconds_total{mode="system"}[5m])) * 100
```

## 4.6 主机内存

内存使用率：

```promql
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
```

可用内存：

```promql
node_memory_MemAvailable_bytes
```

内存总量：

```promql
node_memory_MemTotal_bytes
```

## 4.7 磁盘空间

磁盘使用率：

```promql
(1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) * 100
```

可用空间：

```promql
node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}
```

预测 24 小时后磁盘是否写满：

```promql
predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}[6h], 24 * 3600) < 0
```

## 4.8 磁盘 IO

读速率：

```promql
rate(node_disk_read_bytes_total[5m])
```

写速率：

```promql
rate(node_disk_written_bytes_total[5m])
```

IO 使用率近似：

```promql
rate(node_disk_io_time_seconds_total[5m]) * 100
```

## 4.9 网络

入口流量：

```promql
rate(node_network_receive_bytes_total{device!~"lo|docker.*|veth.*"}[5m])
```

出口流量：

```promql
rate(node_network_transmit_bytes_total{device!~"lo|docker.*|veth.*"}[5m])
```

网络错误：

```promql
rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m])
```

## 4.10 HTTP 服务

QPS：

```promql
sum by (service) (rate(http_requests_total[5m]))
```

错误率：

```promql
sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
/
sum by (service) (rate(http_requests_total[5m]))
```

P95 延迟：

```promql
histogram_quantile(
  0.95,
  sum by (le, service) (rate(http_request_duration_seconds_bucket[5m]))
)
```

## 4.11 常用函数

| 函数 | 说明 |
| --- | --- |
| `rate()` | 计算 Counter 每秒速率 |
| `increase()` | 计算 Counter 区间增量 |
| `irate()` | 近两个点的瞬时速率 |
| `histogram_quantile()` | 计算 Histogram 分位数 |
| `predict_linear()` | 线性预测 |
| `absent()` | 指标不存在检测 |
| `changes()` | 区间内变化次数 |
| `resets()` | Counter 重置次数 |

## 4.12 常见问题

### 4.12.1 rate 结果为空

常见原因：

- 指标不是 Counter。
- 查询区间太短。
- 最近没有样本。
- 标签过滤条件过窄。

### 4.12.2 查询很慢

处理：

- 缩小时间范围。
- 减少高基数标签聚合。
- 使用 recording rules 预聚合。
- 避免对全量指标做复杂正则。

### 4.12.3 图表出现断点

常见原因：

- Target down。
- scrape interval 太长。
- 查询 step 设置不合理。
- Exporter 指标间歇性缺失。

## 4.13 参考资料

- [Prometheus Querying Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Prometheus Functions](https://prometheus.io/docs/prometheus/latest/querying/functions/)
- [Prometheus Operators](https://prometheus.io/docs/prometheus/latest/querying/operators/)
