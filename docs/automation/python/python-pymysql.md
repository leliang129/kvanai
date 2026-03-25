---
title: Python-pymysql模块
---

# Python pymysql 模块使用指南

pymysql 是 Python 中用于连接 MySQL 数据库的模块，提供了与 MySQL 数据库交互的功能。

## 安装

```bash
# 使用 pip 安装
pip install pymysql
```

## 1. 基本连接

### 1.1 建立连接

```python
import pymysql

# 创建数据库连接
conn = pymysql.connect(
    host='localhost',      # 数据库主机地址
    user='root',          # 数据库用户名
    password='123456',    # 数据库密码
    database='test_db',   # 数据库名
    charset='utf8mb4',    # 字符编码
    port=3306,           # 端口号
    cursorclass=pymysql.cursors.DictCursor  # 使用字典游标
)

try:
    with conn.cursor() as cursor:
        # 执行SQL语句
        cursor.execute("SELECT VERSION()")
        result = cursor.fetchone()
        print(f"Database version: {result['VERSION()']}")
finally:
    conn.close()
```

### 1.2 错误处理

```python
try:
    conn = pymysql.connect(
        host='localhost',
        user='root',
        password='wrong_password',
        database='test_db'
    )
except pymysql.Error as e:
    print(f"连接错误: {e}")
```

## 2. 数据操作

### 2.1 插入数据

```python
def insert_user(name, age, email):
    try:
        with conn.cursor() as cursor:
            # 使用参数化查询防止SQL注入
            sql = "INSERT INTO users (name, age, email) VALUES (%s, %s, %s)"
            cursor.execute(sql, (name, age, email))
        # 提交更改
        conn.commit()
        print(f"成功插入用户: {name}")
    except pymysql.Error as e:
        # 发生错误时回滚
        conn.rollback()
        print(f"插入错误: {e}")

# 批量插入
def batch_insert_users(users):
    try:
        with conn.cursor() as cursor:
            sql = "INSERT INTO users (name, age, email) VALUES (%s, %s, %s)"
            cursor.executemany(sql, users)
        conn.commit()
        print(f"成功插入 {cursor.rowcount} 条记录")
    except pymysql.Error as e:
        conn.rollback()
        print(f"批量插入错误: {e}")
```

### 2.2 查询数据

```python
# 查询单条记录
def get_user(user_id):
    with conn.cursor() as cursor:
        sql = "SELECT * FROM users WHERE id = %s"
        cursor.execute(sql, (user_id,))
        result = cursor.fetchone()
        return result

# 查询多条记录
def get_users(age_limit):
    with conn.cursor() as cursor:
        sql = "SELECT * FROM users WHERE age > %s"
        cursor.execute(sql, (age_limit,))
        results = cursor.fetchall()
        return results

# 分页查询
def get_users_page(page, page_size):
    offset = (page - 1) * page_size
    with conn.cursor() as cursor:
        sql = "SELECT * FROM users LIMIT %s OFFSET %s"
        cursor.execute(sql, (page_size, offset))
        return cursor.fetchall()
```

### 2.3 更新数据

```python
def update_user(user_id, new_email):
    try:
        with conn.cursor() as cursor:
            sql = "UPDATE users SET email = %s WHERE id = %s"
            cursor.execute(sql, (new_email, user_id))
        conn.commit()
        print(f"成功更新用户 {user_id} 的邮箱")
    except pymysql.Error as e:
        conn.rollback()
        print(f"更新错误: {e}")
```

### 2.4 删除数据

```python
def delete_user(user_id):
    try:
        with conn.cursor() as cursor:
            sql = "DELETE FROM users WHERE id = %s"
            cursor.execute(sql, (user_id,))
        conn.commit()
        print(f"成功删除用户 {user_id}")
    except pymysql.Error as e:
        conn.rollback()
        print(f"删除错误: {e}")
```

## 3. 高级特性

### 3.1 事务处理

```python
def transfer_money(from_id, to_id, amount):
    try:
        with conn.cursor() as cursor:
            # 开始事务
            conn.begin()
            
            # 扣除转出账户金额
            sql1 = "UPDATE accounts SET balance = balance - %s WHERE id = %s"
            cursor.execute(sql1, (amount, from_id))
            
            # 增加转入账户金额
            sql2 = "UPDATE accounts SET balance = balance + %s WHERE id = %s"
            cursor.execute(sql2, (amount, to_id))
            
            # 提交事务
            conn.commit()
            print("转账成功")
    except pymysql.Error as e:
        # 发生错误时回滚
        conn.rollback()
        print(f"转账失败: {e}")
```

### 3.2 连接池

```python
from dbutils.pooled_db import PooledDB

# 创建连接池
pool = PooledDB(
    creator=pymysql,       # 使用链接数据库的模块
    maxconnections=6,      # 连接池允许的最大连接数
    mincached=2,          # 初始化时，链接池中至少创建的空闲的链接
    maxcached=5,          # 链接池中最多闲置的链接
    maxshared=3,          # 链接池中最多共享的链接数量
    blocking=True,        # 超过最大连接数量时候的表现
    maxusage=None,        # 一个链接最多被重复使用的次数
    host='localhost',
    user='root',
    password='123456',
    database='test_db',
    charset='utf8mb4'
)

# 使用连接池
def use_connection_pool():
    conn = pool.connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM users")
            return cursor.fetchall()
    finally:
        conn.close()
```

## 4. 实用示例

### 4.1 数据库备份

```python
def backup_table(table_name, output_file):
    try:
        with conn.cursor() as cursor:
            # 获取表数据
            cursor.execute(f"SELECT * FROM {table_name}")
            rows = cursor.fetchall()
            
            # 写入CSV文件
            import csv
            with open(output_file, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=rows[0].keys())
                writer.writeheader()
                writer.writerows(rows)
            
            print(f"成功备份表 {table_name} 到文件 {output_file}")
    except Exception as e:
        print(f"备份失败: {e}")
```

### 4.2 表结构操作

```python
def create_table():
    try:
        with conn.cursor() as cursor:
            sql = """
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                age INT,
                email VARCHAR(100) UNIQUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
            cursor.execute(sql)
        conn.commit()
        print("成功创建表")
    except pymysql.Error as e:
        print(f"创建表失败: {e}")
```

## 注意事项

1. 始终使用参数化查询防止SQL注入
2. 正确处理数据库连接的关闭
3. 在修改操作后要记得提交事务
4. 使用 with 语句自动管理游标
5. 大量数据操作时考虑使用连接池
6. 敏感信息（如密码）不要硬编码在代码中

## 常见错误处理

```python
# 连接错误处理
try:
    conn = pymysql.connect(
        host='localhost',
        user='root',
        password='123456',
        database='test_db'
    )
except pymysql.err.OperationalError as e:
    print(f"无法连接到数据库: {e}")
except pymysql.err.InternalError as e:
    print(f"数据库内部错误: {e}")

# 查询错误处理
try:
    with conn.cursor() as cursor:
        cursor.execute("SELECT * FROM non_existent_table")
except pymysql.err.ProgrammingError as e:
    print(f"SQL语法错误: {e}")
except pymysql.err.IntegrityError as e:
    print(f"数据完整性错误: {e}")
``` 