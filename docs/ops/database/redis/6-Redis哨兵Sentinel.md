---
title: Redis 哨兵 Sentinel
sidebar_position: 6
---

# 3.2 Redis 哨兵 Sentinel

本节对应 PDF 第 3 章中 **3.2 Redis 哨兵 Sentinel** 的内容，主要介绍：

- Sentinel 解决的痛点与整体架构；
- 关键的故障检测与投票机制；
- 搭建一主多从的 Sentinel 高可用集群；
- 故障转移过程的日志分析与配置自动改写；
- 客户端接入方式与实践建议。

---

## 3.2.1 Sentinel 解决的问题

在只有主从复制的架构中仍存在两个突出问题：

1. **主从角色无法自动切换**：
   - master 宕机后，需要人工选择 slave、手动执行 `REPLICAOF NO ONE` 等操作；
   - 期间应用需要改配置或改负载均衡，存在较长不可用窗口。

2. **单 master 写入瓶颈仍然存在**：
   - Sentinel 本身不解决容量与写性能问题，仅聚焦于高可用和角色切换。

Sentinel 的目标是：

- 监控 master 和 slave 的存活状态；
- 在判断 master 失败后，自动将某个 slave 提升为新的 master；
- 通知其他 slave 改为复制新的 master；
- 为客户端提供“逻辑主节点名称”，使应用在主从切换时无需硬编码 IP。

---

## 3.2.2 Sentinel 架构与故障检测

### 3.2.2.1 架构角色

在 Sentinel 模式中，通常有三类角色：

- **主节点（master）**：对外提供写服务，并将数据同步到从节点；
- **从节点（slave/replica）**：从主节点复制数据，对外提供只读服务；
- **Sentinel 进程**：独立于 Redis server 的监控进程。

Sentinel 本身也是一个 Redis 进程，以特殊模式运行。生产中通常部署 **至少 3 个 Sentinel 实例**，构成一个哨兵集群：

- 每个 Sentinel 会定期与 master、slave、其他 Sentinel 通信；
- Sentinel 之间通过投票来决定是否执行故障转移以及由谁来执行。

### 3.2.2.2 主观下线与客观下线

Sentinel 使用两级判断机制：

1. **主观下线（SDOWN, Subjective Down）**：
   - 某个 Sentinel 认为在一定时间内无法与 master 通信；
   - 仅代表“自己认为” master 出问题了。

2. **客观下线（ODOWN, Objectively Down）**：
   - 多数 Sentinel 进程通过 `is-master-down-by-addr` 命令互相确认；
   - 当认为 master 下线的 Sentinel 数量达到配置的 `quorum` 时，才进入 ODOWN 状态；
   - 只有在 ODOWN 下，才会触发自动故障转移流程。

这种设计可以避免因为个别 Sentinel 网络抖动造成的误判。

### 3.2.2.3 Sentinel 的三个周期性任务

根据 PDF 中的描述，Sentinel 内部默认运行三个关键的定时任务：

1. **每 10 秒 对 master 和 slave 执行 `INFO`**：
   - 发现新的从节点；
   - 确认主从拓扑关系是否有变化。

2. **每 2 秒 通过 master 的 Pub/Sub 频道交换 Sentinel 信息**：
   - 使用 `__sentinel__:hello` 频道广播自身状态和对集群的“看法”；
   - 用于让其他 Sentinel 感知到新的 Sentinel 和配置变更。

3. **每 1 秒 对所有 Redis 节点和其他 Sentinel 执行 `PING`**：
   - 用于快速检测连接是否正常；
   - 为 SDOWN/ODOWN 判断提供基础数据。

---

## 3.2.3 搭建基于 Sentinel 的高可用集群

以下以“一主两从 + 三个 Sentinel”为例说明部署步骤。前提是已经基于上一节完成了 Redis 主从复制。

### 3.2.3.1 统一主从节点的认证配置

PDF 中强调：

- master 和所有 slave 节点的 `masterauth` 与 `requirepass` 必须保持一致；
- 这既是复制通信的密码，也是将来某个 slave 被提升为 master 后的访问密码。

统一后的 `redis.conf` 示例如下：

```conf
requirepass 123456
masterauth 123456
```

### 3.2.3.2 编写 Sentinel 配置文件

以监控名称为 `mymaster` 的集群为例，一个最小可用的 `redis-sentinel.conf` 如下：

```conf
port 26379
daemonize no
logfile "/var/log/redis/sentinel.log"
dir "/tmp"

# 监控名为 mymaster 的主节点，IP 为 10.0.0.8，端口 6379，至少 2 个 Sentinel
# 一致认为其下线才会执行故障转移
sentinel monitor mymaster 10.0.0.8 6379 2

# 主节点认证信息
sentinel auth-pass mymaster 123456

# 判定主节点下线的超时时间（毫秒）
sentinel down-after-milliseconds mymaster 3000

# 故障转移时，并发向多少个 slave 发送同步新主节点的复制指令
sentinel parallel-syncs mymaster 1

# 一次故障转移的超时时间（毫秒）
sentinel failover-timeout mymaster 180000
```

每个 Sentinel 实例都需要一份配置文件，通常只在 `port`、`logfile` 等本地属性上有所差异。

