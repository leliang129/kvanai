---
title: Kafka 监控与告警
sidebar_position: 4
---

# Kafka 监控与告警


## 4.1 监控目标

Kafka 监控要覆盖四类对象：

| 对象 | 关注点 |
| --- | --- |
| Broker | 存活、请求、网络、磁盘、JVM |
| Topic / Partition | 分区、Leader、ISR、Under Replicated |
| Producer / Consumer | 写入速率、消费速率、错误、延迟 |
| Consumer Group | Lag、消费状态、成员变化 |

生产环境最低要求：

- Broker 存活告警。
- Under Replicated Partitions 告警。
- Offline Partitions 告警。
- Consumer Lag 告警。
- 磁盘容量告警。
- JVM Heap / GC 告警。
- Controller Quorum 异常告警。

## 4.2 监控方案

常见方案：

| 方案 | 说明 |
| --- | --- |
| JMX + Prometheus JMX Exporter | 采集 Kafka Broker JMX 指标 |
| kafka-exporter | 采集 Consumer Group Lag、Topic、Partition 指标 |
| Burrow | 专注 Consumer Lag 监控 |
| Grafana | 展示 Kafka 指标面板 |
| Alertmanager | 告警通知 |

建议组合：

```text
Kafka Broker -> JMX Exporter -> Prometheus -> Grafana / Alertmanager
kafka-exporter -> Prometheus -> Grafana / Alertmanager
Node Exporter -> Prometheus -> 主机磁盘/CPU/网络监控
```

## 4.3 JMX Exporter 接入

下载 JMX Exporter：

```bash
mkdir -p /opt/jmx-exporter
cd /opt/jmx-exporter
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/1.1.0/jmx_prometheus_javaagent-1.1.0.jar
```

配置文件：

```yaml title="/opt/jmx-exporter/kafka.yml"
lowercaseOutputName: true
rules:
  - pattern: kafka.server<type=(.+), name=(.+)PerSec\w*><>Count
    name: kafka_server_$1_$2_total
    type: COUNTER

  - pattern: kafka.server<type=(.+), name=(.+)><>Value
    name: kafka_server_$1_$2
    type: GAUGE

  - pattern: kafka.controller<type=(.+), name=(.+)><>Value
    name: kafka_controller_$1_$2
    type: GAUGE

  - pattern: kafka.network<type=(.+), name=(.+)><>Value
    name: kafka_network_$1_$2
    type: GAUGE

  - pattern: java.lang<type=Memory><HeapMemoryUsage>used
    name: jvm_memory_heap_used_bytes
    type: GAUGE

  - pattern: java.lang<type=Memory><HeapMemoryUsage>max
    name: jvm_memory_heap_max_bytes
    type: GAUGE
```

Kafka 启动参数：

```bash
export KAFKA_OPTS="$KAFKA_OPTS -javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent-1.1.0.jar=9404:/opt/jmx-exporter/kafka.yml"
```

systemd 示例：

```ini
Environment="KAFKA_OPTS=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent-1.1.0.jar=9404:/opt/jmx-exporter/kafka.yml"
```

验证：

```bash
curl http://localhost:9404/metrics | head
```

## 4.4 kafka-exporter

`kafka-exporter` 常用于采集 Topic、Partition、Consumer Group Lag。

Docker 示例：

```bash
docker run -d \
  --name kafka-exporter \
  --restart unless-stopped \
  -p 9308:9308 \
  danielqsj/kafka-exporter \
  --kafka.server=10.0.0.11:9092 \
  --kafka.server=10.0.0.12:9092 \
  --kafka.server=10.0.0.13:9092
```

验证：

```bash
curl http://localhost:9308/metrics | head
```

常见指标：

| 指标 | 说明 |
| --- | --- |
| `kafka_consumergroup_lag` | Consumer Group Lag |
| `kafka_topic_partitions` | Topic 分区数 |
| `kafka_topic_partition_current_offset` | 分区最新 offset |
| `kafka_consumergroup_current_offset` | 消费组当前 offset |
| `kafka_brokers` | Broker 数量 |

## 4.5 Prometheus 配置

```yaml title="prometheus.yml"
scrape_configs:
  - job_name: kafka-broker-jmx
    static_configs:
      - targets:
          - 10.0.0.11:9404
          - 10.0.0.12:9404
          - 10.0.0.13:9404

  - job_name: kafka-exporter
    static_configs:
      - targets:
          - 10.0.0.20:9308

  - job_name: node-exporter
    static_configs:
      - targets:
          - 10.0.0.11:9100
          - 10.0.0.12:9100
          - 10.0.0.13:9100
```

## 4.6 核心指标

