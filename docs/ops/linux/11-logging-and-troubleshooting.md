---
sidebar_position: 12
title: 日志与排障
---

# 11 日志与排障

## 系统日志

常见日志目录：

- `/var/log/syslog`：Ubuntu 通用系统日志。
- `/var/log/messages`：RHEL/CentOS 通用系统日志。
- `/var/log/auth.log`：认证与登录相关日志。
- `/var/log/kern.log`：内核相关日志。
- `/var/log/dmesg`：启动期内核消息。

查看方式：

```bash
sudo tail -n 200 /var/log/syslog      # 查看最近系统日志
sudo grep -i error /var/log/messages  # 搜索错误日志
sudo less /var/log/auth.log           # 分页查看认证日志
```

建议：

- 先看问题发生时间附近的日志。
- 优先定位第一条错误，不要只盯后续连锁报错。

## `journalctl`

`systemd` 日志统一入口。

```bash
journalctl -xe                                         # 查看最近的详细错误日志
journalctl -u nginx -n 100 --no-pager                  # 查看 nginx 最近 100 行日志
journalctl --since "2026-03-25 10:00:00" --until "2026-03-25 11:00:00" # 按时间范围查询
journalctl -k -n 50                                    # 查看最近内核日志
journalctl -b                                          # 查看当前启动周期日志
journalctl -f                                          # 实时追踪日志
```

实用参数：

- `-u <service>`：按服务过滤。
- `-b`：按启动周期过滤。
- `-f`：实时追踪。
- `-p err`：只看错误级别日志。

## 服务日志分析

典型方法：

1. 先看错误峰值时间段。
2. 再按请求 ID、trace ID 串联上下游。
3. 最后匹配变更记录，例如发布、配置修改、依赖升级。

常用组合：

```bash
journalctl -u myapp --since "30 min ago" | grep -E "ERROR|timeout|panic" # 过滤近期异常
grep "trace_id=abc123" app.log                                           # 按请求 ID 串联日志
awk '/ERROR/ {print $1, $2, $0}' app.log | tail                          # 提取错误时间线
```

分析重点：

- 错误首次出现时间。
- 同期是否有发布、重启、配置变更。
- 上下游依赖是否也在相同时间点报错。

## 常见问题排查

### 1) 服务启动失败

优先检查：

```bash
systemctl status <service>          # 查看服务状态和退出码
journalctl -u <service> -n 200      # 查看服务日志
ss -lntp                            # 检查端口是否被占用
```

常见原因：

- 配置语法错误。
- 端口占用。
- 权限不足。
- 依赖服务未启动。

### 2) 端口不通

优先检查：

```bash
ss -lntp                            # 查看服务是否监听
curl -v http://127.0.0.1:8080       # 测试本机访问
sudo ufw status                     # 检查防火墙
```

判断思路：

- 本机不通先查服务本身。
- 本机通、远端不通再查防火墙、安全组、路由。

### 3) 磁盘满

优先检查：

```bash
df -h                               # 查看分区使用率
du -sh /var/log/* | sort -h         # 查找大目录
lsof | grep deleted                 # 查找已删除但仍占空间的文件
```

常见原因：

- 日志未轮转。
- 临时文件堆积。
- 已删除文件仍被进程持有。

## Debug 技巧

系统状态快照：

```bash
date                                # 记录当前时间，便于对齐日志
uptime                              # 查看系统负载
free -h                             # 查看内存使用
df -h                               # 查看磁盘空间
dmesg | tail -n 50                  # 查看最近内核消息
```

方法论：

- 把问题拆成“网络、权限、资源、配置”四类。
- 每次只变更一个变量，避免混淆因果。
- 保留现场证据，例如日志片段、系统状态、时间线。
- 排障完成后沉淀 Runbook，减少重复踩坑。

## 日志轮转（`logrotate`）

日志长期不清理会直接导致磁盘风险。

常见操作：

```bash
logrotate -d /etc/logrotate.conf    # 预演轮转，不真正执行
sudo logrotate -f /etc/logrotate.conf # 强制执行一次轮转
cat /etc/logrotate.conf             # 查看全局轮转配置
ls /etc/logrotate.d/                # 查看服务级轮转规则
```

建议：

- 应用日志必须明确轮转策略。
- 轮转后要确认应用是否能继续写入新日志文件。
