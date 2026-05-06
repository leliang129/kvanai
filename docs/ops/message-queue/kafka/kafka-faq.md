---
title: Kafka 常见故障 Q&A
sidebar_position: 6
---

# Kafka 常见故障 Q&A


## Q1：客户端连不上 Kafka，提示 connection refused / timed out 怎么办？

常见原因：

- Kafka 进程未启动。
- `9092` 端口未监听。
- 防火墙或安全组未放行。
- 客户端访问了错误的 Broker 地址。
- `advertised.listeners` 返回了客户端不可访问的地址。

处理：

```bash
systemctl status kafka
ss -lntp | grep 9092
kafka-broker-api-versions.sh --bootstrap-server 10.0.0.11:9092
```

先确认 Kafka 服务和端口正常，再检查防火墙、安全组和 `advertised.listeners`。

## Q2：本机能连 Kafka，其他机器连不上，为什么？

最常见原因是 `advertised.listeners` 配成了 `localhost`。

错误示例：

```properties
advertised.listeners=PLAINTEXT://localhost:9092
```

生产应配置为客户端可访问的 IP 或域名：

```properties
advertised.listeners=PLAINTEXT://10.0.0.11:9092
```

修改后重启 Kafka：

```bash
systemctl restart kafka
```

## Q3：创建 Topic 报 replication factor larger than available brokers 怎么办？

原因是指定的副本数大于当前可用 Broker 数。

处理：

- 测试环境把 `--replication-factor` 调为 `1`。
- 生产环境先确认所有 Broker 都正常启动。
- 三副本 Topic 至少需要 3 个可用 Broker。

检查 Broker：

```bash
kafka-broker-api-versions.sh --bootstrap-server "$BOOTSTRAP"
```

## Q4：Topic 没有 Leader，业务无法读写怎么办？

现象：

- `LEADER_NOT_AVAILABLE`。
- `NotLeaderOrFollowerException`。
- Topic describe 显示 Leader 为 `-1`。

排查：

```bash
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --unavailable-partitions

kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --topic "$TOPIC"
```

处理：

- 先恢复离线 Broker。
- 检查 Broker 磁盘、网络、进程。
- 检查 ISR 是否为空。
- 不要随意开启 `unclean.leader.election.enable`，它可能导致数据丢失。

## Q5：Under Replicated Partitions 一直告警怎么办？

含义：

- 有副本没有跟上 Leader，不在 ISR 中。

排查：

```bash
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --under-replicated-partitions

df -h
iostat -x 1
journalctl -u kafka -n 300 --no-pager
```

处理：

- 恢复异常 Broker。
- 排查磁盘 IO 和网络。
- 暂停或限速分区迁移。
- 对热点 Topic 做分区和副本重新分布。

## Q6：Consumer Lag 持续增长怎么办？

排查：

```bash
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP"
```

判断：

- 所有分区 Lag 增长：消费整体能力不足。
- 少数分区 Lag 增长：可能存在热点 key。
- Lag 不变但不下降：消费者可能停止。

处理：

- 增加消费者实例，但有效并发不超过分区数。
- 优化消费逻辑和下游数据库、HTTP 接口。
- 增加 Topic 分区数。
- 检查是否频繁 rebalance。
- 对热点 key 做拆分或改造分区策略。

## Q7：消费者启动了，但没有消费到历史消息？

常见原因：

- 消费者从最新 offset 开始，历史消息不会消费。
- 消费组已有已提交 offset。
- Topic 名或环境连错。
- ACL 没有 Topic Read 或 Group Read 权限。

处理：

```bash
kafka-console-consumer.sh --bootstrap-server "$BOOTSTRAP" \
  --topic "$TOPIC" \
  --group "debug-${GROUP}-$(date +%s)" \
  --from-beginning \
  --max-messages 10
```

用临时消费组验证 Topic 中是否有历史消息，再决定是否重置正式消费组 offset。

## Q8：重置 offset 后出现重复消费，正常吗？

正常。offset 回退后，消费者会重新读取历史消息。

建议：

- 重置前先 `--dry-run`。
- 执行前停止对应消费者。
- 业务侧需要具备幂等处理能力。
- 关键业务必须让业务负责人确认。

## Q9：Producer 写入很慢怎么办？

常见原因：

- `acks=all` 且 ISR 不稳定。
- Broker 磁盘 IO 慢。
- 网络延迟高。
- Producer 同步发送。
- `batch.size` 太小。
- `linger.ms` 太低。
- key 倾斜导致热点分区。

处理：

- 检查 Under Replicated Partitions。
- 检查磁盘 IO 和网络。
- 开启压缩，如 `compression.type=lz4` 或 `zstd`。
- 合理增大 `batch.size` 和 `linger.ms`。
- 优化 key 分布。

## Q10：Kafka 磁盘快满了怎么办？

先看空间：

```bash
df -h
du -sh /data/kafka/*
```

临时处理：

- 扩容磁盘。
- 降低非核心 Topic 的 `retention.ms`。
- 删除无用 Topic。
- 停止异常写入源。

