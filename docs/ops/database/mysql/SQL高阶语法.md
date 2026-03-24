---
title: SQL高阶语法
sidebar_position: 4
---

# 4 SQL 高阶语法

本节在 SQL 基础语法的基础上，继续介绍连接、子查询、视图、函数、
存储过程与触发器等高级用法。

---

## 4.1 连接 (JOIN)

在关系型数据库中，数据通常被拆分到多张表，通过 **JOIN** 在查询时重新组合。

### 4.1.1 常见 JOIN 类型

假设有两张表：

```sql
CREATE TABLE departments (
  id   INT PRIMARY KEY,
  name VARCHAR(50) NOT NULL
);

CREATE TABLE employees (
  id           INT PRIMARY KEY,
  name         VARCHAR(50) NOT NULL,
  department_id INT        NULL
);
```

#### 1）INNER JOIN（内连接）

只返回两张表中 **匹配成功** 的记录：

```sql
SELECT e.id, e.name, d.name AS department
FROM employees AS e
INNER JOIN departments AS d
  ON e.department_id = d.id;
```

#### 2）LEFT JOIN（左连接）

保留左表全部记录，右表匹配不到的地方填充 `NULL`：

```sql
SELECT e.id, e.name, d.name AS department
FROM employees AS e
LEFT JOIN departments AS d
  ON e.department_id = d.id;
```

#### 3）RIGHT JOIN / FULL JOIN

- RIGHT JOIN：与 LEFT JOIN 相反，保留右表全部记录；
- FULL JOIN：保留两边全部记录（MySQL 需通过 `UNION` 等方式模拟）。

---

## 4.2 子查询 (Subquery)

子查询是嵌套在其他查询中的 `SELECT` 语句，可出现在 WHERE / FROM / SELECT 部分。

### 4.2.1 标量子查询

返回单个值，可用于比较：

```sql
SELECT id, name, salary
FROM employees
WHERE salary > (
  SELECT AVG(salary)
  FROM employees
);
```

### 4.2.2 列子查询与行子查询

```sql
-- 列子查询：IN 子句
SELECT id, name
FROM employees
WHERE department_id IN (
  SELECT id
  FROM departments
  WHERE name LIKE '技术%'
);

-- 行子查询：用于多列比较（示意）
SELECT *
FROM employees
WHERE (department_id, salary) IN (
  SELECT department_id, MAX(salary)
  FROM employees
  GROUP BY department_id
);
```

---

## 4.3 视图 (VIEW)

视图是基于查询语句的 **虚拟表**，本身不存储数据，只存储定义。

### 4.3.1 创建视图

```sql
CREATE VIEW v_active_employees AS
SELECT id, name, department_id
FROM employees
WHERE status = 'active';
```

### 4.3.2 使用与管理视图

```sql
-- 使用视图查询
SELECT *
FROM v_active_employees
WHERE department_id = 1;

-- 查看视图定义
SHOW CREATE VIEW v_active_employees;

-- 删除视图
DROP VIEW IF EXISTS v_active_employees;
```

视图的常见用途：

- 简化复杂查询；
- 隐藏底层表结构，对外暴露稳定接口；
- 做权限隔离（只允许访问视图中的部分列或行）。

---

## 4.4 函数与表达式

### 4.4.1 内置函数示例

```sql
-- 字符串函数
SELECT UPPER(name), LOWER(name), LENGTH(name)
FROM employees;

-- 日期函数
SELECT NOW(), CURDATE(), DATE_ADD(CURDATE(), INTERVAL 7 DAY);

-- 数值函数
SELECT ABS(-10), ROUND(3.14159, 2), FLOOR(2.9), CEIL(2.1);
```

### 4.4.2 聚合函数与 GROUP BY

```sql
SELECT department_id,
       COUNT(*)          AS cnt,
       AVG(salary)       AS avg_salary,
       MAX(salary)       AS max_salary
FROM employees
GROUP BY department_id
HAVING COUNT(*) >= 3;
```

---

## 4.5 存储过程与函数

### 4.5.1 存储过程 (Stored Procedure)

```sql
DELIMITER $$

CREATE PROCEDURE raise_salary(IN p_dept_id INT, IN p_percent DECIMAL(5,2))
BEGIN
  UPDATE employees
  SET salary = salary * (1 + p_percent / 100)
  WHERE department_id = p_dept_id;
END $$

DELIMITER ;
```

调用存储过程：

```sql
CALL raise_salary(1, 10.0);  -- 为部门 1 加薪 10%
```

### 4.5.2 存储函数 (Stored Function)

```sql
DELIMITER $$

CREATE FUNCTION tax_amount(p_salary DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
  DECLARE tax DECIMAL(10,2);
  SET tax = p_salary * 0.1;  -- 示例：统一按 10% 计税
  RETURN tax;
END $$

DELIMITER ;
```

使用方式：

```sql
SELECT name, salary, tax_amount(salary) AS tax
FROM employees;
```

---

## 4.6 触发器 (Trigger)

触发器是在对表执行 `INSERT`/`UPDATE`/`DELETE` 时自动触发的程序。

```sql
DELIMITER $$

CREATE TRIGGER trg_employee_log
AFTER INSERT ON employees
FOR EACH ROW
BEGIN
  INSERT INTO employee_log(employee_id, action, created_at)
  VALUES (NEW.id, 'insert', NOW());
END $$

DELIMITER ;
```

触发器适合用来：

- 记录审计日志；
- 做简单的数据同步；
- 保证复杂业务规则（但不宜写过重逻辑）。

---

以上为 SQL 高阶语法的简要总结，实际项目中需要根据业务特点谨慎使用
视图、存储过程和触发器，并注意性能与维护成本。
