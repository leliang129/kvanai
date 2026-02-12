---
title: Kafka 命令速查
sidebar_position: 2
---

# Kafka 常用命令速查

以下命令以官方 `kafka-*` 脚本为例（KRaft 或 ZK 模式均可用）。请先确认 `KAFKA_HOME` 或 `PATH` 中包含 Kafka 的 `bin/`。

## 基础信息

```bash
# 查看版本
kafka-topics.sh --version

# 查看集群信息（KRaft）
kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe
```

## Topic 管理

```bash
# 列出所有 Topic
kafka-topics.sh --bootstrap-server localhost:9092 --list

# 创建 Topic
kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic demo \
  --partitions 3 --replication-factor 1

# 查看 Topic 详情
kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe --topic demo

# 修改分区数（只能增加）
kafka-topics.sh --bootstrap-server localhost:9092 \
  --alter --topic demo --partitions 6

# 删除 Topic（需 broker 开启 delete.topic.enable=true）
kafka-topics.sh --bootstrap-server localhost:9092 \
  --delete --topic demo
```

## Producer / Consumer

```bash
# 生产消息（交互式）
kafka-console-producer.sh --bootstrap-server localhost:9092 \
  --topic demo

# 消费消息（从最新）
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic demo --from-beginning
```

## Consumer Group

```bash
# 列出所有 consumer group
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list

# 查看 group 详情（lag 等）
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group demo-group

# 重置 offset 到最早（示例）
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group demo-group --reset-offsets --to-earliest \
  --execute --topic demo
```

## ACL / 权限

```bash
# 查看 ACL
kafka-acls.sh --bootstrap-server localhost:9092 --list

# 添加 ACL（示例：允许用户写入 demo）
kafka-acls.sh --bootstrap-server localhost:9092 \
  --add --allow-principal User:app \
  --operation Write --topic demo
```

## Broker / 配置

```bash
# 查看 broker 配置
kafka-configs.sh --bootstrap-server localhost:9092 \
  --entity-type brokers --entity-name 0 --describe

# 修改 topic 配置（示例：保留 7 天）
kafka-configs.sh --bootstrap-server localhost:9092 \
  --entity-type topics --entity-name demo \
  --alter --add-config retention.ms=604800000
```

## 分区副本迁移

```bash
# 生成迁移计划（示例）
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --generate --topics-to-move-json-file topics.json \
  --broker-list "0,1,2"

# 执行迁移
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --execute --reassignment-json-file reassignment.json

# 查看迁移状态
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --verify --reassignment-json-file reassignment.json
```

## 常用诊断

```bash
# 查看 topic 的 offset 及 lag
topic=demo
group=demo-group
kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 --topic "$topic"

kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group "$group" --members
```

> 说明：部分命令在不同 Kafka 版本脚本名略有差异，请以安装版本为准。
