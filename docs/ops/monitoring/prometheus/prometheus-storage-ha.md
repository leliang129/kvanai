---
title: Prometheus 存储与高可用
sidebar_position: 12
---

# Prometheus 存储与高可用


## 10.1 TSDB 存储说明

Prometheus 默认使用本地 TSDB 存储指标数据。它适合单机高性能写入和近周期查询，但不负责跨节点复制，也不适合作为长期历史仓库。

核心特点：

- 数据默认写入 `--storage.tsdb.path` 指定目录。
- 新样本先写入 WAL，再进入 Head Block。
- 历史数据会压缩成按时间切分的 Block。
- 本地数据只属于当前 Prometheus 实例。
- 高可用、长期存储和全局查询通常依赖 Thanos、Cortex、Mimir、VictoriaMetrics 等方案。

常见目录：

```text
/var/lib/prometheus
├── 01HXXX...          # 历史数据块
├── chunks_head        # 当前活跃块数据
├── queries.active     # 当前活跃查询记录
└── wal                # 预写日志
```

## 10.2 保留时间与容量限制

常用启动参数：

```bash
prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=15d \
  --storage.tsdb.retention.size=100GB  # 启动 Prometheus，并限制本地数据保留 15 天或最大 100GB
```

参数说明：

| 参数 | 说明 |
| --- | --- |
| `--storage.tsdb.retention.time` | 按时间保留数据，如 `15d`、`30d` |
| `--storage.tsdb.retention.size` | 按数据目录大小保留数据，如 `100GB` |
| `--storage.tsdb.path` | TSDB 数据目录 |

注意：

- 同时设置时间和大小时，任一条件触发都可能清理旧数据。
- `retention.size` 应低于磁盘总容量，预留 WAL、压缩和系统空间。
- 不建议把 Prometheus 数据目录放在系统盘。

## 10.3 磁盘规划

容量主要受以下因素影响：

| 因素 | 影响 |
| --- | --- |
| Target 数量 | 采集目标越多，样本越多 |
| 指标数量 | Exporter 暴露指标越多，写入越多 |
| 标签基数 | 标签组合越多，时间序列越多 |
| 采集间隔 | 间隔越短，样本增长越快 |
| 保留时间 | 保留越久，磁盘越大 |

粗略估算：

```text
每日样本量 = 活跃时间序列数 * 86400 / scrape_interval
```

检查当前规模：

```bash
du -sh /var/lib/prometheus  # 查看 Prometheus 数据目录大小
df -h /var/lib/prometheus  # 查看数据盘剩余空间
curl -s http://localhost:9090/api/v1/status/tsdb | jq '.data.headStats'  # 查看 Head Block 时间序列统计
```

常用自监控指标：

```promql
prometheus_tsdb_head_series
rate(prometheus_tsdb_head_samples_appended_total[5m])
prometheus_tsdb_storage_blocks_bytes
prometheus_tsdb_wal_segment_current
```

## 10.4 WAL 与 Block

WAL 用于保证异常退出后能恢复最近写入的数据。Block 是已经压缩落盘的历史数据。

运维关注点：

- WAL 增长快通常说明写入压力大或压缩异常。
- Block 数量异常多可能影响查询和启动速度。
- 非正常关机后启动慢，通常是在重放 WAL。
- 不要手工删除 WAL 或 Block，除非已经确认损坏范围并完成备份。

分析 TSDB：

```bash
promtool tsdb analyze /var/lib/prometheus  # 分析 TSDB 指标、标签和高基数情况
ls -lh /var/lib/prometheus/wal  # 查看 WAL 文件数量和大小
ls -lh /var/lib/prometheus  # 查看 Block 目录和元数据文件
```

## 10.5 备份与恢复

Prometheus 本地数据可以备份，但需要注意一致性。更推荐使用快照或底层存储快照，不建议直接在线复制整个数据目录。

创建快照需要启用 `--web.enable-admin-api`：

```bash
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot  # 创建 TSDB 快照
ls -lh /var/lib/prometheus/snapshots  # 查看快照目录
```

恢复思路：

1. 停止 Prometheus。
2. 备份当前数据目录。
3. 将快照数据复制到新的数据目录。
4. 修复目录权限。
5. 启动 Prometheus 并检查日志。

示例：

