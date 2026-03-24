---
title: MySQL快速入门
sidebar_position: 2
---

# 2 MySQL 快速入门

本节从 **MySQL 的背景、软件包差异** 开始，带你在常见 Linux 发行版上
完成 MySQL / MariaDB 的安装与基本检查。

> 说明：编号仍然沿用课件中的 1.2.x，以便和 PDF 对应。

---

## 2.1 MySQL 简介

### 2.1.1 MySQL 经历了什么（历史概览）

- **起源**：MySQL 的创始人是 Michael Widenius（外号 Monty），
  最早在 1979 年左右开始做相关工作，最初只是为报表工具开发的一套 API。
- **1996 年**：发布 MySQL 1.0，随后在 Solaris、Linux 等平台迅速普及。
- **1999 年**：成立 MySQL AB 公司，MySQL 从个人项目走向团队化、商业化。
- **2001 年**：InnoDB 存储引擎诞生，提供事务、行级锁、崩溃恢复等特性，
  后来成为 MySQL 的默认存储引擎。
- **2008 年**：Sun 以约 10 亿美金收购 MySQL AB，MySQL 进入 Sun 时代。
- **2009 年**：Oracle 收购 Sun，MySQL 进入 Oracle 时代。
- **之后**：社区对 MySQL 的开源前景产生担忧，促成了 MariaDB 等分支的出现。

> 小知识：MySQL 这个名字来自 Monty 的大女儿 My，后来他的小女儿 Maria
> 则成为 MariaDB 项目名字的来源。

### 2.1.2 MySQL 与 MariaDB 的关系

- **MariaDB** 是 MySQL 的一个社区分支，保持高度兼容：
  - SQL 语法、存储引擎接口大部分兼容；
  - 工具命令名（`mysql`、`mysqld` 等）也基本一致；
  - 常见应用/框架通常可以无缝在 MySQL 与 MariaDB 之间切换。
- 差异主要体现在：
  - 发布节奏：MariaDB 的版本号通常形如 `10.5.27`，MySQL 则是 `8.0.41`；
  - 一些新特性并不完全同步；
  - 官方支持与生态组件有所不同。
- 在很多 Linux 发行版（尤其是 RHEL / CentOS / Rocky 系列）中，
  **`mysql-server` 实际上安装的是 MariaDB**，而不是 Oracle 官方的 MySQL。

### 2.1.3 MySQL 8.x 与旧版本的变化（摘录）

- 移除 **查询缓存（Query Cache）**，避免命中率低、维护开销大等问题；
- 默认字符集调整为 `utf8mb4`；
- 权限系统、安全性、JSON 支持等均有大幅增强；
- 内置性能_schema 与诊断能力更强，适合生产环境长期运行和调优。

---

## 2.2 安装与软件包

本小节重点说明：

1. 不同发行版上 **MySQL / MariaDB 软件包名的差异**；
2. 如何通过系统仓库或官方仓库安装 MySQL / MariaDB；
3. 安装完成后的基础检查与登录测试。

### 2.2.1 常见软件包与命名关系

在不同发行版中，`mysql-*` 相关软件包未必都指向 Oracle 官方 MySQL，
常见情况可以粗略总结如下表：

#### RHEL / CentOS / Rocky 系列

| 软件包名                 | 实际软件          | 说明 |
|--------------------------|-------------------|------|
| `mysql-server`           | **MariaDB Server**| 官方仓库中的兼容包名，实际安装 MariaDB |
| `mysql`                  | MariaDB Client    | MySQL 兼容命令行客户端 |
| `mysql-community-server` | **MySQL Server**  | 通过 *MySQL 官方 YUM 源* 安装的原生 MySQL |
| `mariadb-server`         | MariaDB Server    | 直接显式安装 MariaDB |

#### Debian / Ubuntu 系列

| 软件包名        | 实际软件        | 说明 |
|-----------------|-----------------|------|
| `mysql-server`  | MySQL 或 MariaDB| 根据发行版版本而定，近年偏向 MySQL 8.x |
| `mariadb-server`| MariaDB Server  | 显式安装 MariaDB |

