---
sidebar_position: 0
title: Linux 学习路径总览
---

# Linux 学习路径总览

这套文档按「基础认知 -> 日常操作 -> 运维实战」组织，适合开发/运维工程师快速建立 Linux 体系化能力。

## 章节地图

- [00-基础入门](./00-linux-basics.md)：Linux 简介、发行版、安装环境、终端与目录结构。
- [01-文件系统](./01-file-system.md)：路径、文件类型、链接、inode。
- [02-常用命令](./02-common-commands.md)：文件、查找、查看、压缩、磁盘。
- [03-权限与用户](./03-permissions-and-users.md)：rwx、chmod/chown、sudo、用户组。
- [04-文本处理](./04-text-processing.md)：grep/awk/sed/sort/uniq，管道与重定向。
- [05-包管理工具](./05-package-management.md)：apt/dnf/yum/zypper/apk/pacman/pkg/brew 与常见运维操作。
- [06-Shell编程](./06-shell-programming.md)：语法、变量、流程控制、函数、参数。
- [07-进程与系统管理](./07-process-and-system-management.md)：ps/top/kill/后台任务/调度。
- [08-服务管理](./08-service-management.md)：systemctl、service、自定义 service。
- [09-网络](./09-networking.md)：TCP/IP、curl/wget、端口连接、DNS、防火墙。
- [10-存储与文件系统](./10-storage-and-file-systems.md)：挂载、分区、ext4/xfs、LVM。
- [11-日志与排障](./11-logging-and-troubleshooting.md)：journalctl、服务日志、排障套路。
- [12-安全](./12-security.md)：账户安全、SSH、防火墙、权限、Fail2ban。
- [13-开发环境](./13-development-environment.md)：Git、gcc/make、环境变量、apt/yum。

## 建议学习顺序

1. 先完成 00-04，建立基础命令与文本处理能力。
2. 再学 05-09，把包管理、脚本、进程、服务和网络串起来。
3. 最后学 10-13，把存储、排障、安全、工具链补齐。

## 使用方式

- 遇到线上问题时，优先看 07、09、11、12。
- 做自动化改造时，重点看 04、05、06、13。
- 做基础设施规划时，重点看 03、10、12。
