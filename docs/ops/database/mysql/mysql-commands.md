---
title: MySQL 常用命令
sidebar_position: 3
---

本章整理 MySQL 运维最常用的命令速查：连接、账号权限、库表操作、会话/锁、慢查询、复制状态等。可按需补充到你的 SOP。

## 1. 连接与基础信息

```bash
# 登录
mysql -h 127.0.0.1 -P 3306 -u root -p

# 查看版本/运行信息
mysql -uroot -p -e "SELECT VERSION();"
mysql -uroot -p -e "SHOW VARIABLES LIKE 'version%';"
mysql -uroot -p -e "SHOW GLOBAL STATUS LIKE 'Threads%';"
```

## 2. 用户与权限

```sql
-- 创建用户
CREATE USER 'app'@'%' IDENTIFIED BY 'StrongPassword';

-- 授权
GRANT SELECT,INSERT,UPDATE,DELETE ON appdb.* TO 'app'@'%';
FLUSH PRIVILEGES;

-- 查看用户与权限
SELECT user, host FROM mysql.user;
SHOW GRANTS FOR 'app'@'%';
```

## 3. 库表与容量

```sql
SHOW DATABASES;
USE appdb;
SHOW TABLES;
SHOW TABLE STATUS;
```

```sql
-- 按库统计容量（InnoDB 估算）
SELECT
  table_schema AS db,
  ROUND(SUM(data_length + index_length)/1024/1024, 2) AS size_mb
FROM information_schema.tables
GROUP BY table_schema
ORDER BY size_mb DESC;
```

## 4. 会话、慢查询与锁

```sql
-- 当前连接
SHOW PROCESSLIST;

-- InnoDB 事务与锁（8.0 以 performance_schema 为主）
SELECT * FROM information_schema.innodb_trx;
```

常用排障建议：

- 先看 `SHOW PROCESSLIST` 是否有长事务/长查询。
- 再看慢查询日志（`slow_query_log`、`long_query_time`）。
- 生产建议开启 `performance_schema` 并配合可观测平台做趋势分析。

## 5. 复制状态（主从）

> 复制更完整的内容见：[`mysql-replication`](./mysql-replication)

```sql
-- 从库查看复制状态（MySQL 8.0）
SHOW REPLICA STATUS\G

-- 主库查看 binlog
SHOW MASTER STATUS;
SHOW BINARY LOGS;
```

