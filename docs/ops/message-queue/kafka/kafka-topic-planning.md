---
title: Kafka Topic 规划
sidebar_position: 2
---

# Kafka Topic 规划


## 2.1 规划目标

Topic 规划决定 Kafka 后续的吞吐、扩展、可靠性和运维成本。生产环境不建议让应用自动创建 Topic，应由平台或运维提前规划。

Topic 规划重点：

- 命名规范。
- 分区数。
- 副本数。
- `min.insync.replicas`。
- 保留时间和保留大小。
- 是否启用压缩清理。
- 消息大小限制。
- 权限和责任人。

建议生产关闭自动创建 Topic：

```properties
auto.create.topics.enable=false
```

## 2.2 命名规范

推荐命名格式：

```text
<domain>.<service>.<event>.<env>
```

示例：

```text
order.payment.created.prod
user.profile.updated.test
log.nginx.access.prod
```

命名建议：

- 使用小写字母、数字、点号、短横线。
- 不建议使用空格、中文、特殊符号。
- 名称体现业务域、事件含义和环境。
- 测试和生产 Topic 分开。
- 不把临时调试 Topic 混入生产命名空间。

不建议：

```text
test
demo
topic1
order
```

## 2.3 分区数规划

分区数影响：

- Topic 吞吐能力。
- Consumer Group 最大并发消费数。
- 文件句柄和元数据规模。
- 分区迁移成本。
- 故障恢复耗时。

基本原则：

- 分区数只能增加，不能减少。
- 同一个 Consumer Group 中，单个 Topic 的有效消费并发不超过分区数。
- 分区过多会增加 Broker、Controller 和客户端开销。
- 不要为了“以后可能用到”盲目创建大量分区。

粗略估算：

```text
分区数 >= 期望总吞吐 / 单分区可承载吞吐
分区数 >= 最大消费并发数
```

示例：

| 场景 | 建议起步分区数 |
| --- | --- |
| 低频业务事件 | `3` |
| 普通业务事件 | `6` 或 `12` |
| 日志类高吞吐 Topic | `12`、`24` 或更高 |
| 延迟敏感小流量 | `3` 或 `6` |

创建示例：

```bash
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --create --topic order.payment.created.prod \
  --partitions 6 \
  --replication-factor 3
```

## 2.4 副本数规划

副本数决定可用性和数据可靠性。

常见建议：

| 环境 | 副本数 |
| --- | --- |
| 本地测试 | `1` |
| 测试集群 | `2` 或 `3` |
| 生产集群 | `3` |

生产建议：

```text
replication.factor=3
```

原因：

- 允许单 Broker 故障时继续服务。
- 配合 `min.insync.replicas=2` 和 Producer `acks=all`，提升写入可靠性。
- 副本越多，磁盘和网络复制成本越高。

## 2.5 min.insync.replicas

`min.insync.replicas` 表示写入成功时必须保持同步的最小副本数。它通常和 Producer 的 `acks=all` 一起使用。

三副本生产 Topic 推荐：

```bash
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics \
  --entity-name order.payment.created.prod \
  --alter --add-config min.insync.replicas=2
```

效果：

- 当 ISR 数量小于 `2` 时，Producer 写入会失败。
- 可以避免只有 1 个副本可用时仍然确认写入成功。
- 提升可靠性，但在副本异常时会牺牲可用性。

常见组合：

| replication.factor | min.insync.replicas | Producer acks | 说明 |
| --- | --- | --- | --- |
| `1` | `1` | `1` 或 `all` | 仅测试 |
| `3` | `2` | `all` | 生产推荐 |
| `3` | `1` | `all` | 可用性高，可靠性弱 |

## 2.6 保留策略

Kafka 支持按时间和大小清理消息。

按时间保留：

```bash
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics \
  --entity-name order.payment.created.prod \
  --alter --add-config retention.ms=604800000
```

按大小保留：

```bash
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics \
  --entity-name order.payment.created.prod \
  --alter --add-config retention.bytes=10737418240
```

常见建议：

