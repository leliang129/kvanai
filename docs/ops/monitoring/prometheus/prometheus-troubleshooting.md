---
title: Prometheus 故障排查
sidebar_position: 11
---

# Prometheus 故障排查


## 9.1 排查思路

Prometheus 故障建议按链路排查：

1. Prometheus 服务是否启动。
2. 配置文件是否正确。
3. Targets 是否正常。
4. 指标是否存在。
5. PromQL 是否正确。
6. 告警规则是否加载。
7. Alertmanager 是否收到告警。
8. 磁盘、内存、查询压力是否异常。

常用入口：

```text
http://prometheus.example.com:9090/targets
http://prometheus.example.com:9090/alerts
http://prometheus.example.com:9090/rules
http://prometheus.example.com:9090/status
```

## 9.2 Prometheus 启动失败

排查：

```bash
systemctl status prometheus  # 查看服务状态
journalctl -u prometheus -n 300 --no-pager  # 查看启动日志
promtool check config /etc/prometheus/prometheus.yml  # 校验配置文件
```

常见原因：

- YAML 格式错误。
- 配置参数不支持当前版本。
- 端口 `9090` 被占用。
- 数据目录权限错误。
- TSDB 数据损坏。

端口检查：

```bash
ss -lntp | grep 9090  # 检查 9090 是否被占用
```

权限修复：

```bash
chown -R prometheus:prometheus /var/lib/prometheus /etc/prometheus  # 修复目录权限
```

## 9.3 Targets down

页面：

```text
Status -> Targets
```

排查：

```bash
curl http://target-host:9100/metrics  # 从 Prometheus 主机访问目标 metrics
curl http://localhost:9090/api/v1/targets  # 查看 Targets API
```

常见原因：

- Exporter 未启动。
- Prometheus 到目标网络不通。
- 目标地址写错。
- 防火墙或安全组未放行。
- metrics path 不对。
- 目标响应慢，超过 `scrape_timeout`。

## 9.4 指标查不到

排查：

```promql
up
up{job="node"}
{__name__=~"node_.*"}
```

常见原因：

- Target down。
- 指标名称写错。
- 标签过滤条件不匹配。
- 时间范围不包含样本。
- Exporter 没有暴露该指标。
- `metric_relabel_configs` 把指标丢弃了。

## 9.5 PromQL 查询慢

常见原因：

- 时间范围太大。
- 查询命中高基数指标。
- 正则匹配范围过宽。
- 聚合维度过多。
- 没有使用 recording rules。
- Prometheus CPU 或磁盘 IO 压力高。

处理：

- 缩小时间范围。
- 减少标签维度。
- 避免全量正则。
- 对常用复杂表达式使用 recording rules。
- 治理高基数指标。

检查 Prometheus 自身：

```promql
prometheus_engine_query_duration_seconds
prometheus_tsdb_head_series
rate(prometheus_tsdb_head_samples_appended_total[5m])
```

## 9.6 告警不触发

排查：

```bash
promtool check rules /etc/prometheus/rules/*.yml  # 校验规则文件
curl http://localhost:9090/api/v1/rules  # 查看已加载规则
curl http://localhost:9090/api/v1/alerts  # 查看当前告警
```

常见原因：

- `rule_files` 没引用规则文件。
- 配置 reload 失败。
- 表达式结果为空。
- `for` 持续时间未满足。
- 告警已恢复。

## 9.7 Alertmanager 没收到告警

排查：

```bash
curl http://localhost:9090/api/v1/alerts  # 查看 Prometheus 告警
curl http://localhost:9093/api/v2/alerts  # 查看 Alertmanager 告警
```

检查 Prometheus 配置：

```yaml
alerting:  # Prometheus 告警发送配置
  alertmanagers:  # Alertmanager 实例列表
    - static_configs:  # 使用静态地址配置
        - targets:  # Alertmanager 地址列表
            - localhost:9093  # 本机 Alertmanager 地址
```

常见原因：

- Alertmanager 地址错误。
- Alertmanager 未启动。
- Prometheus 到 Alertmanager 网络不通。
- 告警规则未触发。

## 9.8 配置 reload 失败

排查：

```bash
promtool check config /etc/prometheus/prometheus.yml  # reload 前校验配置
curl -X POST http://localhost:9090/-/reload  # 触发 reload
journalctl -u prometheus -n 100 --no-pager  # 查看 reload 日志
```

常见原因：

- 未启用 `--web.enable-lifecycle`。
- 配置文件语法错误。
- 规则文件错误。
- reload 请求打到了错误实例。

## 9.9 磁盘增长过快

检查：

```bash
du -sh /var/lib/prometheus  # 查看数据目录大小
df -h  # 查看磁盘空间
```

PromQL：

```promql
prometheus_tsdb_head_series
rate(prometheus_tsdb_head_samples_appended_total[5m])
topk(20, count by (__name__)({__name__=~".+"}))
```

处理：

- 降低保留时间。
- 设置保留大小。
- 减少 scrape 频率。
- 删除高基数指标。
- 接入远端存储或 Thanos / VictoriaMetrics。

启动参数：

```text
--storage.tsdb.retention.time=15d
--storage.tsdb.retention.size=50GB
```

## 9.10 TSDB 数据损坏

现象：

- Prometheus 启动失败。
- 日志出现 block corrupted。
- 查询历史数据失败。

处理思路：

- 先备份当前数据目录。
- 查看 Prometheus 日志定位损坏 block。
- 使用 `promtool tsdb` 工具检查。
- 必要时移除损坏 block。

命令：

```bash
promtool tsdb analyze /var/lib/prometheus  # 分析 TSDB 数据
```

注意：

- 删除 block 会丢失对应时间段数据。
- 生产环境应优先依赖备份或远端存储恢复。

## 9.11 内存占用高

常见原因：

- 活跃时间序列太多。
- 高基数标签。
- 查询范围大。
- scrape 目标过多。
- rule 计算过重。

查看：

```promql
prometheus_tsdb_head_series
prometheus_tsdb_symbol_table_size_bytes
process_resident_memory_bytes{job="prometheus"}
```

处理：

- 治理高基数标签。
- 拆分 Prometheus 实例。
- 使用 recording rules。
- 调整查询范围和面板刷新频率。

## 9.12 常用诊断命令

```bash
systemctl status prometheus  # 服务状态
journalctl -u prometheus -n 300 --no-pager  # 服务日志
promtool check config /etc/prometheus/prometheus.yml  # 配置检查
promtool check rules /etc/prometheus/rules/*.yml  # 规则检查
curl http://localhost:9090/-/healthy  # 健康检查
curl http://localhost:9090/-/ready  # ready 检查
curl http://localhost:9090/api/v1/targets  # Targets API
du -sh /var/lib/prometheus  # 数据目录大小
```

## 9.13 参考资料

- [Prometheus Troubleshooting](https://prometheus.io/docs/prometheus/latest/troubleshooting/)
- [Prometheus Storage](https://prometheus.io/docs/prometheus/latest/storage/)
- [Prometheus HTTP API](https://prometheus.io/docs/prometheus/latest/querying/api/)
