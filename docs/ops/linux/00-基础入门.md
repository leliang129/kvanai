---
sidebar_position: 1
title: 基础入门
---

# 00 基础入门

## Linux 简介

Linux 是一个类 Unix 操作系统内核，常见发行版通常由 Linux 内核、GNU 用户态工具、包管理器和服务管理组件共同组成。

运维工作中，Linux 主要承担：

- 服务运行平台，例如 Web、数据库、缓存、消息队列、Kubernetes 节点。
- 自动化脚本执行环境，例如发布脚本、巡检脚本、备份脚本。
- 网络与存储管理控制面，例如路由、挂载、权限、日志、监控代理。

核心特点：

- 多用户、多任务，适合服务器并发场景。
- 权限模型清晰，便于隔离服务和用户权限。
- 工具链丰富，很多问题可直接通过命令行定位。
- 文本配置普遍，适合自动化和版本管理。

## 常见发行版（Ubuntu/CentOS/Alpine）

| 发行版 | 特点 | 典型场景 |
| --- | --- | --- |
| Ubuntu | 社区活跃、文档多、`apt` 生态好 | 开发机、通用服务器 |
| CentOS/RHEL 系 | 企业常见、稳定、`yum/dnf` 生态成熟 | 传统企业生产环境 |
| Alpine | 体积小、镜像轻、默认组件少 | 容器镜像、轻量运行时 |

选型建议：

- 通用场景优先 Ubuntu LTS 或 RHEL 兼容发行版。
- 容器镜像可以考虑 Alpine，但要留意 `musl libc` 与 `glibc` 的兼容差异。
- 如果团队长期使用同一类发行版，优先统一，减少脚本和运维手册分叉。

## 安装与环境准备

最小安装后建议立即完成以下初始化。

Ubuntu / Debian：

```bash
sudo apt update                      # 刷新软件源索引
sudo apt -y upgrade                  # 升级已安装软件包
sudo adduser devops                  # 创建普通用户
sudo usermod -aG sudo devops         # 把用户加入 sudo 组
sudo timedatectl set-timezone Asia/Shanghai # 设置时区
sudo timedatectl set-ntp true        # 启用 NTP 时间同步
sudo apt install -y curl wget vim git htop net-tools unzip # 安装基础工具
```

RHEL / Rocky / AlmaLinux：

```bash
sudo dnf update -y                   # 更新系统软件包
sudo useradd -m -s /bin/bash devops  # 创建普通用户
sudo passwd devops                   # 设置用户密码
sudo usermod -aG wheel devops        # 把用户加入管理员组
sudo timedatectl set-timezone Asia/Shanghai # 设置时区
sudo timedatectl set-ntp true        # 启用 NTP 时间同步
sudo dnf install -y curl wget vim git htop net-tools unzip # 安装基础工具
```

环境基线建议：

- 禁止直接使用 root 远程登录。
- 保持系统时间同步，日志、证书、分布式服务都依赖准确时间。
- 统一 Shell 与编辑器习惯，例如 `bash + vim`。
- 新机器初始化后先做一次基线检查，再交付业务使用。

## 终端基础

常见终端操作：

- 历史命令：`history`
- 自动补全：`Tab`
- 反向搜索：`Ctrl + r`
- 中断当前命令：`Ctrl + c`
- 后台挂起：`Ctrl + z`
- 清屏：`Ctrl + l`

常用帮助命令：

```bash
man systemctl     # 查看命令手册
ls --help         # 查看命令简要帮助
which bash        # 查看命令所在路径
type cd           # 判断命令是内建命令、别名还是外部程序
history | tail    # 查看最近执行的命令
```

推荐别名（写入 `~/.bashrc`）：

```bash
alias ll='ls -alF'              # 以长格式列出文件
alias grep='grep --color=auto'  # 匹配结果高亮
alias ..='cd ..'                # 快速返回上一级目录
alias cls='clear'               # 清屏
```

## 系统信息快速检查

登录新机器后，建议先确认以下信息：

```bash
whoami                 # 当前登录用户
hostnamectl            # 主机名、系统版本、内核版本
cat /etc/os-release    # 发行版信息
uname -r               # 内核版本
uptime                 # 运行时长与系统负载
free -h                # 内存使用情况
df -h                  # 磁盘容量使用情况
ip addr                # 网卡与 IP 信息
```

排查习惯：

- 先确认机器身份，再执行有风险的变更。
- 先看系统版本和包管理器，再决定用 `apt`、`yum` 还是 `dnf`。
- 先看负载、内存、磁盘，再判断问题是资源类还是配置类。

## 目录结构（`/etc` `/var` `/home`）

- `/etc`：系统与服务配置文件目录，例如 `sshd_config`、`nginx.conf`。
- `/var`：可变数据目录，例如日志、缓存、数据库数据。
- `/home`：普通用户家目录。
- `/usr`：用户态程序与库。
- `/opt`：可选软件安装目录，第三方应用常见。
- `/srv`：站点或服务对外提供的数据目录。
- `/tmp`：临时文件目录，系统可能定期清理。

目录定位示例：

```bash
cd /etc                    # 进入系统配置目录
ls /var/log                # 查看日志目录内容
du -sh /home/*             # 查看各用户家目录占用
find /opt -maxdepth 2 -type f | head # 查看第三方软件常见文件
```

实战原则：

- 配置看 `/etc`，数据看 `/var`，用户脚本看 `/home/<user>`。
- 应用安装目录和数据目录尽量分离，便于升级和备份。
- 改配置前先备份：`sudo cp file{,.bak.$(date +%F-%H%M%S)}`。
