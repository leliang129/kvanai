---
title: MySQL 安装配置
sidebar_position: 2
---

本文详细介绍 MySQL 的各种安装方式，从 Docker 容器到二进制安装，以及生产环境的配置优化。

> **推荐顺序**：开发环境优先使用 Docker，生产环境使用官方二进制安装。

## 1. Docker 安装（推荐开发/测试）

### 1.1 最简单方式

```bash
# 拉取官方镜像
docker pull mysql:8.0

# 启动 MySQL 容器
docker run -d \
  --name mysql \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=your_password \
  -v mysql_data:/var/lib/mysql \
  mysql:8.0

# 进入容器
docker exec -it mysql mysql -uroot -p
```

### 1.2 使用 Docker Compose（推荐）

创建 `compose.yaml`：

```yaml
services:
  mysql:
    image: mysql:8.0
    container_name: mysql
    ports:
      - "3306:3306"
    environment:
      # 基本配置
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-rootpassword}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-myapp}
      MYSQL_USER: ${MYSQL_USER:-appuser}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-apppassword}
      TZ: Asia/Shanghai
    volumes:
      # 数据持久化
      - mysql_data:/var/lib/mysql
      # 自定义配置文件
      - ./conf/my.cnf:/etc/mysql/conf.d/my.cnf:ro
      # 初始化脚本
      - ./init:/docker-entrypoint-initdb.d:ro
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --default-authentication-plugin=mysql_native_password
    restart: unless-stopped

    # 健康检查
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-p$$MYSQL_ROOT_PASSWORD"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s

volumes:
  mysql_data:
    driver: local
```

**启动服务**：

```bash
# 启动
docker compose up -d

# 查看日志
docker compose logs -f mysql

# 查看状态
docker compose ps

# 进入容器
docker compose exec mysql mysql -uroot -p
```

## 2. Linux 二进制安装（推荐生产环境）

### 2.1 下载官方二进制包

