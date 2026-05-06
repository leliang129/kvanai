---
title: Prometheus 最佳实践
sidebar_position: 13
---

# Prometheus 最佳实践


## 11.1 标签规划优先于一切

Prometheus 的大部分后续问题，本质上都来自标签设计失控。

推荐保留的稳定标签：

- `env`
- `cluster`
- `service`
- `team`
- `region`
- `instance`

不建议作为标签的字段：

- 用户 ID
- 订单 ID
- request id
- trace id
- 动态 URL
- 容器临时 ID

原则：

- 标签要稳定。
- 标签要服务于查询、聚合和路由。
- 能不用标签表达的动态值，不要放标签。

## 11.2 控制高基数

高基数是 Prometheus 最常见的性能和容量问题来源。

常见高基数来源：

- 每个请求路径都打到标签里。
- 每个用户 ID 都是标签值。
- Kubernetes 场景保留了过多临时标签。
- Exporter 默认开启了大量低价值指标。

治理方法：

- 从应用源头治理。
- 用 `metric_relabel_configs` 丢弃低价值标签和指标。
- 减少不必要的 Exporter collector。
- 在 Dashboard 中避免全量正则查询。

## 11.3 采集间隔要分层

不是所有目标都需要 15 秒采集。

建议：

- 核心业务和主机：`15s`
- 中低频中间件：`30s`
- 黑盒探测：`30s` 或 `60s`
- 慢变资源：`60s` 或更长

原则：

- 采集越频繁，样本量越大。
- 采集间隔应和指标变化速度匹配。

## 11.4 Rule 文件拆分

不要把所有规则堆进一个文件。

推荐拆分：

```text
/etc/prometheus/rules
├── node.yml
├── app.yml
├── database.yml
└── middleware.yml
```

建议：

- 按系统或职责拆分。
- 告警规则和 recording rules 可以分文件。
- 每次变更前都执行 `promtool check rules`。

## 11.5 Recording Rules 先于复杂 Dashboard

复杂的 PromQL 不应该每次都在 Dashboard 实时算。

适合做 recording rules 的场景：

- 高频访问的复杂表达式。
- 需要在多个 Dashboard 复用的指标。
- 需要做聚合和降维后的结果。

好处：

- 查询更快。
- 告警和 Dashboard 表达式更简洁。
- 降低 Prometheus 查询压力。

## 11.6 Alert 先求稳定，再求全面

告警设计不应追求“多”，而应追求“有用”。

建议：

- 先做基础可用性告警。
- `for` 要合理，避免抖动。
- `critical` 只保留真正影响业务的告警。
- 告警标签要能支持 Alertmanager 路由。

常见基础告警：

- Target down
- CPU / 内存 / 磁盘使用率高
- 磁盘预计写满
- HTTP 5xx 错误率高
- P95 延迟高

## 11.7 Exporter 最小化部署

不要为了“指标多”而无节制上 Exporter。

建议：

- 先部署 Node Exporter。
- 中间件按实际场景补充 MySQL / Redis / Kafka 等 Exporter。
- 每加一个 Exporter，都评估采集价值和成本。

## 11.8 Dashboard 和 Prometheus 解耦

Dashboard 不应该绑死 Prometheus 内部细节。

建议：

- 通过 recording rules 暴露稳定指标名。
- 变量依赖统一标签。
- 社区 Dashboard 导入后做本地裁剪。

## 11.9 存储与保留策略要提前设计

建议：

- 本地 Prometheus 只保留短中期数据。
- 长期存储用 Thanos、VictoriaMetrics、Mimir 等方案。
- 同时设置 `retention.time` 和 `retention.size`。
- 数据目录独立磁盘。

## 11.10 HA 与拆分策略

Prometheus 自身不复制数据。

建议：

- 关键环境至少双 Prometheus。
- Alertmanager 负责通知去重。
- 规模变大后按环境、区域或系统拆分。
- 全局查询交给 Thanos 或远端查询层。

## 11.11 配置管理建议

- `prometheus.yml`、rules、targets 全部纳入 Git。
- 使用 `file_sd_configs` 管理动态目标。
- 修改配置前执行 `promtool check config`。
- 修改规则前执行 `promtool check rules`。

## 11.12 运维建议

- 定期检查 `prometheus_tsdb_head_series`。
- 关注 WAL 和数据目录增长。
- 关注慢查询和高频 Dashboard。
- 定期审查无效告警和无用指标。

## 11.13 参考资料

- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)
- [Prometheus Instrumentation Best Practices](https://prometheus.io/docs/practices/instrumentation/)
- [Prometheus Storage](https://prometheus.io/docs/prometheus/latest/storage/)
