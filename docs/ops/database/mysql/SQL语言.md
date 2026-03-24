---
title: SQL语言
sidebar_position: 3
---

# 3 SQL 语言

本节介绍 SQL 的基础概念与常见语法，主要围绕 MySQL/MariaDB 的使用场景。

---

## 3.1 SQL 概览

### 3.1.1 SQL 是什么

SQL (Structured Query Language) 是关系型数据库的**标准查询语言**，
用于定义、查询和管理关系型数据。

SQL 大致可以分为以下几类：

- **DDL (Data Definition Language)**：数据定义语言
  - `CREATE`、`ALTER`、`DROP` 等；
- **DML (Data Manipulation Language)**：数据操作语言
  - `INSERT`、`UPDATE`、`DELETE`；
- **DQL (Data Query Language)**：数据查询语言
  - `SELECT`；
- **DCL (Data Control Language)**：权限控制
  - `GRANT`、`REVOKE`；
- **TCL (Transaction Control Language)**：事务控制
  - `COMMIT`、`ROLLBACK`、`SAVEPOINT`。

---

## 3.2 基本查询语法

### 3.2.1 最简单的 SELECT

```sql
-- 查询整张表
SELECT *
FROM employees;

-- 查询指定列
SELECT id, name, department
FROM employees;
```

一般写法建议：

1. 在生产环境中尽量避免 `SELECT *`，明确写出需要的列；
2. 关键字大写、表名和列名小写或使用下划线风格；
3. 每个子句单独一行，便于阅读和版本管理。

### 3.2.2 WHERE 条件过滤

```sql
-- 使用比较运算符
SELECT id, name, salary
FROM employees
WHERE salary >= 10000;

-- 使用逻辑运算符
SELECT id, name, department
FROM employees
WHERE department = 'IT'
  AND status = 'active';

-- 区间与集合
SELECT *
FROM orders
WHERE created_at BETWEEN '2025-01-01' AND '2025-01-31'
  AND status IN ('paid', 'shipped');
```

### 3.2.3 排序与分页

```sql
-- 按工资从高到低排序
SELECT id, name, salary
FROM employees
ORDER BY salary DESC;

-- 多字段排序：先部门，再工资
SELECT id, name, department, salary
FROM employees
ORDER BY department ASC, salary DESC;

-- 简单分页
SELECT id, name
FROM employees
ORDER BY id
LIMIT 10 OFFSET 0;   -- 第 1 页

SELECT id, name
FROM employees
ORDER BY id
LIMIT 10 OFFSET 10;  -- 第 2 页
```

### 3.2.4 模糊匹配与空值判断

```sql
-- 模糊匹配
SELECT id, name
FROM customers
WHERE name LIKE '张%';   -- 以“张”开头

SELECT id, name
FROM customers
WHERE email LIKE '%@example.com';

-- 空值判断
SELECT id, nickname
FROM users
WHERE nickname IS NULL;        -- 未设置昵称

SELECT id, nickname
FROM users
WHERE nickname IS NOT NULL;    -- 已设置昵称
```

---

## 3.3 DDL：定义数据库和表

### 3.3.1 创建数据库

```sql
CREATE DATABASE IF NOT EXISTS demo_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
```

### 3.3.2 创建表

```sql
CREATE TABLE IF NOT EXISTS employees (
  id          BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  name        VARCHAR(50)  NOT NULL,
  department  VARCHAR(50)  NOT NULL,
  salary      DECIMAL(10,2) NOT NULL DEFAULT 0,
  hired_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_dept (department)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COMMENT = '员工信息表';
```

### 3.3.3 修改与删除表

```sql
-- 增加列
ALTER TABLE employees
  ADD COLUMN email VARCHAR(100) NULL AFTER name;

-- 修改列类型
ALTER TABLE employees
  MODIFY COLUMN salary DECIMAL(12,2) NOT NULL DEFAULT 0;

-- 删除表（慎用）
DROP TABLE IF EXISTS employees;
```

---

## 3.4 DML：增删改数据

### 3.4.1 插入数据

```sql
INSERT INTO employees (name, department, salary)
VALUES
  ('Alice',   'IT',   15000.00),
  ('Bob',     'HR',    9000.00),
  ('Charlie', 'IT',   13000.00);
```

### 3.4.2 更新数据

```sql
-- 单表更新
UPDATE employees
SET salary = salary * 1.1
WHERE department = 'IT';

-- 谨慎的大批量更新，可先用 SELECT 验证条件
SELECT *
FROM employees
WHERE department = 'IT';
```

### 3.4.3 删除数据

```sql
-- 删除单条或多条记录
DELETE FROM employees
WHERE id = 1001;

DELETE FROM employees
WHERE department = '离职员工';

-- 清空整张表（保留结构）
TRUNCATE TABLE employees;
```

---

## 3.5 事务控制和锁的基础

### 3.5.1 事务的四大特性 (ACID)

- **Atomicity（原子性）**
- **Consistency（一致性）**
- **Isolation（隔离性）**
- **Durability（持久性）**

### 3.5.2 简单事务示例

```sql
START TRANSACTION;

UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;

COMMIT;  -- 或 ROLLBACK
```

---

以上为 SQL 语言的基础部分，后续“SQL 高阶语法”会在此基础上深入介绍
连接、子查询、视图、函数、存储过程等高级特性。