```bash
systemctl stop prometheus  # 停止 Prometheus 服务
mv /var/lib/prometheus /var/lib/prometheus.bak  # 备份旧数据目录
mkdir -p /var/lib/prometheus  # 创建新的数据目录
SNAPSHOT_DIR=/var/lib/prometheus.bak/snapshots/20260506T120000Z-xxxxxxxx  # 设置需要恢复的快照目录
cp -a "$SNAPSHOT_DIR"/* /var/lib/prometheus/  # 复制快照数据
chown -R prometheus:prometheus /var/lib/prometheus  # 修复数据目录权限
systemctl start prometheus  # 启动 Prometheus 服务
```

注意：

- 快照只解决本地数据恢复，不等同于跨机房容灾。
- 启用 admin API 后要限制访问来源。
- 长期历史数据建议使用对象存储或远端存储方案。

## 10.6 Federation

Federation 用于上层 Prometheus 从下层 Prometheus 拉取聚合后的指标。

适合场景：

- 多个机房或环境需要汇总核心指标。
- 上层只需要少量聚合指标，不需要全量明细。
- 希望按业务或集群拆分采集压力。

上层配置示例：

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: federate-prod  # Federation 采集任务名称
    scrape_interval: 30s  # 每 30 秒从下层 Prometheus 拉取一次
    honor_labels: true  # 保留下层 Prometheus 返回的原始标签
    metrics_path: /federate  # 使用 Prometheus federation API
    params:  # 传给 /federate 的查询参数
      match[]:  # 指定需要拉取的指标匹配条件
        - '{job="prometheus"}'  # 拉取 job=prometheus 的指标
        - '{__name__=~"job:.*"}'  # 拉取 job: 开头的聚合指标
    static_configs:  # 使用静态目标配置
      - targets:  # 下层 Prometheus 地址列表
          - prometheus-prod-a:9090  # 生产 A Prometheus
          - prometheus-prod-b:9090  # 生产 B Prometheus
```

建议：

- Federation 不适合拉全量指标。
- 优先拉 recording rules 生成的聚合指标。
- 上下层标签要统一规划，避免 `job`、`instance` 混乱。

## 10.7 remote_write

`remote_write` 用于把 Prometheus 采集到的样本写入远端存储。

常见后端：

- VictoriaMetrics。
- Grafana Mimir。
- Cortex。
- Thanos Receive。
- 云厂商托管 Prometheus。

配置示例：

```yaml
remote_write:  # 远端写入配置
  - url: http://vm-single:8428/api/v1/write  # 远端存储写入地址
    queue_config:  # remote_write 队列配置
      max_samples_per_send: 10000  # 单次请求最多发送的样本数
      capacity: 20000  # 每个 shard 的队列容量
      max_shards: 30  # 最大并发写入 shard 数
```

自监控指标：

```promql
rate(prometheus_remote_storage_samples_total[5m])
prometheus_remote_storage_samples_pending
prometheus_remote_storage_failed_samples_total
prometheus_remote_storage_shards
```

处理建议：

- 远端写入失败时，先看网络、后端容量和限流。
- pending 持续增长说明写入速度跟不上采集速度。
- remote_write 不是本地高可用复制，Prometheus 本地仍要保留短期数据。

## 10.8 Thanos 方案

Thanos 常用于 Prometheus 长期存储、全局查询和 HA 去重。

常见组件：

| 组件 | 说明 |
| --- | --- |
| Sidecar | 跟随 Prometheus，上传 Block 到对象存储 |
| Query | 全局查询入口，支持 HA 去重 |
| Store Gateway | 查询对象存储中的历史 Block |
| Compactor | 压缩和降采样对象存储数据 |
| Ruler | 统一执行规则 |
| Receive | 接收 remote_write 数据 |

典型结构：

```text
Prometheus A + Sidecar \
                        -> Thanos Query -> Grafana
Prometheus B + Sidecar /
             |
             v
        Object Storage -> Store Gateway -> Query
```

Prometheus 外部标签示例：

```yaml
global:  # 全局配置
  external_labels:  # 写入到所有时间序列和告警上的外部标签
    cluster: prod-a  # 标识所属集群
    replica: prometheus-0  # 标识 Prometheus 副本，用于查询层去重
```

HA 去重依赖：

- 两个 Prometheus 抓取同一批目标。
- `external_labels` 中设置不同 `replica`。
- Thanos Query 配置 `--query.replica-label=replica`。

## 10.9 VictoriaMetrics 方案

VictoriaMetrics 常用于 remote_write 后端，也可以作为 Prometheus 兼容查询入口。

单机写入示例：

```yaml
remote_write:  # 远端写入配置
  - url: http://victoriametrics:8428/api/v1/write  # VictoriaMetrics 写入地址
