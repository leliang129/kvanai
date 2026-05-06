---
title: Kafka 故障排查
sidebar_position: 5
---

# Kafka 故障排查


## 5.1 排查思路

Kafka 故障建议按链路分层排查：

1. Broker 进程是否存活。
2. KRaft Controller Quorum 是否正常。
3. 客户端能否连接到 `advertised.listeners`。
4. Topic 分区是否有 Leader。
5. 副本是否在 ISR 中。
6. Consumer Group 是否有 Lag。
7. 磁盘、网络、JVM 是否异常。
8. 安全认证和 ACL 是否正确。

常用变量：

```bash
export BOOTSTRAP="localhost:9092"
export TOPIC="demo"
export GROUP="demo-group"
```

常用日志：

```bash
journalctl -u kafka -f
journalctl -u kafka -n 300 --no-pager
tail -f /opt/kafka/logs/server.log
```

## 5.2 Broker 启动失败

检查服务状态：

```bash
systemctl status kafka
journalctl -u kafka -n 300 --no-pager
```

常见原因：

| 原因 | 现象 |
| --- | --- |
| Java 版本不兼容 | 启动直接退出 |
| 配置文件语法错误 | 日志提示无法解析配置 |
| 端口被占用 | bind failed |
| 数据目录权限错误 | permission denied |
| `cluster.id` 不一致 | cluster id mismatch |
| `node.id` 冲突 | quorum 或 broker 注册异常 |

检查端口：

```bash
ss -lntp | grep -E '9092|9093'
```

检查权限：

```bash
ls -ld /data/kafka
chown -R kafka:kafka /data/kafka
```

## 5.3 KRaft Quorum 异常

检查：

```bash
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --status
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --replication
```

重点检查：

- `controller.quorum.voters` 是否所有节点一致。
- `node.id` 是否和 voters 中的 ID 匹配。
- Controller 端口 `9093` 是否互通。
- 所有节点是否使用同一个 `cluster.id`。
- 数据目录中的 `meta.properties` 是否被误删或来自其他集群。

查看元数据：

```bash
cat /data/kafka/meta.properties
```

## 5.4 advertised.listeners 错误

典型现象：

- 本机能连 Kafka，其他机器连不上。
- 客户端连接后拿到 `localhost:9092`。
- Docker 部署时容器内外访问不一致。
- 报错 `Connection to node -1 could not be established`。

检查配置：

```bash
grep -E '^(listeners|advertised.listeners|listener.security.protocol.map)' \
  /opt/kafka/config/kraft/server.properties
```

原则：

- `listeners` 是 Broker 实际监听地址。
- `advertised.listeners` 是返回给客户端访问的地址。
- `advertised.listeners` 必须是客户端能访问的地址。

示例：

```properties
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://10.0.0.11:9092
```

## 5.5 Topic 无法创建

常见原因：

- Broker 数量少于 `replication-factor`。
- Controller Quorum 异常。
- ACL 权限不足。
- Topic 已存在。
- 自动创建 Topic 被关闭。

排查：

```bash
kafka-broker-api-versions.sh --bootstrap-server "$BOOTSTRAP"
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --list
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --status
```

创建时降低副本数验证：

```bash
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --create --topic test-topic \
  --partitions 3 \
  --replication-factor 1
```

## 5.6 分区没有 Leader

查看 unavailable partitions：

```bash
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --unavailable-partitions
```

常见原因：

- Leader 所在 Broker 下线。
- ISR 中没有可用副本。
- 磁盘或网络异常导致副本不可用。
- 集群正在恢复或分区迁移中。

处理方向：

- 先恢复 Broker。
- 检查磁盘、网络、进程。
- 确认是否发生数据目录损坏。
- 谨慎处理 `unclean.leader.election.enable`，开启可能导致数据丢失。

## 5.7 Under Replicated Partitions

查看：

```bash
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --under-replicated-partitions
```

常见原因：

- Broker 离线。
- follower 复制跟不上。
- 磁盘 IO 慢。
- 网络抖动。
- 分区迁移正在执行。
- Broker 负载不均衡。

排查：

```bash
df -h
iostat -x 1
sar -n DEV 1
journalctl -u kafka -n 300 --no-pager
```

## 5.8 消费堆积

查看 Lag：

```bash
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP"
```

判断：

- Lag 持续增长：消费能力不足或消费者异常。
- Lag 稳定不变：可能是消费者停止或没有新消息。
- 某几个分区 Lag 高：可能分区 key 倾斜。

排查方向：

- Consumer 实例是否存活。
- Consumer 并发是否小于分区数。
- 消费逻辑是否变慢。
- 下游数据库、缓存、HTTP 接口是否变慢。
- 是否频繁 rebalance。
- 是否存在热点 key。

处理方式：

