---
title: Kafka 命令速查
sidebar_position: 3
---

# Kafka 常用命令速查

以下命令以官方 `kafka-*` 脚本为例（KRaft 或 ZK 模式均可用）。请先确认 `KAFKA_HOME` 或 `PATH` 中包含 Kafka 的 `bin/`。

建议先定义常用变量：

```bash
export BOOTSTRAP="localhost:9092"
export TOPIC="demo"
export GROUP="demo-group"
```

## 基础信息

```bash
# 查看版本
kafka-topics.sh --version

# 查看集群信息（KRaft）
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe

# 查看 broker API 版本
kafka-broker-api-versions.sh --bootstrap-server "$BOOTSTRAP"

# 查看 KRaft quorum 状态
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --status

# 查看 KRaft quorum 副本信息
kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --replication
```

## Topic 管理

```bash
# 列出所有 Topic
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --list

# 创建 Topic
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --create --topic "$TOPIC" \
  --partitions 3 --replication-factor 3

# 查看 Topic 详情
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --topic "$TOPIC"

# 查看所有 Topic 详情
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe

# 修改分区数（只能增加）
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --alter --topic "$TOPIC" --partitions 6

# 删除 Topic（需 broker 开启 delete.topic.enable=true）
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --delete --topic "$TOPIC"

# 查看 Topic 覆盖配置
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics --entity-name "$TOPIC" --describe

# 设置 Topic 保留时间为 7 天
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics --entity-name "$TOPIC" \
  --alter --add-config retention.ms=604800000

# 设置 Topic 保留大小为 10GB
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics --entity-name "$TOPIC" \
  --alter --add-config retention.bytes=10737418240

# 删除 Topic 覆盖配置，恢复 broker 默认值
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics --entity-name "$TOPIC" \
  --alter --delete-config retention.ms
```

## Producer / Consumer

```bash
# 生产消息（交互式）
kafka-console-producer.sh --bootstrap-server "$BOOTSTRAP" \
  --topic "$TOPIC"

# 消费消息（从头开始）
kafka-console-consumer.sh --bootstrap-server "$BOOTSTRAP" \
  --topic "$TOPIC" --from-beginning

# 指定 consumer group 消费
kafka-console-consumer.sh --bootstrap-server "$BOOTSTRAP" \
  --topic "$TOPIC" --group "$GROUP"

# 只消费 10 条消息后退出
kafka-console-consumer.sh --bootstrap-server "$BOOTSTRAP" \
  --topic "$TOPIC" --from-beginning --max-messages 10

# 打印 key、value、offset、partition、timestamp
kafka-console-consumer.sh --bootstrap-server "$BOOTSTRAP" \
  --topic "$TOPIC" --from-beginning --max-messages 10 \
  --property print.key=true \
  --property print.value=true \
  --property print.offset=true \
  --property print.partition=true \
  --property print.timestamp=true

# 生产带 key 的消息
kafka-console-producer.sh --bootstrap-server "$BOOTSTRAP" \
  --topic "$TOPIC" \
  --property parse.key=true \
  --property key.separator=:
```

## Consumer Group

```bash
# 列出所有 consumer group
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" --list

# 查看 group 详情（lag 等）
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP"

# 查看 group 成员
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP" --members

# 查看 group 状态
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP" --state

# 预览：重置 offset 到最早
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" --reset-offsets --to-earliest \
  --dry-run --topic "$TOPIC"

# 执行：重置 offset 到最早
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" --reset-offsets --to-earliest \
  --execute --topic "$TOPIC"

# 重置 offset 到最新
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" --reset-offsets --to-latest \
  --execute --topic "$TOPIC"

# 重置 offset 到指定时间
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" --reset-offsets \
  --to-datetime 2026-05-06T10:00:00.000 \
  --execute --topic "$TOPIC"

# 按分区重置 offset
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" --reset-offsets \
  --to-offset 100 \
  --execute --topic "$TOPIC:0"

# 删除 consumer group
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --delete --group "$GROUP"
```

## 消费积压处理

```bash
# 查看指定消费组积压
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP"

# 只查看指定 Topic 的积压
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP" \
  | awk -v topic="$TOPIC" '$1 == topic || NR == 1'

# 按 Lag 倒序查看积压分区
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP" \
  | awk 'NR == 1 || $6 ~ /^[0-9]+$/ {print}' \
  | sort -k6 -nr

# 查看消费组成员和分区分配，判断是否有消费者实例不足或分配不均
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP" --members --verbose

# 查看消费组状态，确认是否频繁 rebalancing
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP" --state

# 查看 Topic 分区最新 offset
kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list "$BOOTSTRAP" \
  --topic "$TOPIC" --time -1

# 查看 Topic 分区最早 offset
kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list "$BOOTSTRAP" \
  --topic "$TOPIC" --time -2

# 临时新建消费组验证是否能正常消费消息
kafka-console-consumer.sh --bootstrap-server "$BOOTSTRAP" \
  --topic "$TOPIC" \
  --group "debug-${GROUP}-$(date +%s)" \
  --from-beginning \
  --max-messages 10 \
  --property print.offset=true \
  --property print.partition=true \
  --property print.timestamp=true

# 预览：将消费组 offset 重置到指定时间
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" \
  --reset-offsets --to-datetime 2026-05-06T10:00:00.000 \
  --dry-run --topic "$TOPIC"

# 执行：将消费组 offset 重置到指定时间
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" \
  --reset-offsets --to-datetime 2026-05-06T10:00:00.000 \
  --execute --topic "$TOPIC"

# 预览：跳过积压，直接重置到最新 offset
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" \
  --reset-offsets --to-latest \
  --dry-run --topic "$TOPIC"

# 执行：跳过积压，直接重置到最新 offset
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" \
  --reset-offsets --to-latest \
  --execute --topic "$TOPIC"

# 对指定分区重置 offset，适合只有个别分区异常积压的场景
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --group "$GROUP" \
  --reset-offsets --to-offset 123456 \
  --execute --topic "$TOPIC:0"

# 增加 Topic 分区数，提高后续最大消费并发（只能增加，不能减少）
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --alter --topic "$TOPIC" --partitions 12
```

