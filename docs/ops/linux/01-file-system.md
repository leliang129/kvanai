---
sidebar_position: 2
title: 文件系统
---

# 01 文件系统

## 路径（绝对/相对）

- 绝对路径：从根目录 `/` 开始，例如 `/etc/nginx/nginx.conf`。
- 相对路径：相对当前工作目录，例如 `../logs/app.log`。

常用路径命令：

```bash
pwd                    # 查看当前目录
cd /var/log            # 切换到指定绝对路径
cd ..                  # 返回上一级目录
cd -                   # 返回上一次所在目录
realpath ./app.log     # 查看文件绝对路径
dirname /etc/ssh/sshd_config # 取目录部分
basename /etc/ssh/sshd_config # 取文件名部分
```

建议：

- 脚本中尽量使用绝对路径，减少上下文变化导致的问题。
- 执行删除、移动、覆盖操作前，先用 `pwd` 和 `ls` 确认当前路径。

## 文件类型

Linux 中“万物皆文件”，常见类型包括：

- 普通文件（`-`）
- 目录（`d`）
- 符号链接（`l`）
- 字符设备（`c`）
- 块设备（`b`）
- 套接字（`s`）
- 管道（`p`）

查看文件类型：

```bash
ls -l                # 查看目录项及文件类型标记
file /bin/ls         # 识别文件真实类型
stat /etc/passwd     # 查看文件详细元数据
find /dev -maxdepth 1 -type b | head # 查看块设备示例
```

判断思路：

- `ls -l` 适合快速看目录结构。
- `file` 适合判断一个文件到底是文本、二进制还是压缩包。
- `stat` 适合看权限、时间、inode、链接数等元信息。

## 软链接 vs 硬链接

软链接（symbolic link）：

- 本质是“路径引用”，类似快捷方式。
- 可以跨文件系统。
- 原文件删除后软链接失效。

硬链接（hard link）：

- 多个文件名指向同一 inode。
- 不能跨文件系统，通常也不能链接目录。
- 删除某个文件名不影响其他硬链接访问。

命令示例：

```bash
ln /data/app.log app.log.hard     # 创建硬链接
ln -s /data/app.log app.log.soft  # 创建软链接
ls -li app.log.*                  # 对比 inode 和链接关系
readlink -f app.log.soft          # 查看软链接最终指向
```

选择建议：

- 做“快捷入口”优先用软链接。
- 需要同一文件多个目录名引用时，可考虑硬链接。
- 运维脚本中删除文件前，先确认它是否被其他链接引用。

## inode 机制

inode 存储文件元数据，例如权限、属主、大小、时间戳、数据块指针；文件名本身存储在目录项里。

要点：

- 文件名 -> inode -> 数据块。
- 同一个 inode 可能对应多个文件名，典型场景就是硬链接。
- 磁盘“空间没满但无法创建文件”常见原因之一是 inode 耗尽。

排查命令：

```bash
ls -li /var/log              # 查看 inode 编号
df -h                        # 查看磁盘容量使用率
df -i                        # 查看 inode 使用率
find /var/tmp -xdev -type f | wc -l # 统计目录中文件数量
```

实战建议：

- 日志切分、缓存目录、消息堆积目录要关注“小文件爆炸”问题。
- 定期清理临时文件和历史归档，避免 inode 被大量小文件占满。
- 清理前优先定位目录，不要直接全盘 `find / -delete`。

## 文件元数据与时间戳

Linux 文件常见时间戳：

- `mtime`：内容最后修改时间。
- `ctime`：元数据最后变化时间，例如权限变化。
- `atime`：最后访问时间。

查看与筛选：

```bash
stat app.log                      # 查看详细时间戳
find /var/log -type f -mtime -1  # 查找最近 1 天内修改过的文件
find /data -type f -size +1G      # 查找大于 1G 的文件
touch test.txt                    # 创建文件或更新文件时间戳
```

排障价值：

- 发布后判断配置文件是否真的被改过。
- 排查日志文件是否长期没有更新。
- 查找近期突增的大文件或异常生成文件。
