---
title: Kafka 安装部署
sidebar_position: 1
---

# Kafka 安装部署


## 1.1 安装方式说明

Kafka 新版本已经以 KRaft 模式作为主要部署方式。KRaft 模式不再依赖 ZooKeeper，Kafka 通过内置 Controller Quorum 管理元数据。

常见部署方式：

| 方式 | 说明 | 适用场景 |
| --- | --- | --- |
| 二进制包安装 | 官方 tar 包部署，结构清晰 | 学习、测试、生产手工部署 |
| systemd 托管 | 在二进制安装基础上由 systemd 管理 | 生产常用 |
| Docker / Compose | 容器化快速启动 | 本地测试、演示环境 |
| Kubernetes / Operator | Strimzi 等 Operator 管理 | 云原生环境 |

本文以 **KRaft + 二进制包 + systemd** 为主。

## 1.2 环境准备

建议配置：

- 测试环境：`CPU 2C+`、内存 `4G+`、磁盘 `20G+`。
- 生产环境：至少 `3` 个节点，磁盘独立挂载，内存和磁盘按吞吐量评估。
- Kafka 数据盘建议使用 SSD 或高性能云盘。

软件要求：

- Kafka 运行需要 Java。
- Kafka 4.x 建议使用 Java 17 或更高版本。

安装基础工具：

```bash
# Ubuntu / Debian
apt update
apt install -y openjdk-21-jre wget tar lsof net-tools

# RHEL / Rocky / AlmaLinux
dnf install -y java-21-openjdk wget tar lsof net-tools
```

检查 Java：

```bash
java -version
```

创建用户和目录：

```bash
useradd -r -m -s /bin/bash kafka

mkdir -p /opt/kafka
mkdir -p /data/kafka
mkdir -p /var/log/kafka

chown -R kafka:kafka /opt/kafka /data/kafka /var/log/kafka
```

## 1.3 下载与安装

下载 Kafka：

```bash
cd /opt
wget https://downloads.apache.org/kafka/4.2.0/kafka_2.13-4.2.0.tgz
tar zxf kafka_2.13-4.2.0.tgz
ln -s kafka_2.13-4.2.0 kafka
chown -R kafka:kafka /opt/kafka /opt/kafka_2.13-4.2.0
```

配置环境变量：

```bash
cat > /etc/profile.d/kafka.sh <<'EOF'
export KAFKA_HOME=/opt/kafka
export PATH=$PATH:$KAFKA_HOME/bin
EOF

source /etc/profile.d/kafka.sh
```

检查命令：

```bash
kafka-topics.sh --version
```

说明：