注意：

- 不要手工删除 `/data/kafka` 下的日志文件。
- Kafka 清理不是实时释放，受 segment 滚动影响。
- 长期方案是按 Topic 规划保留策略和磁盘容量。

## Q11：消息太大导致发送失败怎么办？

常见错误：

- `RecordTooLargeException`。
- `MessageSizeTooLargeException`。

建议：

- 大文件放对象存储，Kafka 只传引用地址。
- 如必须调大限制，Producer、Broker、Consumer 要一起调整。
- 大消息 Topic 单独规划，避免影响普通 Topic。

## Q12：KRaft 节点启动时报 cluster id mismatch 怎么办？

原因：

- 数据目录里的 `meta.properties` 属于另一个 Kafka 集群。
- 节点格式化时使用了不同的 cluster id。

排查：

```bash
cat /data/kafka/meta.properties
```

处理：

- 同一集群所有节点必须使用同一个 cluster id。
- 不要混用不同集群的数据目录。
- 测试环境可以清空数据目录后用同一个 cluster id 重新 format。
- 生产环境不要随意删除数据目录。

## Q13：KRaft Controller Quorum 不正常怎么办？

排查：

```bash
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --status
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --replication
```

重点检查：

- `controller.quorum.voters` 是否所有节点一致。
- `node.id` 是否唯一。
- voters 中的 ID 是否和各节点 `node.id` 匹配。
- Controller 端口是否互通。
- 所有节点 cluster id 是否一致。

## Q14：SASL 认证失败怎么办？

排查：

- 用户名密码是否正确。
- Broker 和客户端 `sasl.mechanism` 是否一致。
- `security.protocol` 是否一致。
- JAAS 配置是否生效。
- 是否连到了错误环境。

验证：

```bash
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --command-config client.properties \
  --list
```

## Q15：ACL 权限不足怎么办？

查看 ACL：

```bash
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" --list
```

授权示例：

```bash
# 允许写 Topic
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" \
  --add --allow-principal User:app \
  --operation Write --topic "$TOPIC"

# 允许读 Topic 和 Group
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" \
  --add --allow-principal User:app \
  --operation Read --topic "$TOPIC" \
  --operation Read --group "$GROUP"
```

## Q16：Consumer 频繁 Rebalance 怎么办？

常见原因：

- 消费处理时间超过 `max.poll.interval.ms`。
- 单次拉取太多，处理过慢。
- Consumer 实例频繁重启。
- 心跳异常。
- Consumer Group 成员频繁变化。

处理：

- 降低 `max.poll.records`。
- 增大 `max.poll.interval.ms`。
- 优化单批处理耗时。
- 保持 Consumer 实例数量稳定。
- 排查应用重启和 OOM。

## Q17：Topic 分区数增加后，消息顺序会受影响吗？

可能会。Kafka 只保证同一分区内有序。如果 Producer 使用 key 分区，增加分区后 key 到分区的映射可能变化。

建议：

- 对强顺序场景提前规划分区数。
- 只要求单 key 有序时，确认分区策略变更影响。
- 对全局有序场景，Kafka 多分区并不适合直接保证。

## Q18：Kafka 可以直接删除数据目录释放空间吗？

不建议。直接删除 `/data/kafka` 下的日志文件可能导致分区数据损坏、Broker 启动失败、副本不一致或数据丢失。

正确方式：

- 调整 Topic 保留策略。
- 删除无用 Topic。
- 扩容磁盘。
- 通过 Kafka 自身日志清理机制释放空间。

## Q19：如何快速判断 Kafka 集群是否健康？

执行：

```bash
kafka-broker-api-versions.sh --bootstrap-server "$BOOTSTRAP"
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --status
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --unavailable-partitions
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --under-replicated-partitions
df -h
```

健康状态：

- Broker API 正常返回。
- KRaft quorum 有 Leader。
- 无 unavailable partitions。
- 无 under-replicated partitions。
- 磁盘空间充足。

## Q20：生产环境最常见的配置误区有哪些？

常见误区：

- `advertised.listeners` 配成 `localhost`。
- 开启 `auto.create.topics.enable` 导致误创建 Topic。
- Topic 副本数为 `1`。
- 三副本场景下 `min.insync.replicas=1`。
- 所有 Topic 使用相同保留策略。
- 不监控 Consumer Lag。
- 不监控 Under Replicated Partitions。
- 直接在 Kafka 中传大文件。
- 没有规划 Topic 分区数，后续被迫频繁扩分区。

## 参考资料

- [Apache Kafka Operations](https://kafka.apache.org/documentation/#operations)
- [Apache Kafka Topic Configs](https://kafka.apache.org/documentation/#topicconfigs)
- [Apache Kafka Producer Configs](https://kafka.apache.org/documentation/#producerconfigs)
- [Apache Kafka Consumer Configs](https://kafka.apache.org/documentation/#consumerconfigs)
- [Apache Kafka Security](https://kafka.apache.org/documentation/#security)
