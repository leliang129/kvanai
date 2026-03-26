---
sidebar_position: 7
title: 进程与系统管理
---

# 06 进程与系统管理

## `ps/top/htop`

查看进程快照：

```bash
ps -ef                                   # 以标准格式查看全部进程
ps aux | grep nginx                      # 查找指定进程
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head # 按 CPU 排序查看热点进程
pstree -p                                # 查看进程树和父子关系
```

实时观察：

```bash
top                                      # 实时查看系统负载和进程
htop                                     # 更友好的交互式视图
free -h                                  # 查看内存使用
uptime                                   # 查看负载和运行时长
```

核心关注指标：

- CPU 占用。
- 内存占用和 Swap 使用。
- 系统负载 `load average`。
- 进程状态，例如 `R`、`S`、`D`、`Z`。

## `kill`

发送信号控制进程：

```bash
kill <pid>        # 默认发送 SIGTERM(15)，请求进程优雅退出
kill -9 <pid>     # 发送 SIGKILL(9)，强制终止
kill -HUP <pid>   # 常用于通知进程重载配置
pkill nginx       # 按进程名发送信号
kill -l           # 查看可用信号列表
```

建议顺序：

- 先 `TERM`，给应用清理资源和落盘机会。
- 确认无响应时再使用 `KILL`。
- 如果进程频繁起不来，优先排查日志而不是反复 `kill -9`。

## 后台任务（`&`/`nohup`）

```bash
./task.sh &                          # 放到后台执行，但仍关联当前会话
nohup ./task.sh > task.log 2>&1 &    # 退出终端后继续运行
jobs -l                              # 查看当前 shell 的后台任务
fg %1                                # 把任务切回前台
bg %1                                # 让挂起任务继续在后台运行
disown -h %1                         # 让任务脱离当前 shell
```

说明：

- `&` 适合临时后台任务。
- `nohup` 适合关闭终端后仍需继续运行的任务。
- 长期运行任务更建议交给 `systemd` 或调度系统管理。

## 进程调度

优先级管理：

```bash
nice -n 10 ./batch-job.sh   # 以较低优先级启动任务
renice -n 5 -p <pid>        # 调整运行中进程优先级
```

定时任务（cron）：

```bash
crontab -e                  # 编辑当前用户定时任务
crontab -l                  # 查看当前用户定时任务
systemctl status cron       # 查看 cron 服务状态
```

示例：每天 2:30 备份。

```cron
30 2 * * * /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1
```

实战建议：

- 长任务要加超时控制与告警。
- 定时任务要记录开始时间、结束时间和结果。
- `cron` 中环境变量较少，脚本里尽量使用绝对路径。

## 系统状态排查

常见观察命令：

```bash
vmstat 1 5                 # 观察 CPU、内存、IO 等趋势
iostat -xz 1 3             # 观察磁盘 IO 情况
dmesg | tail -n 50         # 查看最近内核消息
lsof -p <pid> | head       # 查看进程打开的文件和连接
```

排障思路：

- CPU 高先看热点进程和线程。
- 内存高先看 RSS、缓存和是否发生 OOM。
- 磁盘卡先看 IO 等待和设备延迟。
- 进程异常退出先看日志，再看内核信息和资源限制。
