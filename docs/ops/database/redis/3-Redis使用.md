---
title: Redis 使用
sidebar_position: 3
---

# 3 Redis 使用

本节对应 PDF 中的“**Redis 使用 / Redis 基础功能**”部分，
聚焦于 Redis 的日常使用方式，包括：

- 常用基础命令；
- 配置查询与在线调整；
- 内存与性能相关设置；
- 慢查询排查和 Pipeline 使用思路。

数据类型的详细命令将单独在《Redis 数据类型》一节中展开。

---

## 3.1 常用基础命令

### 3.1.1 PING / ECHO

用于测试连接是否正常：

```bash
redis-cli ping
# 返回：PONG

redis-cli echo "hello redis"
# 返回："hello redis"
```

### 3.1.2 SELECT / DBSIZE / FLUSHDB / FLUSHALL

Redis 默认有多个逻辑数据库（DB 0~15），可以通过 `SELECT` 切换：

```bash
SELECT 0
SELECT 1
```

查看当前数据库中键的数量：

```bash
DBSIZE
```

清空操作（慎用）：

```bash
# 清空当前数据库
FLUSHDB

# 清空所有数据库（生产环境极度危险）
FLUSHALL
```

PDF 强调，在生产环境中建议通过配置 `rename-command` 禁用或
隐藏类似 `FLUSHALL` 的危险命令，例如：

```conf
rename-command FLUSHALL ""
```

> 提示：一旦禁用命令，后续就无法再通过同名命令调用；需谨慎设计
> 运维流程，避免误操作。

### 3.1.3 SHUTDOWN

关闭 Redis 服务器：

```bash
SHUTDOWN
```

- 在启用持久化的情况下，`SHUTDOWN` 会先进行数据同步/持久化，
  再安全关闭进程；
- 通常建议通过 `systemctl stop redis` 等方式配合服务管理使用。

---

## 3.2 配置查询与在线调整

PDF 中示范了使用 `CONFIG GET` / `CONFIG SET` 来查看和在线修改
部分配置项，这对于临时调试与排查问题很有帮助。

### 3.2.1 查看配置

```bash
# 查看所有配置（输出较多）
CONFIG GET *

# 查看指定配置，例如监听地址
CONFIG GET bind

# 查看最大内存
CONFIG GET maxmemory
```

命令返回是“键值交替”的列表，例如：

```text
1) "dbfilename"
2) "dump.rdb"
3) "requirepass"
4) ""
...
```

### 3.2.2 在线修改配置

并非所有配置都支持在运行时修改，且不同版本支持情况不同。

以 `maxmemory` 为例，通常可以在线修改：

```bash
CONFIG SET maxmemory 8589934592   # 8G
# 或者
aCONFIG SET maxmemory 1g
CONFIG GET maxmemory
```

部分版本中，`bind` 等网络相关配置可能不支持运行时变更，PDF 中
就指出在某些版本执行 `CONFIG SET bind` 会报错：

```text
(error) ERR Unsupported CONFIG parameter: bind
```

因此：

- **安全相关、网络相关配置** 优先通过配置文件修改 + 重启生效；
- 在线修改主要用于缓存调优、慢查询分析等场景下的临时调整。

---

## 3.3 内存与淘汰策略（简要）

PDF 中对 `maxmemory` 等配置进行了示例，这里补充常见思路：

- `maxmemory`：限制 Redis 使用的最大内存；
- `maxmemory-policy`：内存用满后的“淘汰算法”，如：
  - `noeviction`：不再接收写入，直接报错；
  - `allkeys-lru`：对所有键做 LRU 淘汰；
  - `volatile-lru`：仅对设置了过期时间的键做 LRU 淘汰；
  - 等多种策略。

合理设置步骤：

1. 根据机器内存、其他进程开销，预估 Redis 可用内存；
2. 设置合适的 `maxmemory`；
3. 选择与业务特征匹配的淘汰策略；
4. 结合监控观察命中率与淘汰情况，逐步调优。

---

## 3.4 慢查询与性能排查

PDF 在“慢查询”章节中建议开启慢查询日志，用来定位执行时间过长
的命令。相关配置主要包括：

- `slowlog-log-slower-than`：阈值（单位：微秒）。
  - 例如设置为 `10000`，表示超过 10ms 的命令会记录为慢查询；
- `slowlog-max-len`：最多保留多少条慢查询记录。

简单使用示例：

```bash
# 查看当前慢查询配置
CONFIG GET slowlog-log-slower-than
CONFIG GET slowlog-max-len

# 查询慢查询列表
SLOWLOG GET 10   # 获取最近 10 条

# 清空慢查询日志
SLOWLOG RESET
```

在排查性能问题时，可以结合：

- 慢查询日志（slowlog）；
- INFO 命令输出的统计信息（如命中率、内存占用）；
- 系统层面的 CPU、I/O、网络监控。

---

## 3.5 Pipeline 使用思路

PDF 中通过实验对比了“逐条发送命令”和“使用 Pipeline 批量发送命令”
的性能差异。Pipeline 的核心思想是：

- 将多条命令一次性发送给服务器；
- 服务器依次执行后再将响应批量返回；
- 减少网络 RTT（往返次数），在延迟较大环境下提升吞吐量。

以伪代码说明：

```text
# 逐条发送
SET k1 v1
SET k2 v2
SET k3 v3
...

# Pipeline 思路
(SET k1 v1;
 SET k2 v2;
 SET k3 v3;
 ...)
一次性写入网络
```

在实际开发中：

- 建议在成批写入/读取一组数据时使用 Pipeline；
- 注意控制每个 pipeline 中的命令数量，避免一次发送过多导致
  单次延迟过高或单个请求体积过大；
- 不要在需要强顺序依赖、逐条检查返回值的场景滥用 Pipeline。

多数语言客户端都提供了 Pipeline 封装，可直接查阅对应文档
获取具体用法。

---

## 3.6 使用建议小结

1. 熟悉小部分基础命令（PING、DBSIZE、FLUSHDB、SHUTDOWN 等），
   可以快速判断 Redis 服务是否工作正常；
2. 合理利用 `CONFIG GET/SET` 做调试，但生产环境要谨慎在线修改
   网络和安全相关配置；
3. 用慢查询日志定位耗时命令，优先排查是否存在：
   - 大 key（单个键下数据过多）；
   - 批量操作 / 大范围扫描；
   - 复杂 Lua 脚本等；
4. 在网络延迟较大的场景下适当使用 Pipeline 提升效率；
5. 将本节内容与后续“Redis 数据类型”结合起来看，既理解“命令”，
   也理解“数据结构”，才能更好地使用 Redis。