注意：

- 处理积压前先判断是消费者停止、下游变慢、分区热点，还是消费能力不足。
- 重置 offset 可能导致重复消费或跳过消息，执行前必须先 `--dry-run`，关键业务需要业务方确认。
- 增加消费者实例的有效并发不超过 Topic 分区数。
- 增加分区可能影响 key 到分区的映射，强顺序业务要谨慎。

## ACL / 权限

```bash
# 查看 ACL
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" --list

# 添加 ACL（示例：允许用户写入 demo）
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" \
  --add --allow-principal User:app \
  --operation Write --topic "$TOPIC"

# 添加 ACL（示例：允许用户读取 demo，并使用 group）
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" \
  --add --allow-principal User:app \
  --operation Read --topic "$TOPIC" \
  --operation Read --group "$GROUP"

# 删除 ACL
kafka-acls.sh --bootstrap-server "$BOOTSTRAP" \
  --remove --allow-principal User:app \
  --operation Write --topic "$TOPIC"
```

## Broker / 配置

```bash
# 查看 broker 配置
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type brokers --entity-name 0 --describe

# 查看所有动态 broker 配置
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type brokers --all --describe

# 修改 broker 动态配置（示例：限制 broker 0 出站复制带宽）
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type brokers --entity-name 0 \
  --alter --add-config follower.replication.throttled.rate=10485760

# 删除 broker 动态配置
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type brokers --entity-name 0 \
  --alter --delete-config follower.replication.throttled.rate

# 修改 topic 配置（示例：保留 7 天）
kafka-configs.sh --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics --entity-name "$TOPIC" \
  --alter --add-config retention.ms=604800000
```

## 分区副本迁移

```bash
# topics.json 示例：
# {"topics":[{"topic":"demo"}],"version":1}

# 生成迁移计划
kafka-reassign-partitions.sh --bootstrap-server "$BOOTSTRAP" \
  --generate --topics-to-move-json-file topics.json \
  --broker-list "0,1,2"

# 执行迁移
kafka-reassign-partitions.sh --bootstrap-server "$BOOTSTRAP" \
  --execute --reassignment-json-file reassignment.json

# 查看迁移状态
kafka-reassign-partitions.sh --bootstrap-server "$BOOTSTRAP" \
  --verify --reassignment-json-file reassignment.json

# 取消迁移
kafka-reassign-partitions.sh --bootstrap-server "$BOOTSTRAP" \
  --cancel --reassignment-json-file reassignment.json
```

## 分区首领与副本状态

```bash
# 查看 under-replicated partitions
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --under-replicated-partitions

# 查看 unavailable partitions
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --unavailable-partitions

# 执行 preferred leader election
kafka-leader-election.sh --bootstrap-server "$BOOTSTRAP" \
  --election-type preferred --all-topic-partitions

# 对指定分区执行 preferred leader election
kafka-leader-election.sh --bootstrap-server "$BOOTSTRAP" \
  --election-type preferred \
  --topic "$TOPIC" --partition 0
```

## 性能测试

```bash
# Producer 压测
kafka-producer-perf-test.sh \
  --topic "$TOPIC" \
  --num-records 1000000 \
  --record-size 1024 \
  --throughput -1 \
  --producer-props bootstrap.servers="$BOOTSTRAP" acks=all

# Consumer 压测
kafka-consumer-perf-test.sh \
  --bootstrap-server "$BOOTSTRAP" \
  --topic "$TOPIC" \
  --messages 1000000 \
  --threads 1
```

## 常用诊断

```bash
# 查看 topic 的 offset 及 lag
kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list "$BOOTSTRAP" --topic "$TOPIC"

kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list "$BOOTSTRAP" --topic "$TOPIC" --time -1

kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list "$BOOTSTRAP" --topic "$TOPIC" --time -2

# 查看 consumer group lag
kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --group "$GROUP"

# 查看本地日志目录大小
du -sh /data/kafka/*

# 查看 Kafka 进程
jps -l
ps aux | grep kafka

# 查看端口
ss -lntp | grep -E '9092|9093'

# 查看 systemd 日志
journalctl -u kafka -n 200 --no-pager
```

## 常用配置文件参数

```bash
# 查看 server.properties 中关键配置
grep -E '^(process.roles|node.id|controller.quorum.voters|listeners|advertised.listeners|log.dirs|num.partitions|default.replication.factor|min.insync.replicas)' \
  /opt/kafka/config/kraft/server.properties

# 查看存储目录元数据
cat /data/kafka/meta.properties
```

> 说明：部分命令在不同 Kafka 版本脚本名略有差异，请以安装版本为准。执行 offset 重置、Topic 删除、分区迁移、ACL 删除等操作前，建议先在测试环境验证，并优先使用 `--dry-run` 预览影响范围。
