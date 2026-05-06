---
title: Prometheus 常用 Exporter
sidebar_position: 8
---

# Prometheus 常用 Exporter


## 8.1 Exporter 说明

Exporter 用于把系统、数据库、中间件或应用的指标转换为 Prometheus 可抓取的 `/metrics` 格式。

常见类型：

| 类型 | Exporter |
| --- | --- |
| 主机 | Node Exporter |
| 容器 | cAdvisor |
| 黑盒探测 | Blackbox Exporter |
| MySQL | mysqld_exporter |
| Redis | redis_exporter |
| PostgreSQL | postgres_exporter |
| Kafka | kafka_exporter、JMX Exporter |
| Nginx | nginx-prometheus-exporter |

## 8.2 Node Exporter

用于采集主机 CPU、内存、磁盘、网络等指标。

启动：

```bash
node_exporter --web.listen-address=:9100  # 启动 Node Exporter
```

Prometheus 配置：

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: node  # 采集 Node Exporter 指标
    static_configs:  # 使用静态目标配置
      - targets:  # 采集目标列表
          - 10.0.0.11:9100  # Node Exporter 地址
```

常用指标：

| 指标 | 说明 |
| --- | --- |
| `node_cpu_seconds_total` | CPU 时间 |
| `node_memory_MemAvailable_bytes` | 可用内存 |
| `node_filesystem_avail_bytes` | 文件系统可用空间 |
| `node_network_receive_bytes_total` | 网络接收字节 |
| `node_disk_read_bytes_total` | 磁盘读字节 |

## 8.3 cAdvisor

用于采集容器 CPU、内存、网络、文件系统指标。

Docker 启动：

```bash
# 启动 cAdvisor 容器，采集 Docker 容器指标
docker run -d \
  --name cadvisor \
  --restart unless-stopped \
  -p 8080:8080 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  gcr.io/cadvisor/cadvisor:v0.52.1
```

Prometheus 配置：

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: cadvisor  # 采集 cAdvisor 容器指标
    static_configs:  # 使用静态目标配置
      - targets:  # 采集目标列表
          - 10.0.0.11:8080  # cAdvisor metrics 地址
```

## 8.4 Blackbox Exporter

用于 HTTP、TCP、ICMP 探测。

启动：

```bash
blackbox_exporter --config.file=/etc/blackbox_exporter/config.yml  # 启动 Blackbox Exporter
```

配置示例：

```yaml title="blackbox.yml"
modules:  # Blackbox 探测模块列表
  http_2xx:  # HTTP 2xx 探测模块名称
    prober: http  # 使用 HTTP 探测器
    timeout: 5s  # 单次探测超时时间
    http:  # HTTP 探测参数
      valid_status_codes: []  # 空列表表示默认接受 2xx 状态码

  tcp_connect:  # TCP 连接探测模块名称
    prober: tcp  # 使用 TCP 探测器
    timeout: 5s  # 单次探测超时时间

  icmp:  # ICMP 探测模块名称
    prober: icmp  # 使用 ICMP 探测器
    timeout: 5s  # 单次探测超时时间
```

Prometheus 配置：

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: blackbox-http  # HTTP 黑盒探测任务名称
    metrics_path: /probe  # Blackbox Exporter 探测入口
    params:  # 传给 Blackbox Exporter 的参数
      module: [http_2xx]  # 使用 http_2xx 模块
    static_configs:  # 使用静态目标配置
      - targets:  # 需要探测的真实业务地址
          - https://example.com  # HTTP 探测目标
    relabel_configs:  # 采集前改写 target 标签
      - source_labels: [__address__]  # 读取原始目标地址
        target_label: __param_target  # 写入 target 查询参数
      - source_labels: [__param_target]  # 读取真实探测目标
        target_label: instance  # 将真实目标展示为 instance
      - target_label: __address__  # 改写实际抓取地址
        replacement: 10.0.0.10:9115  # 指向 Blackbox Exporter 地址
```

常用指标：

| 指标 | 说明 |
| --- | --- |
| `probe_success` | 探测是否成功 |
| `probe_duration_seconds` | 探测耗时 |
| `probe_http_status_code` | HTTP 状态码 |

## 8.5 MySQL Exporter

Docker 启动：

```bash
# 启动 MySQL Exporter 容器，采集 MySQL 指标
docker run -d \
  --name mysqld-exporter \
  --restart unless-stopped \
  -p 9104:9104 \
  -e DATA_SOURCE_NAME='exporter:password@(mysql.example.com:3306)/' \
  prom/mysqld-exporter:v0.17.2