### 4.6.1 Broker 存活

关注：

- Broker 进程是否存活。
- Broker 数量是否符合预期。
- Controller 是否正常。

命令检查：

```bash
kafka-broker-api-versions.sh --bootstrap-server "$BOOTSTRAP"
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --status
```

### 4.6.2 Under Replicated Partitions

含义：

- 有分区副本不在 ISR 中。
- 通常表示 Broker 故障、磁盘慢、网络慢或复制跟不上。

命令：

```bash
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --under-replicated-partitions
```

告警建议：

```text
UnderReplicatedPartitions > 0 持续 5 分钟
```

### 4.6.3 Offline Partitions

含义：

- 分区没有可用 Leader。
- 业务读写会受影响，属于高优先级故障。

命令：

```bash
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --unavailable-partitions
```

告警建议：

```text
OfflinePartitionsCount > 0 立即告警
```

### 4.6.4 Consumer Lag

Lag 表示消费者落后生产者的消息数量。

命令：

```bash
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP"
```

告警建议：

- 按业务 Topic 设置不同阈值。
- 只看绝对 Lag 不够，还要看 Lag 是否持续增长。
- 对离线任务和实时任务设置不同阈值。

### 4.6.5 磁盘

Kafka 强依赖磁盘容量和 IO。

检查：

```bash
df -h
du -sh /data/kafka/*
iostat -x 1
```

告警建议：

- 磁盘使用率 `> 80%` 预警。
- 磁盘使用率 `> 90%` 严重告警。
- IO await 持续偏高需要排查。

### 4.6.6 JVM 与 GC

关注：

- Heap 使用率。
- Full GC 次数和耗时。
- 进程是否 OOM。
- Page Cache 是否被挤压。

建议：

- Kafka 不应把所有内存都给 JVM Heap。
- 需要给 OS Page Cache 留足内存。
- 常见 Heap 配置为 `4G-8G`，具体按规模评估。

## 4.7 告警规则示例

Prometheus 规则示例：

```yaml title="kafka-alerts.yml"
groups:
  - name: kafka
    rules:
      - alert: KafkaBrokerDown
        expr: up{job="kafka-broker-jmx"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Kafka broker exporter is down"

      - alert: KafkaConsumerLagHigh
        expr: kafka_consumergroup_lag > 100000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Kafka consumer lag is high"

      - alert: KafkaDiskUsageHigh
        expr: (1 - node_filesystem_avail_bytes{mountpoint="/data"} / node_filesystem_size_bytes{mountpoint="/data"}) > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Kafka data disk usage is high"
```

说明：

- 指标名会受 Exporter 配置影响，实际规则需要以 Prometheus 中的指标为准。
- Consumer Lag 阈值必须按业务设置，不建议全局一个阈值。

## 4.8 Grafana 面板

建议面板：

- Broker 存活状态。
- Broker 请求速率。
- Bytes In / Bytes Out。
- Messages In。
- Under Replicated Partitions。
- Offline Partitions。
- Consumer Group Lag TopN。
- Topic 流量 TopN。
- JVM Heap / GC。
- 磁盘容量和 IO。
- 网络流量。

使用建议：

- 大屏关注集群级健康。
- 运维面板保留 Broker、Topic、Consumer Group 下钻。
- 业务团队面板只暴露自身 Topic 和 Consumer Group。

## 4.9 常见问题

### 4.9.1 JMX Exporter 没有指标

排查：

```bash
ps aux | grep jmx_prometheus_javaagent
curl http://localhost:9404/metrics
journalctl -u kafka -n 200 --no-pager
```

常见原因：

- `KAFKA_OPTS` 没有生效。
- jar 路径错误。
- 配置文件路径错误。
- 端口被占用。

### 4.9.2 Consumer Lag 一直增长

排查方向：

- 消费者是否存活。
- 消费者并发是否小于分区数。
- 消费逻辑是否变慢。
- 下游数据库或接口是否变慢。
- 是否出现大量重试。

### 4.9.3 Under Replicated Partitions 告警

排查方向：

- Broker 是否离线。
- Broker 磁盘 IO 是否异常。
- 网络是否抖动。
- 分区迁移是否正在执行。
- follower 是否复制跟不上。

### 4.9.4 磁盘增长过快

排查：

- Topic 保留策略是否过长。
- 是否有异常流量。
- 是否创建了过多副本。
- 是否存在大消息。
- 是否有 Topic 未设置合理保留策略。

## 4.10 参考资料

- [Apache Kafka Monitoring](https://kafka.apache.org/documentation/#monitoring)
- [Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter)
- [kafka-exporter](https://github.com/danielqsj/kafka_exporter)
- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
