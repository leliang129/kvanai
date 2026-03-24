---
title: Redis 部署
sidebar_position: 2
---

# 2 Redis 部署

本节对应 PDF 中的“**Redis 部署**”部分，
主要介绍在 Linux 环境下部署 Redis 的常见方式，包括：

- 使用系统软件仓库安装；
- 源码编译安装及目录规划；
- 多实例部署（单机多端口）；
- 通过 Docker 容器运行 Redis；
- 常见工具与客户端连接方式。

---

## 2.1 安装方式概览

PDF 中给出了三种典型安装方式：

- **包安装（Package）**：通过发行版软件仓库或官方仓库安装；
- **源码编译安装（Source）**：自行下载源码编译，便于定制目录结构；
- **容器运行（Container）**：使用 Docker 等容器平台运行 Redis 实例。

生产环境中，常见的做法是：

- 以 **发行版包 / 官方包** 为主，方便升级与安全修复；
- 在需要灵活控制目录结构、版本或多实例时，使用 **源码编译 + 自定义目录**；
- 在容器化平台（Kubernetes 等）中，采用 **官方或自建镜像** 部署。

---

## 2.2 使用发行版软件仓库安装

### 2.2.1 Debian / Ubuntu 系列

```bash
sudo apt update
sudo apt install -y redis-server

# 查看服务状态
sudo systemctl status redis-server
```

常见文件位置：

- 配置文件：`/etc/redis/redis.conf`；
- 日志：`/var/log/redis/redis.log`；
- 数据目录：`/var/lib/redis`；
- systemd 单元：`/lib/systemd/system/redis-server.service` 等。

### 2.2.2 RHEL / CentOS / Rocky 系列

```bash
sudo yum install -y redis
# 或
sudo dnf install -y redis

sudo systemctl enable --now redis
sudo systemctl status redis
```

若系统自带版本较老，可以根据 PDF 中的链接添加官方仓库，或
使用源码编译方式安装更高版本的 Redis。

---

## 2.3 源码编译安装与目录规划

PDF 示范了通过源码编译安装 Redis，并在 `/apps/redis` 下划分
多个子目录来存放二进制、配置、数据、日志等内容。可以参考
如下布局：

```text
/apps/redis/
├── bin/    # 可执行文件（redis-server、redis-cli 等）
├── etc/    # 配置文件（例如 redis-6379.conf、redis-6380.conf）
├── data/   # 数据目录（持久化文件）
├── log/    # 日志文件
└── run/    # PID 文件、socket 文件等
```

### 2.3.1 下载与编译

```bash
# 以 7.2.4 为例
wget https://download.redis.io/releases/redis-7.2.4.tar.gz

 tar -xf redis-7.2.4.tar.gz
 cd redis-7.2.4

# 编译
make

# 安装到目标目录（示例）
make PREFIX=/apps/redis install
```

然后将生成的可执行文件移动到上述 `bin` 目录，并为每个实例
准备独立的配置文件与数据目录。

---

## 2.4 多实例部署（单机多端口）

在测试环境或资源有限的环境中，经常希望在一台服务器上运行
多个 Redis 实例，以不同端口对外提供服务。PDF 中给出了
**多实例目录布局与配置示例**，核心思路如下：

1. 为每个实例准备独立配置文件，例如：
   - `etc/redis-6379.conf`
   - `etc/redis-6380.conf`
2. 为每个实例准备独立的数据、日志、PID 目录：
   - `data/6379/`、`log/redis-6379.log` 等；
3. 为不同实例设置不同端口、PID 文件和日志文件名。

配置片段示例（以 6379 端口为例）：

```conf
port 6379
pidfile /apps/redis/run/redis_6379.pid
logfile /apps/redis/log/redis-6379.log
dir /apps/redis/data/6379
```

可以通过 systemd 单元或简单的 shell 脚本批量启动多个实例：

```bash
/apps/redis/bin/redis-server /apps/redis/etc/redis-6379.conf
/apps/redis/bin/redis-server /apps/redis/etc/redis-6380.conf
```

这种方式在一台服务器上模拟多节点环境、学习主从复制或
集群部署时非常方便。

---

## 2.5 使用 Docker 部署 Redis 多实例

PDF 中还演示了使用 Docker 运行多个 Redis 实例的方式，例如：

```bash
# 示例：在宿主机 7777 端口运行一个 Redis 实例

docker run --name redis7777 \
  -d -p 7777:6379 \
  -v /opt/redis/redis.conf:/etc/redis/redis.conf \
  --restart always \
  redis:7.2.4 redis-server /etc/redis/redis.conf

# 再运行一个 8888 端口的实例

docker run --name redis8888 \
  -d -p 8888:6379 \
  -v /opt/redis/redis.conf:/etc/redis/redis.conf \
  --restart always \
  redis:7.2.4 redis-server /etc/redis/redis.conf
```

要点：

- 通过 `-p 宿主端口:容器端口` 将不同宿主端口映射到容器的 6379；
- 通过 `-v` 挂载配置文件和持久化目录；
- 使用 `--restart always` 保证容器异常退出后自动拉起。

在容器化平台中，还可以通过编排工具（docker-compose、
Kubernetes 等）管理多个 Redis 实例，并结合主从复制、哨兵
或 Cluster 架构实现高可用。

---

## 2.6 Redis 工具与客户端

PDF 在“Redis 工具和客户端连接”章节中介绍了多个工具，这里
简要整理几类：

### 2.6.1 命令行客户端 `redis-cli`

最常用的 CLI 工具，用于：

- 交互式执行命令；
- 执行脚本或批量命令；
- 做简单的连通性与性能测试。

示例：

```bash
redis-cli -h 127.0.0.1 -p 6379
127.0.0.1:6379> PING
PONG
```

### 2.6.2 图形化管理工具

PDF 中提到了 Redis Desktop Manager 等 GUI 工具：

- 通过图形界面浏览键空间、在线修改键值；
- 支持简单的监控与导出；
- 注意与 Redis 版本的兼容性（例如文档中提到
  Redis 7.2.1 某些工具版本无法连接等）。

除此之外，常见的还有：

- Medis、Another Redis Desktop Manager 等桌面工具；
- 使用 VSCode 插件等方式集成到开发环境。

### 2.6.3 编程语言客户端

Redis 官方文档和 PDF 列举了多种语言客户端：

- Java、C/C++、Go、Python、PHP、JavaScript 等；
- 大部分客户端都支持连接池、自动重连、序列化等功能；
- 在实际开发中应优先选择维护活跃、文档完整的客户端库。

---

本节从 PDF 中“Redis 部署”的内容出发，对包安装、源码安装、
多实例部署以及 Docker 方式进行了整理，后续“Redis 使用”
将基于这些部署方式展开日常运维与命令实践。