### 3.2.3.3 启动多个 Sentinel 实例

可以直接用命令行启动：

```bash
redis-sentinel /etc/redis-sentinel.conf
```

生产环境中更常见的是使用 systemd：

```ini
[Unit]
Description=Redis Sentinel
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/redis-sentinel /etc/redis-sentinel.conf
Restart=always

[Install]
WantedBy=multi-user.target
```

三台不同的服务器上分别运行一个 Sentinel，即可组成一个基本的哨兵集群。

---

## 3.2.4 验证 Sentinel 状态

### 3.2.4.1 监听端口

在 Sentinel 服务器上检查 26379 端口是否监听：

```bash
ss -ntl | grep 26379
```

### 3.2.4.2 使用 INFO sentinel 查看状态

通过 `redis-cli` 连接到 Sentinel：

```bash
redis-cli -p 26379 INFO sentinel
```

关键字段说明：

- `sentinel_masters`：当前监控的 master 数量；
- `master0:name=mymaster,status=ok,address=...,slaves=2,sentinels=3`：
  - 逻辑名为 `mymaster` 的 master 状态为 `ok`；
  - 有 2 个 slave、3 个 Sentinel 正在监控。

如果 `sentinels` 显示数量不正确，通常是某些 Sentinel 的 `myid` 冲突或者配置错误，需要排查日志。

---

## 3.2.5 故障转移过程分析

### 3.2.5.1 触发故障转移

当 master 宕机（例如停止其 Redis 服务）时，Sentinel 日志会依次出现类似事件：

- `+sdown master ...`：某 Sentinel 主观认为 master 下线；
- `+odown master ... quorum 2/2`：达到法定票数，进入客观下线；
- `+try-failover` / `+elected-leader`：选出负责执行故障转移的 Sentinel；
- `+failover-state-select-slave`：选择合适的 slave 作为候选新主节点。

### 3.2.5.2 提升从节点为新主节点

接下来日志中会看到：

- `+selected-slave`：选中了某个 slave；
- `+failover-state-send-slaveof-noone`：向该 slave 发送 `SLAVEOF NO ONE`；
- `+promoted-slave`：slave 成功晋升为新的 master。

在新 master 上使用 `INFO replication`，可以看到：

- `role: master`；
- `connected_slaves` 中包含其他节点作为从节点；
- `master_replid` 等复制 ID 发生了变化。

### 3.2.5.3 其他从节点重新指向新主节点

原来的其他 slave 会被重新配置为复制新的 master：

- Sentinel 日志中可以看到 `slave-reconf-sent`、`slave-reconf-inprog`、`slave-reconf-done` 等状态；
- 故障转移结束时会出现 `+failover-end` 与 `+switch-master` 事件。

### 3.2.5.4 配置文件自动改写

故障转移完成后：

1. 每个 slave 的 `redis.conf` 中 `replicaof` 行会被自动改为指向新的 master IP 和端口；
2. 每个 Sentinel 的配置文件中：
   - `sentinel monitor mymaster <ip> 6379 2` 行会自动改为新的 master 地址；
   - `sentinel known-replica` 等字段也会更新，记录新的主从拓扑；
3. 这些改写都是由 Sentinel 自动完成，无需人工干预。

---

## 3.2.6 客户端接入 Sentinel 的方式

在 Sentinel 模式下，**客户端连接的是 Sentinel 集群，而不是固定的 Redis IP**：

1. 在客户端配置若干个 Sentinel 地址；
2. 向 Sentinel 查询指定逻辑名（如 `mymaster`）的当前 master 地址；
3. 建立到 master 的连接执行写操作；
4. 当 Sentinel 发生故障转移时，客户端通过再次查询即可获得新的 master 地址。

很多语言的 Redis 客户端已经内置了 Sentinel 支持，例如：

- Java：Jedis / Lettuce 的 Sentinel 模式；
- Python：redis-py 的 `Sentinel` 封装；
- 其他语言也大多提供类似能力。

---

## 3.2.7 Sentinel 使用建议

结合 PDF 内容与实践经验，有以下建议：

1. **Sentinel 数量**：部署不少于 3 个 Sentinel，并尽量分布在不同物理机或可用区，避免单点故障。

2. **部署位置**：
   - Sentinel 进程负载较小，可以与 Redis 共机或单独部署；
   - 为避免资源竞争，强业务场景可以考虑与 Redis 进程分开。

3. **参数调优**：
   - `down-after-milliseconds` 不宜设置得过小，防止短暂网络抖动触发频繁切换；
   - `quorum` 和 Sentinel 总数需综合考虑，确保多数票能够覆盖网络分区场景。

4. **监控与报警**：
   - 接入日志与监控系统，关注 `+sdown`、`+odown`、`+failover-*` 等事件；
   - 为 Sentinel 自身的进程存活、端口连通性设置告警。

5. **与 Cluster 的关系**：
   - Sentinel 主要解决“一个 master + 多个 slave” 架构的高可用问题；
   - 如果需要水平扩展容量与写性能，应优先考虑 Redis Cluster 方案，而不是在大规模场景中堆叠大量 Sentinel+主从集群。

---

通过 Sentinel，可以在主从复制的基础上构建出自动故障转移的 Redis 高可用集群，大幅降低运维干预的频率。