```

查询入口：

```text
http://victoriametrics:8428/select/0/prometheus
```

适合场景：

- 希望快速接入长期存储。
- 指标量较大，需要更高压缩率。
- 需要 Prometheus 兼容 API 给 Grafana 查询。

注意：

- 单机版仍存在单点风险。
- 集群版需要规划 `vminsert`、`vmselect`、`vmstorage`。
- 告警和 recording rules 可以继续由 Prometheus 或 vmalert 执行。

## 10.10 Prometheus HA

Prometheus 自身不做多副本数据复制。常见 HA 做法是部署两个 Prometheus 实例，配置相同采集目标和规则。

基础模式：

```text
prometheus-a -> targets
prometheus-b -> targets
```

关键点：

- 两个实例独立采集，互不依赖。
- Alertmanager 集群负责告警去重。
- Grafana 可以接 Thanos Query、VictoriaMetrics 或手动配置多个数据源。
- 只用两个原生 Prometheus 时，查询层不会自动去重。

Alertmanager 集群示例：

```bash
alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager \
  --cluster.listen-address=0.0.0.0:9094 \
  --cluster.peer=10.0.0.12:9094  # 启动 Alertmanager 并加入对端节点实现告警去重
```

Prometheus 对接多个 Alertmanager：

```yaml
alerting:  # Prometheus 告警发送配置
  alertmanagers:  # Alertmanager 实例列表
    - static_configs:  # 使用静态地址配置
        - targets:  # Alertmanager 地址列表
            - 10.0.0.11:9093  # 第一个 Alertmanager 节点
            - 10.0.0.12:9093  # 第二个 Alertmanager 节点
```

## 10.11 拆分与扩容策略

当单个 Prometheus 压力过高时，优先考虑拆分。

常见拆分方式：

| 方式 | 说明 |
| --- | --- |
| 按环境拆分 | `prod`、`test`、`dev` 分开 |
| 按区域拆分 | 不同机房或云区域分开 |
| 按系统拆分 | Kubernetes、数据库、中间件、业务服务分开 |
| 按团队拆分 | 不同团队独立 Prometheus |

扩容建议：

- 先治理高基数指标，再加机器。
- 常用复杂查询改成 recording rules。
- Grafana 面板避免默认查询超长时间范围。
- 超大规模环境使用 Thanos / Mimir / VictoriaMetrics 等查询层聚合。

## 10.12 常见问题

### 10.12.1 磁盘快满了

排查：

```bash
df -h /var/lib/prometheus  # 查看 Prometheus 数据盘容量
du -sh /var/lib/prometheus/*  # 查看各 Block 和 WAL 占用
promtool tsdb analyze /var/lib/prometheus  # 分析高基数指标和标签
```

处理：

- 降低 `retention.time` 或设置 `retention.size`。
- 删除无用 target 或降低采集频率。
- 使用 `metric_relabel_configs` 丢弃低价值指标。
- 接入远端存储保存长期数据。

### 10.12.2 remote_write pending 持续增长

排查：

```promql
prometheus_remote_storage_samples_pending
rate(prometheus_remote_storage_failed_samples_total[5m])
rate(prometheus_remote_storage_samples_retried_total[5m])
```

处理：

- 检查远端存储是否限流或写入异常。
- 检查 Prometheus 到远端存储网络延迟。
- 适当增大 `queue_config.max_shards`。
- 降低采集量或拆分 Prometheus。

### 10.12.3 两个 Prometheus 告警重复

处理：

- 两个 Prometheus 配置相同 `external_labels` 维度，但 `replica` 不同。
- Prometheus 同时发送到同一组 Alertmanager 集群。
- Alertmanager 路由中的 `group_by` 不要包含 `replica`。
- 通知模板中可以展示 `replica`，但不建议用于分组。

### 10.12.4 Thanos 查询重复数据

处理：

- 检查 Prometheus 是否设置唯一 `external_labels.replica`。
- 检查 Thanos Query 是否配置 `--query.replica-label=replica`。
- 检查两个 Prometheus 是否真的采集同一批目标。

## 10.13 参考资料

- [Prometheus Storage](https://prometheus.io/docs/prometheus/latest/storage/)
- [Prometheus Federation](https://prometheus.io/docs/prometheus/latest/federation/)
- [Prometheus Remote Write](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write)
- [Thanos](https://thanos.io/)
- [VictoriaMetrics](https://docs.victoriametrics.com/)