| Topic 类型 | 保留策略 |
| --- | --- |
| 业务事件 | `3-7` 天 |
| 审计事件 | 按合规要求，可能更长 |
| 日志类 Topic | 按磁盘容量规划 |
| 临时 Topic | `1` 天或更短 |

注意：

- `retention.ms` 和 `retention.bytes` 同时配置时，任一条件满足都可能触发清理。
- 清理不是实时删除，受日志段滚动和清理周期影响。
- 保留时间越长，磁盘规划越重要。

## 2.7 压缩清理

Kafka 支持 `cleanup.policy=compact`，按 key 保留最新值，适合状态类 Topic。

适合：

- 用户状态。
- 配置变更。
- 维表同步。
- 需要按 key 保留最终状态的事件。

配置：

```bash
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics \
  --entity-name user.profile.snapshot.prod \
  --alter --add-config cleanup.policy=compact
```

也可以同时启用删除和压缩：

```bash
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics \
  --entity-name user.profile.snapshot.prod \
  --alter --add-config cleanup.policy=compact,delete
```

注意：

- compact Topic 必须合理设计 key。
- 没有 key 的消息不适合 compact。
- compact 不保证只保留一条记录，它是后台异步清理。

## 2.8 消息大小限制

默认情况下 Kafka 不适合传输很大的消息。大消息会影响 Broker 内存、网络、Page Cache、复制和消费延迟。

相关配置：

| 配置 | 位置 | 说明 |
| --- | --- | --- |
| `message.max.bytes` | Broker / Topic | Broker 接受的最大消息大小 |
| `max.request.size` | Producer | Producer 单次请求最大大小 |
| `fetch.max.bytes` | Consumer | Consumer 单次拉取最大大小 |
| `max.partition.fetch.bytes` | Consumer | 单分区单次拉取最大大小 |

建议：

- 大文件不要直接写入 Kafka，应写对象存储，只在 Kafka 传引用地址。
- 如必须调大消息限制，Producer、Broker、Consumer 需要一起调整。
- 大消息 Topic 建议独立规划，避免影响普通业务 Topic。

## 2.9 权限规划

Topic 创建时建议同步记录：

- 业务负责人。
- 生产者应用。
- 消费者应用。
- 保留时间。
- 分区数。
- 副本数。
- 是否允许删除。
- 是否允许外部系统访问。

ACL 示例：

```bash
# 允许 app-order 写入 Topic
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" \
  --add --allow-principal User:app-order \
  --operation Write \
  --topic order.payment.created.prod

# 允许 app-billing 读取 Topic 和消费组
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" \
  --add --allow-principal User:app-billing \
  --operation Read \
  --topic order.payment.created.prod \
  --operation Read \
  --group billing-service
```

## 2.10 Topic 申请模板

建议在团队内部使用固定模板：

```text
Topic 名称：
业务说明：
环境：
生产者：
消费者：
预估 QPS：
单条消息平均大小：
保留时间：
分区数：
副本数：
min.insync.replicas：
cleanup.policy：
是否包含敏感数据：
负责人：
```

## 2.11 常见问题

### 2.11.1 分区数应该设置多少

先根据吞吐和消费者并发估算，再保守留余量。不要一开始设置过大。普通业务 Topic 通常从 `6` 或 `12` 起步，高吞吐日志类 Topic 单独评估。

### 2.11.2 后续能不能减少分区

不能直接减少。需要新建 Topic、迁移生产消费链路，再下线旧 Topic。

### 2.11.3 副本数是不是越多越好

不是。副本越多，磁盘和网络复制成本越高。多数生产场景 `3` 副本已经是常规选择。

### 2.11.4 Topic 可以自动创建吗

生产不建议。自动创建容易掩盖应用配置错误，也会导致分区数、副本数、保留策略不符合预期。

## 2.12 参考资料

- [Apache Kafka Topic Configs](https://kafka.apache.org/documentation/#topicconfigs)
- [Apache Kafka Operations](https://kafka.apache.org/documentation/#operations)
- [Apache Kafka Producer Configs](https://kafka.apache.org/documentation/#producerconfigs)
- [Apache Kafka Consumer Configs](https://kafka.apache.org/documentation/#consumerconfigs)