```

MySQL 授权示例：

```sql
CREATE USER 'exporter'@'%' IDENTIFIED BY 'password';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
FLUSH PRIVILEGES;
```

Prometheus 配置：

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: mysql  # 采集 MySQL Exporter 指标
    static_configs:  # 使用静态目标配置
      - targets:  # 采集目标列表
          - 10.0.0.20:9104  # MySQL Exporter 地址
```

## 8.6 Redis Exporter

Docker 启动：

```bash
# 启动 Redis Exporter 容器，采集 Redis 指标
docker run -d \
  --name redis-exporter \
  --restart unless-stopped \
  -p 9121:9121 \
  oliver006/redis_exporter:v1.80.1 \
  --redis.addr=redis://redis.example.com:6379
```

带密码：

```bash
# 启动 Redis Exporter 容器，并配置 Redis 访问密码
docker run -d \
  --name redis-exporter \
  --restart unless-stopped \
  -p 9121:9121 \
  oliver006/redis_exporter:v1.80.1 \
  --redis.addr=redis://redis.example.com:6379 \
  --redis.password='password'
```

Prometheus 配置：

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: redis  # 采集 Redis Exporter 指标
    static_configs:  # 使用静态目标配置
      - targets:  # 采集目标列表
          - 10.0.0.21:9121  # Redis Exporter 地址
```

## 8.7 Kafka Exporter

Docker 启动：

```bash
# 启动 Kafka Exporter 容器，采集 Kafka Topic 和消费组指标
docker run -d \
  --name kafka-exporter \
  --restart unless-stopped \
  -p 9308:9308 \
  danielqsj/kafka-exporter \
  --kafka.server=10.0.0.11:9092 \
  --kafka.server=10.0.0.12:9092 \
  --kafka.server=10.0.0.13:9092
```

Prometheus 配置：

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: kafka-exporter  # 采集 Kafka Exporter 指标
    static_configs:  # 使用静态目标配置
      - targets:  # 采集目标列表
          - 10.0.0.30:9308  # Kafka Exporter 地址
```

常用指标：

| 指标 | 说明 |
| --- | --- |
| `kafka_consumergroup_lag` | 消费组 Lag |
| `kafka_topic_partitions` | Topic 分区数 |
| `kafka_brokers` | Broker 数量 |

## 8.8 JMX Exporter

JMX Exporter 常用于 Java 应用、中间件、Kafka、ZooKeeper 等。

Java Agent 方式：

```bash
java -javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9404:/opt/jmx-exporter/config.yml -jar app.jar  # 以 Java Agent 方式暴露应用 JMX 指标
```

Kafka 示例：

```bash
export KAFKA_OPTS="$KAFKA_OPTS -javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9404:/opt/jmx-exporter/kafka.yml"  # 给 Kafka JVM 增加 JMX Exporter Agent 参数
```

Prometheus 配置：

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: kafka-jmx  # 采集 Kafka JMX 指标
    static_configs:  # 使用静态目标配置
      - targets:  # 采集目标列表
          - 10.0.0.11:9404  # JMX Exporter 地址
```

## 8.9 Exporter 管理建议

建议：

- Exporter 端口统一规划。
- Exporter 使用独立低权限账号。
- 对敏感 Exporter 限制访问来源。
- 数据库 Exporter 使用只读低权限账号。
- Exporter 版本固定，不使用浮动 latest。
- 高基数指标要提前评估。

常见端口：

| Exporter | 端口 |
| --- | --- |
| Node Exporter | `9100` |
| mysqld_exporter | `9104` |
| redis_exporter | `9121` |
| blackbox_exporter | `9115` |
| kafka_exporter | `9308` |
| JMX Exporter | 常用 `9404` |

## 8.10 常见问题

### 8.10.1 Exporter up 但指标不完整

原因：

- 权限不足。
- Collector 未开启。
- 目标服务版本不兼容。
- 配置参数缺失。

### 8.10.2 Exporter 无法连接目标服务

排查：

```bash
curl http://exporter-host:port/metrics  # 检查 Exporter 指标
telnet target-host target-port  # 检查到目标服务网络
```

### 8.10.3 指标基数过高

处理：

- 删除高基数标签。
- 关闭不必要 collector。
- 使用 `metric_relabel_configs` 临时丢弃。
- 从应用或 Exporter 源头治理。

## 8.11 参考资料

- [Prometheus Exporters](https://prometheus.io/docs/instrumenting/exporters/)
- [Node Exporter](https://github.com/prometheus/node_exporter)
- [Blackbox Exporter](https://github.com/prometheus/blackbox_exporter)
- [JMX Exporter](https://github.com/prometheus/jmx_exporter)
- [mysqld_exporter](https://github.com/prometheus/mysqld_exporter)
