---
title: MySQL 主从复制
sidebar_position: 6
---

本章用于承载复制与高可用实践：GTID、半同步、延迟与漂移、故障切换。先给一个快速检查清单，后续可继续补齐。

## 1. 常见复制模式

- 异步复制（默认）
- 半同步复制（降低数据丢失风险）
- GTID（更易切换与修复）

## 2. 从库健康检查

```sql
SHOW REPLICA STATUS\G
```

重点字段：

- `Replica_IO_Running` / `Replica_SQL_Running`
- `Seconds_Behind_Source`
- `Last_Error` / `Last_SQL_Error`

## 3. 典型故障与方向

- **延迟上升**：下游写入压力、单线程 apply、磁盘 IO、长事务。
- **复制中断**：表结构差异、权限、binlog 清理过早、网络抖动。