> 在 Rocky9 等 RHEL9 系列系统上，如果直接用 `yum install mysql-server`，
> 安装的是 MariaDB，而不是官方 MySQL。要安装 Oracle 官方 MySQL，
> 应使用 `mysql-community-server` 并配置 MySQL 官方仓库。

### 2.2.2 官方仓库与镜像源

配置官方仓库可以获得**更新的版本**与**安全修复**，常用地址示例：

- MariaDB 官方源：https://mariadb.org/download/?t=repo-config
- MySQL 官方下载与 YUM 源：https://dev.mysql.com/downloads
- 国内常用镜像（举例）：
  - 阿里云 MySQL / MariaDB 镜像；
  - 清华 Tuna MySQL / MariaDB 镜像。

使用官方页面生成对应发行版的 `repo` 配置文件，然后放入
`/etc/yum.repos.d/` 或 `/etc/apt/sources.list.d/` 中即可。

> 提示：课件中的截图可能略落后于最新小版本号（例如 8.34 → 8.41），
> 原理完全一致，以实际查询到的版本信息为准。

---

## 2.2.3 使用系统软件源在 Rocky9 安装 MySQL 8.0

下面以 **Rocky Linux 9** 为例，演示如何通过系统软件源安装 MySQL 8.0
以及如何区分 MySQL 与 MariaDB。

### 2.2.3.1 更新软件源并查看可用版本

如果需要使用国内镜像（例如阿里云镜像），可以先替换 Rocky 的默认源：

```bash
sed -e 's|^mirrorlist=|#mirrorlist=|g'     -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g'     -i.bak     /etc/yum.repos.d/rocky*.repo

yum makecache
```

查看系统仓库中 `mysql` 与 `mariadb` 的情况：

```bash
[root@rocky9 ~]# yum list mysql mysql-server
mysql.x86_64        8.0.41-2.el9_5   appstream
mysql-server.x86_64 8.0.41-2.el9_5   appstream

[root@rocky9 ~]# yum list mariadb mariadb-server
mariadb.x86_64        3:10.5.27-1.el9_5 appstream
mariadb-server.x86_64 3:10.5.27-1.el9_5 appstream
```

从上面的输出可以得出几个结论：

- `mysql-server-8.0.41` 实际上是 **MariaDB 10.5 的兼容层**；
- 真正的 MySQL 官方包名应为 `mysql-community-server`（需配置 MySQL 官方仓库）；
- 在只使用系统源的前提下，更推荐直接使用 `mariadb-server`。

### 2.2.3.2 安装并启动 mysql-server（系统源版本）

> 注意：此处安装的是系统源里的 `mysql-server`，底层为 MariaDB 内核，
> 但命令与使用方式与 MySQL 基本一致，适合作为入门演示环境。

#### 1）安装软件

```bash
[root@rocky9 ~]# yum install -y mysql-server
```

安装过程中会自动拉取依赖，例如：

- `mysql`：客户端工具；
- `mysql-common`、`mysql-errmsg`：公共组件与错误信息；
- `mariadb-connector-c-config` 等：连接器与库文件。

#### 2）启动服务并设置开机自启

```bash
[root@rocky9 ~]# systemctl enable --now mysqld.service

[root@rocky9 ~]# systemctl status mysqld.service
● mysqld.service - MySQL 8.0 database server
     Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled)
     Active: active (running) ...
     Main PID: 33712 (mysqld)
```

如果看到 `Active: active (running)`，说明服务已经正常启动。

### 2.2.3.3 环境检查

#### 1）查看进程与多线程状态

```bash
[root@rocky9 ~]# pstree | grep mysql
        |-mysqld---37*[{mysqld}]
```

#### 2）查看 mysql 用户与数据目录

```bash
[root@rocky9 ~]# getent passwd mysql
mysql:x:27:27:MySQL Server:/var/lib/mysql:/sbin/nologin

[root@rocky9 ~]# ls /var/lib/mysql
auto.cnf  binlog.index  ibdata1  mysql  performance_schema  ...
```