访问 [MySQL 官方下载页面](https://dev.mysql.com/downloads/mysql/) 或使用命令行下载：

```bash
# 创建下载目录
mkdir -p /opt/mysql && cd /opt/mysql

# 下载 MySQL 8.0（通用 Linux 二进制包）
# 根据系统架构选择：x86_64 或 aarch64
wget https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.40-linux-glibc2.28-x86_64.tar.xz

# 或使用国内镜像（更快）
wget https://mirrors.tuna.tsinghua.edu.cn/mysql/downloads/MySQL-8.0/mysql-8.0.40-linux-glibc2.28-x86_64.tar.xz

# 验证下载（可选）
# 从官网获取 MD5 值进行校验
md5sum mysql-8.0.40-linux-glibc2.28-x86_64.tar.xz
```

### 2.2 创建 MySQL 用户和组

```bash
# 创建 mysql 组
sudo groupadd mysql

# 创建 mysql 用户（不允许登录）
sudo useradd -r -g mysql -s /bin/false mysql

# 验证用户
id mysql
```

### 2.3 解压并安装

```bash
# 解压到 /usr/local/
sudo tar xvf mysql-8.0.40-linux-glibc2.28-x86_64.tar.xz -C /usr/local/

# 创建软链接（方便版本管理和升级）
sudo ln -s /usr/local/mysql-8.0.40-linux-glibc2.28-x86_64 /usr/local/mysql

# 创建数据目录
sudo mkdir -p /data/mysql/{data,logs,tmp}

# 设置权限
sudo chown -R mysql:mysql /data/mysql
sudo chown -R mysql:mysql /usr/local/mysql
sudo chmod 750 /data/mysql/data
```

### 2.4 创建配置文件

创建 `/etc/my.cnf`：

```bash
sudo tee /etc/my.cnf > /dev/null <<'EOF'
[mysqld]
# ============ 基本设置 ============
user = mysql
port = 3306
basedir = /usr/local/mysql
datadir = /data/mysql/data
tmpdir = /data/mysql/tmp
socket = /tmp/mysql.sock
pid-file = /data/mysql/mysql.pid

# ============ 字符集设置 ============
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
init_connect = 'SET NAMES utf8mb4'
default-time-zone = '+08:00'

# ============ 网络设置 ============
bind-address = 0.0.0.0
max_connections = 1000
max_connect_errors = 1000
max_allowed_packet = 64M

# ============ InnoDB 设置 ============
# Buffer Pool（建议设置为物理内存的 50-80%）
innodb_buffer_pool_size = 2G
innodb_buffer_pool_instances = 2

# 日志设置
innodb_log_file_size = 512M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# 表空间
innodb_file_per_table = 1
innodb_open_files = 2000

# ============ 日志设置 ============
# 错误日志
log_error = /data/mysql/logs/error.log

# 慢查询日志
slow_query_log = 1
slow_query_log_file = /data/mysql/logs/slow.log
long_query_time = 2

# 二进制日志
log_bin = /data/mysql/logs/mysql-bin
binlog_format = ROW
binlog_expire_logs_seconds = 604800  # 7 天
max_binlog_size = 1G

# ============ 其他设置 ============
server-id = 1
lower_case_table_names = 0
sql_mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION

[client]
port = 3306
socket = /tmp/mysql.sock
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4
no-auto-rehash
EOF
```

### 2.5 初始化数据库

```bash
# 初始化 MySQL 数据目录
sudo /usr/local/mysql/bin/mysqld \
  --initialize-insecure \
  --user=mysql \
  --basedir=/usr/local/mysql \
  --datadir=/data/mysql/data

# 或使用安全初始化（生成随机 root 密码）
# sudo /usr/local/mysql/bin/mysqld \
#   --initialize \
#   --user=mysql \
#   --basedir=/usr/local/mysql \
#   --datadir=/data/mysql/data

# 查看初始化日志（如果使用 --initialize，密码在这里）
sudo cat /data/mysql/logs/error.log | grep 'temporary password'
```

**参数说明**：
- `--initialize-insecure`：不生成 root 密码（首次登录后需手动设置）
- `--initialize`：生成随机 root 密码（更安全）

### 2.6 配置 systemd 服务

创建 systemd 服务文件：

```bash
sudo tee /etc/systemd/system/mysqld.service > /dev/null <<'EOF'
[Unit]
Description=MySQL Server
Documentation=man:mysqld(8)
Documentation=https://dev.mysql.com/doc/refman/en/using-systemd.html
After=network.target
After=syslog.target

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
User=mysql
Group=mysql

# 设置环境变量
Environment="MYSQLD_PARENT_PID=1"

# 启动命令
ExecStart=/usr/local/mysql/bin/mysqld --defaults-file=/etc/my.cnf

# 优雅关闭
TimeoutSec=0
KillMode=process
SendSIGKILL=no

# 自动重启策略
Restart=on-failure
RestartPreventExitStatus=1

# 资源限制
LimitNOFILE=65535
LimitNPROC=65535

# 工作目录
WorkingDirectory=/usr/local/mysql

# 私有临时目录
PrivateTmp=true
EOF
```

### 2.7 启动 MySQL 服务

```bash
# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启动 MySQL
sudo systemctl start mysqld

# 设置开机自启
sudo systemctl enable mysqld

# 查看状态
sudo systemctl status mysqld

# 查看日志
sudo tail -f /data/mysql/logs/error.log
```

### 2.8 配置环境变量

```bash
# 添加到 PATH
echo 'export PATH=/usr/local/mysql/bin:$PATH' | sudo tee -a /etc/profile
source /etc/profile

# 或者创建软链接
sudo ln -s /usr/local/mysql/bin/mysql /usr/bin/mysql
sudo ln -s /usr/local/mysql/bin/mysqldump /usr/bin/mysqldump
sudo ln -s /usr/local/mysql/bin/mysqladmin /usr/bin/mysqladmin

# 验证
mysql --version
which mysql
```

### 2.9 安全初始化

```bash
# 首次登录（如果使用 --initialize-insecure）
mysql -u root

# 或使用临时密码登录（如果使用 --initialize）
mysql -u root -p
```

在 MySQL 中执行安全配置：

```sql
-- 1. 设置 root 密码
ALTER USER 'root'@'localhost' IDENTIFIED BY 'your_strong_password';

-- 2. 删除匿名用户
DELETE FROM mysql.user WHERE User='';

-- 3. 删除 test 数据库
DROP DATABASE IF EXISTS test;

-- 4. 刷新权限
FLUSH PRIVILEGES;
```

### 2.10 验证安装

```bash
# 检查 MySQL 进程
ps aux | grep mysql

# 检查监听端口
sudo netstat -tunlp | grep 3306
# 或
sudo ss -tunlp | grep 3306

# 测试连接
mysql -u root -p -e "SELECT VERSION();"
mysql -u root -p -e "SHOW DATABASES;"

# 查看字符集
mysql -u root -p -e "SHOW VARIABLES LIKE 'character%';"
```

## 3. macOS 安装

### 3.1 使用 Homebrew（推荐）

```bash
# 安装 MySQL
brew install mysql

# 启动服务
brew services start mysql

# 安全初始化
mysql_secure_installation

# 查看服务状态
brew services list
```

### 3.2 使用官方 DMG 包

1. 访问 [MySQL 官方下载页面](https://dev.mysql.com/downloads/mysql/)
2. 下载 macOS DMG 安装包
3. 双击安装
4. 在系统偏好设置中启动 MySQL 服务

## 4. 首次配置

### 4.1 基本安全配置

```sql
-- ============ 1. 修改 root 密码 ============
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_strong_password';

-- ============ 2. 创建数据库 ============
CREATE DATABASE myapp
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- ============ 3. 创建应用用户 ============
-- 只读用户
CREATE USER 'readonly'@'%' IDENTIFIED BY 'readonly_password';
GRANT SELECT ON myapp.* TO 'readonly'@'%';

-- 读写用户
CREATE USER 'appuser'@'%' IDENTIFIED BY 'app_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'appuser'@'%';

-- 管理员用户（限制本地访问）
CREATE USER 'admin'@'localhost' IDENTIFIED BY 'admin_password';
GRANT ALL PRIVILEGES ON myapp.* TO 'admin'@'localhost';

-- ============ 4. 刷新权限 ============
FLUSH PRIVILEGES;

-- ============ 5. 查看用户 ============
SELECT user, host FROM mysql.user;
```

### 4.2 验证配置

```sql
-- 查看字符集配置
SHOW VARIABLES LIKE 'character%';
SHOW VARIABLES LIKE 'collation%';

-- 查看重要配置
SHOW VARIABLES LIKE 'max_connections';
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
SHOW VARIABLES LIKE 'slow_query_log%';
SHOW VARIABLES LIKE 'log_bin';

-- 查看数据目录
SHOW VARIABLES LIKE 'datadir';
SHOW VARIABLES LIKE 'basedir';

-- 查看服务器状态
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Uptime';
SELECT VERSION();
```

## 5. 配置优化建议

### 5.1 根据服务器内存优化

**服务器内存 16GB 示例**：

```ini
[mysqld]
# InnoDB Buffer Pool（50-80% 内存）
innodb_buffer_pool_size = 10G
innodb_buffer_pool_instances = 10

# 连接和缓冲
max_connections = 1000
table_open_cache = 4000
tmp_table_size = 256M
max_heap_table_size = 256M

# 排序和连接
sort_buffer_size = 4M
join_buffer_size = 4M
read_buffer_size = 2M
read_rnd_buffer_size = 4M
```

### 5.2 性能相关配置

```ini
[mysqld]
# ============ InnoDB 性能优化 ============
# 日志文件大小（建议 innodb_buffer_pool_size 的 25%）
innodb_log_file_size = 2G
innodb_log_buffer_size = 64M

# 刷盘策略（0=最快但可能丢数据，1=最安全但慢，2=折中）
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# IO 线程
innodb_read_io_threads = 8
innodb_write_io_threads = 8

# 并发控制（0=自动，建议保持默认）
innodb_thread_concurrency = 0

# ============ 查询缓存（MySQL 8.0 已移除） ============
# query_cache_type = 0

# ============ 慢查询优化 ============
slow_query_log = 1
long_query_time = 1
log_queries_not_using_indexes = 0
min_examined_row_limit = 1000
```

### 5.3 安全相关配置

```ini
[mysqld]
# ============ 网络安全 ============
# 只监听本地（如果不需要远程连接）
# bind-address = 127.0.0.1

# 禁用 DNS 解析（提升连接速度）
skip-name-resolve = 1

# 禁用 LOCAL INFILE（防止数据泄露）
local_infile = 0

# ============ SQL 模式（严格模式） ============
sql_mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION

# ============ 密码策略（MySQL 8.0+） ============
# validate_password.policy = STRONG
# validate_password.length = 12
```

## 6. 常见问题排查

### 6.1 服务无法启动

```bash
# 1. 查看错误日志
sudo tail -100 /data/mysql/logs/error.log

# 2. 检查端口占用
sudo lsof -i:3306
sudo netstat -tunlp | grep 3306

# 3. 检查权限
ls -la /data/mysql/
ls -la /usr/local/mysql/

# 4. 检查配置文件语法
/usr/local/mysql/bin/mysqld --defaults-file=/etc/my.cnf --validate-config

# 5. 手动启动（查看详细错误）
sudo -u mysql /usr/local/mysql/bin/mysqld --defaults-file=/etc/my.cnf --console
```

### 6.2 无法远程连接

```bash
# 1. 检查防火墙
# Ubuntu/Debian
sudo ufw status
sudo ufw allow 3306/tcp

# CentOS/RHEL
sudo firewall-cmd --list-ports
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --reload

# 2. 检查 bind-address
grep bind-address /etc/my.cnf

# 3. 检查用户权限
mysql -u root -p -e "SELECT user, host FROM mysql.user WHERE user='appuser';"

# 4. 创建远程用户
mysql -u root -p <<EOF
CREATE USER 'admin'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';
FLUSH PRIVILEGES;
EOF
```

### 6.3 找不到 my.cnf

```bash
# 查看 MySQL 读取配置文件的顺序
mysql --help --verbose | grep -A 1 'Default options'

# 常见位置
ls -la /etc/my.cnf
ls -la /etc/mysql/my.cnf
ls -la ~/.my.cnf

# 查看实际使用的配置
mysql -u root -p -e "SHOW VARIABLES LIKE '%dir%';"
```

### 6.4 初始化失败

```bash
# 删除旧数据（谨慎操作！）
sudo rm -rf /data/mysql/data/*

# 重新初始化
sudo /usr/local/mysql/bin/mysqld \
  --initialize-insecure \
  --user=mysql \
  --basedir=/usr/local/mysql \
  --datadir=/data/mysql/data

# 查看初始化日志
sudo cat /data/mysql/logs/error.log
```

## 7. 卸载 MySQL

### 7.1 停止服务并卸载

```bash
# 停止服务
sudo systemctl stop mysqld
sudo systemctl disable mysqld

# 删除服务文件
sudo rm -f /etc/systemd/system/mysqld.service
sudo systemctl daemon-reload

# 删除 MySQL 文件
sudo rm -rf /usr/local/mysql*
sudo rm -f /usr/bin/mysql*

# 删除数据目录（谨慎！）
sudo rm -rf /data/mysql

# 删除配置文件
sudo rm -f /etc/my.cnf

# 删除用户和组
sudo userdel mysql
sudo groupdel mysql
```

## 8. 升级 MySQL

### 8.1 二进制升级步骤

```bash
# 1. 备份数据
mysqldump -u root -p --all-databases > /backup/all_databases_$(date +%Y%m%d).sql

# 2. 停止 MySQL
sudo systemctl stop mysqld

# 3. 备份旧版本
sudo cp -r /usr/local/mysql /usr/local/mysql.bak
sudo cp -r /data/mysql /data/mysql.bak

# 4. 下载新版本
cd /opt/mysql
wget https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.0-linux-glibc2.28-x86_64.tar.xz

# 5. 解压新版本
sudo tar xvf mysql-8.4.0-linux-glibc2.28-x86_64.tar.xz -C /usr/local/

# 6. 更新软链接
sudo rm /usr/local/mysql
sudo ln -s /usr/local/mysql-8.4.0-linux-glibc2.28-x86_64 /usr/local/mysql

# 7. 升级数据库
sudo /usr/local/mysql/bin/mysql_upgrade -u root -p

# 8. 启动 MySQL
sudo systemctl start mysqld

# 9. 验证版本
mysql -V
mysql -u root -p -e "SELECT VERSION();"
```

---

## 相关文档

- [MySQL 简要介绍](./mysql-intro) - MySQL 架构和核心特性
- [MySQL 常用命令](./mysql-commands) - 日常运维命令速查
- [MySQL 性能优化](./mysql-performance) - 深入的性能调优
- [Docker Compose 容器编排](/ops/docker/docker-compose) - Docker 部署最佳实践

**下一步**：建议阅读 [MySQL 常用命令](./mysql-commands)，掌握日常运维操作。