- 版本号应按实际需要选择，生产环境建议统一版本并保留安装包。
- 下载地址可从 [Apache Kafka Downloads](https://kafka.apache.org/downloads) 获取。

## 1.4 单机 KRaft 快速启动

适合学习和功能验证，不适合作为生产部署。

复制配置：

```bash
cp /opt/kafka/config/kraft/server.properties /opt/kafka/config/kraft/server-local.properties
```

编辑：

```bash
vim /opt/kafka/config/kraft/server-local.properties
```

关键配置示例：

```properties
process.roles=broker,controller
node.id=1

controller.quorum.voters=1@localhost:9093

listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://localhost:9092
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT

log.dirs=/data/kafka
num.partitions=3
default.replication.factor=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
```

生成集群 ID：

```bash
KAFKA_CLUSTER_ID="$(kafka-storage.sh random-uuid)"
echo "$KAFKA_CLUSTER_ID"
```

格式化存储目录：

```bash
kafka-storage.sh format \
  -t "$KAFKA_CLUSTER_ID" \
  -c /opt/kafka/config/kraft/server-local.properties
```

启动：

```bash
kafka-server-start.sh /opt/kafka/config/kraft/server-local.properties
```

另开终端验证：

```bash
kafka-topics.sh --bootstrap-server localhost:9092 --create \
  --topic demo --partitions 3 --replication-factor 1

kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## 1.5 systemd 托管

创建服务文件：

```bash
cat > /etc/systemd/system/kafka.service <<'EOF'
[Unit]
Description=Apache Kafka Server
After=network.target

[Service]
Type=simple
User=kafka
Group=kafka
Environment="JAVA_HOME=/usr/lib/jvm/java-21-openjdk"
Environment="KAFKA_HEAP_OPTS=-Xms2g -Xmx2g"
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server-local.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF
```

注意：

- `JAVA_HOME` 路径按实际系统调整。
- 生产环境建议将配置文件命名为 `/opt/kafka/config/kraft/server.properties` 或按节点命名。

启动：

```bash
systemctl daemon-reload
systemctl enable --now kafka
systemctl status kafka
```

查看日志：

```bash
journalctl -u kafka -f
```

## 1.6 三节点 KRaft 集群

示例节点：

| 节点 | IP | node.id | 角色 |
| --- | --- | --- | --- |
| kafka-1 | `10.0.0.11` | `1` | broker,controller |
| kafka-2 | `10.0.0.12` | `2` | broker,controller |
| kafka-3 | `10.0.0.13` | `3` | broker,controller |

三节点小集群可以使用 broker/controller 混合角色。更大规模生产集群可以拆分专用 Controller 节点和 Broker 节点。

### 1.6.1 公共配置

三个节点都需要配置：

```properties
process.roles=broker,controller

controller.quorum.voters=1@10.0.0.11:9093,2@10.0.0.12:9093,3@10.0.0.13:9093

listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT

inter.broker.listener.name=PLAINTEXT

log.dirs=/data/kafka
num.partitions=3
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
```

每个节点不同配置：

```properties
# kafka-1
node.id=1
advertised.listeners=PLAINTEXT://10.0.0.11:9092

# kafka-2
node.id=2
advertised.listeners=PLAINTEXT://10.0.0.12:9092

# kafka-3
node.id=3
advertised.listeners=PLAINTEXT://10.0.0.13:9092
```

### 1.6.2 格式化存储

只生成一次集群 ID，并在所有节点使用同一个 ID：

```bash
KAFKA_CLUSTER_ID="$(kafka-storage.sh random-uuid)"
echo "$KAFKA_CLUSTER_ID"
```

在每个节点执行：

```bash
kafka-storage.sh format \
  -t "$KAFKA_CLUSTER_ID" \
  -c /opt/kafka/config/kraft/server.properties
```

注意：

- 同一集群所有节点必须使用同一个 `KAFKA_CLUSTER_ID`。
- `node.id` 每个节点必须唯一。
- 存储目录格式化后不要随意删除 `meta.properties`。

### 1.6.3 启动与验证

每个节点启动：

```bash
systemctl enable --now kafka
```

查看 Controller Quorum：

```bash
kafka-metadata-quorum.sh --bootstrap-server 10.0.0.11:9092 describe
```

创建测试 Topic：

```bash
kafka-topics.sh --bootstrap-server 10.0.0.11:9092 \
  --create --topic demo \
  --partitions 3 \
  --replication-factor 3
```

查看 Topic：

```bash
kafka-topics.sh --bootstrap-server 10.0.0.11:9092 \
  --describe --topic demo
```

## 1.7 生产关键配置

常见配置：

```properties
# Kafka 日志数据目录，保存 Topic 分区日志和本地元数据。
# 生产环境建议挂载独立数据盘，不要和系统盘混用。
log.dirs=/data/kafka

# 自动创建 Topic 或未显式指定分区数时使用的默认分区数。
# 分区数影响并发能力和文件句柄数量，不能减少，只能增加。
num.partitions=6

# 自动创建 Topic 或未显式指定副本数时使用的默认副本数。
# 三节点生产集群通常设置为 3，提高 broker 故障容忍能力。
default.replication.factor=3

# 写入成功所需的最小同步副本数。
# 配合 producer 的 acks=all 使用，可避免只有 1 个副本确认导致数据可靠性不足。
# 三副本场景通常设置为 2。
min.insync.replicas=2

# 是否允许删除 Topic。
# 生产环境可以开启，但应通过权限和流程控制删除操作。
delete.topic.enable=true

# 消息保留时间，单位小时。
# 超过该时间的日志段会被清理，实际清理还受 segment 滚动和清理周期影响。
log.retention.hours=168

# 单个日志段文件大小，达到该大小后滚动新 segment。
# segment 越小，过期数据清理越及时；segment 越大，文件数量更少。
log.segment.bytes=1073741824

# 是否允许客户端写入不存在的 Topic 时自动创建。
# 生产建议关闭，避免应用拼错 Topic 名导致误创建。
auto.create.topics.enable=false
```

建议：

- 生产关闭 `auto.create.topics.enable`，避免误写 Topic。
- `default.replication.factor` 建议为 `3`。
- `min.insync.replicas` 建议为 `2`。
- Topic 分区数需要结合吞吐量、消费者并发和扩容策略规划。

## 1.8 防火墙与端口

常见端口：

| 端口 | 用途 |
| --- | --- |
| `9092` | Broker 客户端访问 |
| `9093` | Controller Quorum |
| `9999` | JMX 监控，可选 |

放行端口：

```bash
firewall-cmd --permanent --add-port=9092/tcp
firewall-cmd --permanent --add-port=9093/tcp
firewall-cmd --reload
```

云服务器还需要检查安全组。

## 1.9 Docker Compose 示例

适合本地测试。

```yaml title="docker-compose.yml"
services:
  kafka:
    image: apache/kafka:4.2.0
    container_name: kafka
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
```

启动：

```bash
docker compose up -d
docker logs -f kafka
```

## 1.10 常见问题

### 1.10.1 advertised.listeners 配置错误

现象：

- 本机能连接，其他机器连不上。
- 客户端报 broker not available。
- 客户端拿到 `localhost:9092` 后无法访问。

处理：

- `advertised.listeners` 必须配置为客户端可访问的地址。
- 容器、内网、外网访问场景需要分别规划监听地址。

### 1.10.2 cluster.id 不一致

现象：

- 节点启动失败。
- 日志提示 cluster id mismatch。

处理：

- 同一集群所有节点使用同一个 cluster id 格式化。
- 不要把其他集群的数据目录直接挂到当前节点。

### 1.10.3 node.id 冲突

现象：

- Controller Quorum 异常。
- Broker 启动失败或频繁退出。

处理：

- 每个 Kafka 节点 `node.id` 必须唯一。
- `controller.quorum.voters` 中的 ID 必须和对应节点 `node.id` 匹配。

### 1.10.4 Topic 副本创建失败

常见原因：

- Broker 数量少于 `replication-factor`。
- 集群节点未全部启动。
- Controller Quorum 异常。

排查：

```bash
kafka-broker-api-versions.sh --bootstrap-server localhost:9092
kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe
```

## 1.11 参考资料

- [Apache Kafka Quickstart](https://kafka.apache.org/quickstart)
- [Apache Kafka KRaft Documentation](https://kafka.apache.org/documentation/#kraft)
- [Apache Kafka Downloads](https://kafka.apache.org/downloads)
- [Apache Kafka Docker Image](https://hub.docker.com/r/apache/kafka)