这些文件和目录包含了 InnoDB 表空间、系统库 `mysql`、日志等数据文件。

#### 3）查看监听端口与 X Protocol

```bash
[root@rocky9 ~]# ss -tnlp | grep mysql
LISTEN 0 151 *:3306   *:* users:(("mysqld",pid=3743,fd=24))
LISTEN 0  70 *:33060 *:* users:(("mysqld",pid=3743,fd=21))
```

- `3306` 是传统的 MySQL TCP 端口；
- `33060` 是 MySQL 8.0 中的 **X Protocol** 端口，用于更现代化的客户端协议。

#### 4）登录测试并查看版本

```bash
[root@rocky9 ~]# mysql
Welcome to the MySQL monitor.  Commands end with ; or \g.
...
mysql> SELECT VERSION();
+-----------------+
| VERSION()       |
+-----------------+
| 8.0.41          |
+-----------------+
1 row in set (0.00 sec)

mysql> EXIT;
Bye
```

---

## 2.2.4 在 Rocky9 安装 MariaDB 并对比

在同一套系统上也可以安装 `mariadb-server`，用来对比行为差异。

### 2.2.4.1 安装并启动 MariaDB

```bash
[root@rocky9-15 ~]# yum install mariadb-server -y

[root@rocky9-15 ~]# systemctl enable --now mariadb
Created symlink /etc/systemd/system/mysql.service  -> mariadb.service
Created symlink /etc/systemd/system/mysqld.service -> mariadb.service
```

检查监听端口：

```bash
[root@rocky9-15 ~]# ss -tnlp | grep 3306
LISTEN 0 80 *:3306 *:* users:(("mariadbd",pid=32880,fd=19))
```

可以看到：

- 进程名变为 `mariadbd`；
- 默认只监听 `3306`，没有 `33060` 端口；
- 命令行客户端仍然叫做 `mysql`，但登录后会显示 MariaDB 的版本信息。

### 2.2.4.2 MariaDB 登录示例

```bash
[root@rocky9-15 ~]# mysql
Welcome to the MariaDB monitor.  Commands end with ; or \g.
...
MariaDB [(none)]> SELECT VERSION();
+-----------------+
| VERSION()       |
+-----------------+
| 10.5.27-MariaDB |
+-----------------+
1 row in set (0.00 sec)

MariaDB [(none)]> EXIT;
Bye
```

> 小结：在 RHEL / Rocky 系列系统上，很多情况下“mysql”命令实际上是
> 连接到 MariaDB 服务器。通过 `SELECT VERSION()` 或 `ss -tnlp` 可以
> 快速判断当前环境到底是 MySQL 还是 MariaDB。

---

## 2.2.5 在 Ubuntu 24.04 安装 MySQL 8.0（示例）

以 Ubuntu 24.04 为例，默认软件源中通常提供 MySQL 8.0 系列：

```bash
root@ubuntu24:~# apt list mysql-server
mysql-server/noble-updates,noble-security 8.0.41-0ubuntu0.24.04.1 all
```

### 2.2.5.1 安装并启动服务

```bash
root@ubuntu24:~# apt update
root@ubuntu24:~# apt install -y mysql-server

root@ubuntu24:~# systemctl status mysql
● mysql.service - MySQL Community Server
     Loaded: loaded (/lib/systemd/system/mysql.service; enabled)
     Active: active (running) ...
```

若服务启动失败且没有做过任何配置，通常是因为系统之前残留了旧版本
的数据目录或配置文件，需要先清理旧数据再重新安装。

### 2.2.5.2 基本检查

Ubuntu 上的检查思路与 Rocky 类似：

- 使用 `ss -tnlp | grep mysql` 检查监听端口；
- 查看数据目录 `/var/lib/mysql` 中的文件结构；
- 使用 `mysql` 登录并执行 `SELECT VERSION();` 确认版本号；
- 确认字符集、连接方式等是否符合预期。

---

以上就是本节 *MySQL 快速入门* 的整理版内容，
后续文档（SQL 语言、SQL 高阶语法等）会基于这里的安装环境展开。
