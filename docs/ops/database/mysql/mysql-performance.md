---
title: MySQL 性能优化
sidebar_position: 4
---

本章用于承载性能调优内容（慢查询、索引、执行计划、InnoDB 参数、容量规划）。先给一个最小落地清单，后续可持续补全。

## 1. 调优的基本顺序（建议）

1. **先定位慢**：慢查询日志 / 业务链路 / 指标（QPS、延迟、buffer pool 命中率）。
2. **再看执行计划**：`EXPLAIN`、索引选择、回表、扫描行数。
3. **再做索引**：最小化索引数量、避免高基数/低选择性误用。
4. **最后调参数**：`innodb_buffer_pool_size`、`innodb_log_file_size` 等要配合压测。

## 2. 慢查询日志（建议开启）

```sql
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';
```

## 3. EXPLAIN 速查

```sql
EXPLAIN SELECT * FROM t WHERE a = 1 ORDER BY b LIMIT 10;
```

关注点：

- `type`（ALL/INDEX/RANGE/REF/CONST…）
- `key` 是否命中预期索引
- `rows` 扫描行数
- `Extra`（Using filesort / Using temporary）

