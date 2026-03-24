---
title: Redis 数据类型
sidebar_position: 4
---

# 4 Redis 数据类型

本节对应 PDF 中“**Redis 数据类型**”部分，
结合官方资料对 Redis 中常见的数据结构做一个系统性的整理，
包括字符串、列表、哈希、集合、有序集合以及若干高级类型。

命令示例以 `redis-cli` 交互方式为主。

> 说明：具体命令的返回格式可能因客户端和版本略有差异，
> 示例仅用于演示基本用法。

---

## 4.1 字符串（String）

PDF 中指出：字符串是 Redis 最基础、使用最广的数据类型。

特点：

- 二进制安全，可以存放任意内容（文本、JSON、图片二进制等）；
- 单个字符串最大可存储约 512MB 内容；
- 所有键（key）本身都是字符串类型。

常用操作：

```bash
# 设置与获取
SET name "alice"
GET name

# 覆盖与追加
SET greeting "hello"
APPEND greeting " world"   # 结果为 "hello world"

# 计数器：自增 / 自减
SET page:views 0
INCR page:views
INCRBY page:views 10
DECR page:views
```

常见应用：

- 缓存单个值或序列化后的对象（如 JSON）；
- 各类计数器（访问量、点赞数等）；
- 分布式锁的基础实现（配合 `SET key value NX PX`）。

---

## 4.2 列表（List）

列表是一个按照插入顺序排序的字符串序列，可以从两端进行入队/出队。

常用命令：

```bash
# 从左侧插入元素
LPUSH queue:email task1 task2

# 从右侧弹出元素
RPOP queue:email

# 阻塞式弹出（若队列为空则等待，超时单位为秒）
BRPOP queue:email 30

# 获取指定区间元素
LRANGE queue:email 0 -1
```

典型场景：

- 简单队列：使用 LPUSH + BRPOP 实现生产者/消费者模型；
- 按时间顺序记录事件日志或消息列表。

注意事项：

- 单个列表过大可能带来性能问题，应合理拆分或做过期策略；
- 对头部/尾部频繁操作更高效，中间插入/删除相对较慢。

---

## 4.3 哈希（Hash）

哈希类似于一个“字段 → 值”的小型字典，适合存放对象的多个属性。

```bash
# 设置用户信息
HSET user:1001 name "Alice" age 25 city "Beijing"

# 读取单个字段
HGET user:1001 name

# 读取所有字段
HGETALL user:1001

# 删除字段
HDEL user:1001 city

# 判断字段是否存在
HEXISTS user:1001 age
```

典型场景：

- 用户信息、配置项等结构化数据；
- 需要高频读写单个字段，而非整个对象的场景。

实践建议：

- 键粒度要适中，避免将过多用户数据塞进同一个哈希中；
- 对稳定结构的数据，也可以考虑使用字符串存 JSON 的方式，
  由应用层负责解析。两者各有优劣。

---

## 4.4 集合（Set）

集合是一个**无序且不重复**的元素集合，适合做去重和关系运算。

```bash
# 添加成员
SADD online_users 1001 1002 1003

# 判断成员是否存在
SISMEMBER online_users 1001

# 统计成员数量
SCARD online_users

# 随机获取 / 弹出成员
SRANDMEMBER online_users 2
SPOP online_users
```

集合运算：

```bash
# 交集：共同好友
SINTER friends:alice friends:bob

# 并集：两个集合所有成员
SUNION friends:alice friends:bob

# 差集：在 A 中但不在 B 中
SDIFF set:a set:b
```

典型场景：

- 在线用户集合；
- 标签系统（用户的兴趣标签等）；
- 简单社交关系计算（共同好友、共同关注等）。

---

## 4.5 有序集合（Sorted Set）

有序集合在集合基础上为每个成员关联一个**分数（score）**，
按分数从小到大排序，适合做排行榜等场景。

```bash
# 添加成员及其分数
ZADD ranking 100 alice 80 bob 120 charlie

# 按分数从小到大获取
ZRANGE ranking 0 -1 WITHSCORES

# 按分数从大到小获取前 10 名
ZREVRANGE ranking 0 9 WITHSCORES

# 查看成员分数
ZSCORE ranking alice

# 修改成员分数
ZINCRBY ranking 10 alice
```

典型场景：

- 排行榜：积分榜、热度榜等；
- 延迟队列：使用时间戳作为 score，按时间顺序处理任务；
- 打分/权重排序：例如搜索结果中结合多个维度计算综合得分。

---

## 4.6 其他常见数据结构（简要）

PDF 中还提到了官方文档对其他数据类型的说明，这里做简要补充：

### 4.6.1 位图（Bitmap）

- 本质上是基于字符串的位操作；
- 适合存储布尔状态，如“某天是否签到”；
- 常用命令：`SETBIT`、`GETBIT`、`BITCOUNT` 等。

示例：

```bash
# 标记用户 1001 在第 1 天签到
SETBIT sign:2026-01 1 1

# 统计本月签到人数
BITCOUNT sign:2026-01
```

### 4.6.2 HyperLogLog

- 用极小的存储空间做**去重计数**（近似值）；
- 适合 UV（独立访客）统计等场景；
- 常用命令：`PFADD`、`PFCOUNT`、`PFMERGE`。

示例：

```bash
PFADD uv:2026-01 user1 user2 user3
PFCOUNT uv:2026-01
```

### 4.6.3 Streams

- 自 Redis 5.0 引入的日志型数据结构；
- 适合构建轻量级消息队列、事件流处理；
- 支持消费组、消息 ID 等，适用于多消费者场景。

示例：

```bash
# 写入一条消息
XADD mystream * name alice action login

# 从头开始读取若干条
XRANGE mystream - + COUNT 10
```

---

## 4.7 使用数据类型的实践建议

1. **根据场景选择合适的数据结构**：
   - 排行榜优先考虑有序集合；
   - 计数器优先考虑字符串；
   - 关系运算使用集合；
   - 对象属性较多时可以用哈希或字符串+JSON。
2. **避免“大 key”问题**：
   - 不要在单个键下面堆积过多元素（极大的列表/集合/哈希等）；
   - 大 key 读写和删除都可能造成阻塞，影响整体性能。
3. **结合过期策略与内存策略**：
   - 确保长期不再访问的数据能够过期或被淘汰；
   - 对缓存类数据设置合理 TTL。
4. **结合前一节“Redis 使用”中的命令与配置**：
   - 在理解数据结构的基础上，再结合慢查询日志、内存配置、
     Pipeline 等技术手段进行调优。

---

本节基于 PDF 中“Redis 数据类型”的章节，对常见数据结构
进行了分类与示例说明。结合前文“Redis 部署”“Redis 使用”，
可以完成从部署、基本命令到核心数据结构的完整学习路径。

