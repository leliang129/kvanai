---
sidebar_position: 1
---

# 数据库与存储巡检

数据库是业务可靠性的最后一道防线。本章节覆盖 MySQL、PostgreSQL、Redis 等常用数据存储的巡检手册。

## MySQL

- 备份
  - 结合 `mysqldump` 与 `xtrabackup`，每日全备 + 每小时增量。
  - 备份校验脚本：`scripts/mysql-restore-check.sh`。
- 性能
  - 使用 `performance_schema` 与 `pt-query-digest` 分析慢查询。
  - `innodb_buffer_pool_reads` 持续高企时考虑扩容。

## PostgreSQL

- 主从复制延迟：`pg_stat_replication` 的 `replay_lag`。
- `VACUUM` 调度：通过 `auto_vacuum_freeze_max_age` 控制膨胀。
- `pgBackRest` 用于统一备份策略。

## Redis

- 内存与持久化
  - `used_memory`, `maxmemory`, `rdb_last_bgsave_status`。
  - AOF rewrite 期间监控 `aof_current_rewrite_time_sec`。
- Cluster
  - `cluster_state`、`cluster_slots_pfail` 指标。
  - 自动故障转移脚本记录在 Playbook。

## 常用命令

```bash
# MySQL 备份恢复演练
target=$1
tar -xf backup/$target.tar.gz -C /tmp/restore
mysql -uroot -p < /tmp/restore/$target.sql
```

## 延伸阅读

- [Percona Toolkit](https://www.percona.com/software/database-tools/percona-toolkit)
- [PostgreSQL Docs](https://www.postgresql.org/docs/)