- 增加消费者实例，但不能超过分区数获得更多并发。
- 优化消费逻辑和下游依赖。
- 增加 Topic 分区数。
- 处理热点 key。
- 对非关键消息评估是否跳过或重置 offset。

## 5.9 Offset 重置风险

重置 offset 前必须先 dry-run：

```bash
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" \
  --reset-offsets --to-earliest \
  --dry-run --topic "$TOPIC"
```

执行：

```bash
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" \
  --reset-offsets --to-earliest \
  --execute --topic "$TOPIC"
```

注意：

- 重置 offset 可能导致重复消费。
- 跳到最新可能导致消息被跳过。
- 执行前应停止对应消费者。
- 关键业务需要业务方确认。

## 5.10 磁盘满

检查：

```bash
df -h
du -sh /data/kafka/*
```

临时处理：

- 扩容磁盘。
- 调小非关键 Topic 保留时间。
- 删除无用 Topic。
- 停止异常写入。

修改 Topic 保留时间：

```bash
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics \
  --entity-name "$TOPIC" \
  --alter --add-config retention.ms=3600000
```

注意：

- 不要直接手工删除 Kafka 数据目录里的日志文件。
- 直接删除可能导致分区不可用或数据损坏。
- 清理受 segment 滚动影响，不一定立刻释放空间。

## 5.11 消息过大

常见现象：

- Producer 报 `RecordTooLargeException`。
- Broker 报 message size too large。
- Consumer 拉取失败。

相关配置：

| 组件 | 配置 |
| --- | --- |
| Broker / Topic | `message.max.bytes` |
| Producer | `max.request.size` |
| Consumer | `fetch.max.bytes`、`max.partition.fetch.bytes` |

建议：

- 大文件写对象存储，Kafka 只传 URL 或元数据。
- 如果必须支持大消息，Producer、Broker、Consumer 要同步调整。
- 大消息 Topic 建议单独隔离。

## 5.12 认证和 ACL 问题

常见现象：

- `SaslAuthenticationException`。
- `TopicAuthorizationException`。
- `GroupAuthorizationException`。
- Producer 能连接但不能写。
- Consumer 能连但不能读或不能提交 offset。

检查 ACL：

```bash
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" --list
```

常见授权：

```bash
# 写 Topic
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" \
  --add --allow-principal User:app \
  --operation Write --topic "$TOPIC"

# 读 Topic 和 Group
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" \
  --add --allow-principal User:app \
  --operation Read --topic "$TOPIC" \
  --operation Read --group "$GROUP"
```

排查方向：

- 客户端 SASL 用户名密码是否正确。
- 认证机制是否一致。
- Topic 权限和 Group 权限是否都配置。
- 是否连接到了错误环境的 Kafka。

## 5.13 Producer 写入慢

排查方向：

- Broker 磁盘 IO 是否慢。
- 网络延迟是否高。
- `acks=all` 下 ISR 是否不足。
- Producer batch 是否太小。
- 是否使用了同步发送。
- 是否有热点分区。

常见优化：

- 合理增大 `batch.size`。
- 合理增大 `linger.ms`。
- 开启压缩，如 `compression.type=lz4` 或 `zstd`。
- 优化 key 分布，避免热点分区。

## 5.14 Consumer 频繁 Rebalance

常见原因：

- 消费处理时间超过 `max.poll.interval.ms`。
- 心跳异常。
- Consumer 实例频繁重启。
- Consumer Group 成员数量变化。
- 单次拉取消息太多，处理过慢。

排查：

```bash
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP" --members
```

优化：

- 降低单批处理耗时。
- 调整 `max.poll.interval.ms`。
- 调整 `max.poll.records`。
- 使用稳定的 Consumer 实例数。
- 检查应用重启和异常日志。

## 5.15 常用诊断清单

```bash
# Broker API
kafka-broker-api-versions.sh --bootstrap-server "$BOOTSTRAP"

# KRaft 状态
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --status

# Topic 状态
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --topic "$TOPIC"

# 无 Leader 分区
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --unavailable-partitions

# 副本不同步分区
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --under-replicated-partitions

# 消费组 Lag
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" --describe --group "$GROUP"

# 磁盘
df -h
du -sh /data/kafka/*

# 端口
ss -lntp | grep -E '9092|9093'

# 日志
journalctl -u kafka -n 300 --no-pager
```

## 5.16 参考资料

- [Apache Kafka Operations](https://kafka.apache.org/documentation/#operations)
- [Apache Kafka KRaft](https://kafka.apache.org/documentation/#kraft)
- [Apache Kafka Topic Configs](https://kafka.apache.org/documentation/#topicconfigs)
- [Apache Kafka Consumer Configs](https://kafka.apache.org/documentation/#consumerconfigs)
- [Apache Kafka Producer Configs](https://kafka.apache.org/documentation/#producerconfigs)
