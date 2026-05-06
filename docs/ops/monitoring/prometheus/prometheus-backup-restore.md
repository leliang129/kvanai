---
title: Prometheus 备份与恢复
sidebar_position: 14
---

# Prometheus 备份与恢复


## 12.1 Prometheus 能不能备份

可以备份，但要先明确边界。

Prometheus 适合做：

- 本地 TSDB 的短中期数据备份
- 单实例故障后的历史数据恢复
- 配置、规则、targets 文件的备份

Prometheus 不适合作为：

- 长期历史归档的唯一方案
- 跨机房容灾的唯一方案
- 多副本强一致存储方案

如果目标是长期留存或统一查询，还是应该配合：

- Thanos
- VictoriaMetrics
- Grafana Mimir
- Cortex

## 12.2 需要备份什么

建议至少备份：

| 路径 | 说明 |
| --- | --- |
| `/etc/prometheus/prometheus.yml` | 主配置文件 |
| `/etc/prometheus/rules` | 告警规则和 recording rules |
| `/etc/prometheus/targets` | file_sd_configs 目标文件 |
| `/var/lib/prometheus` | TSDB 数据目录 |

如果只备份配置，不备份 TSDB，就只能恢复采集逻辑，不能恢复历史数据。

## 12.3 备份方式选择

常见方式：

| 方式 | 说明 | 推荐度 |
| --- | --- | --- |
| TSDB Snapshot | Prometheus 原生快照接口 | 推荐 |
| 文件系统快照 | LVM / 云盘快照 | 推荐 |
| 直接复制数据目录 | 风险较高，容易不一致 | 不推荐在线使用 |

建议：

- 在线备份优先使用 TSDB Snapshot。
- 大规模生产环境优先使用底层存储快照。
- 不要在线直接 `cp -a /var/lib/prometheus` 当成标准方案。

## 12.4 启用 Snapshot 能力

Prometheus 创建 TSDB 快照需要启用 admin API。

启动参数示例：

```text
--web.enable-admin-api
```

注意：

- 开启后要限制访问来源。
- 不要直接暴露到公网。

## 12.5 TSDB Snapshot 备份

创建快照：

```bash
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot  # 创建 Prometheus TSDB 快照
ls -lh /var/lib/prometheus/snapshots  # 查看快照目录
```

常见快照目录：

```text
/var/lib/prometheus/snapshots/20260506T120000Z-xxxxxxxx
```

备份快照和配置：

```bash
SNAPSHOT_DIR=$(ls -dt /var/lib/prometheus/snapshots/* | head -n 1)  # 获取最新快照目录
mkdir -p /backup/prometheus/$(date +%F)  # 创建备份目录
cp -a /etc/prometheus /backup/prometheus/$(date +%F)/  # 备份 Prometheus 配置目录
cp -a "$SNAPSHOT_DIR" /backup/prometheus/$(date +%F)/  # 备份最新 TSDB 快照
```

## 12.6 停机文件备份

如果不能使用 Snapshot，也可以停机后复制数据目录。

示例：

```bash
systemctl stop prometheus  # 停止 Prometheus 服务
mkdir -p /backup/prometheus/$(date +%F)  # 创建备份目录
cp -a /etc/prometheus /backup/prometheus/$(date +%F)/  # 备份 Prometheus 配置目录
cp -a /var/lib/prometheus /backup/prometheus/$(date +%F)/  # 备份 Prometheus 数据目录
systemctl start prometheus  # 启动 Prometheus 服务
```

缺点：

- 会有服务中断。
- 数据目录较大时备份耗时长。

## 12.7 恢复流程

恢复思路：

1. 停止 Prometheus。
2. 备份当前数据目录。
3. 恢复配置文件。
4. 恢复快照或数据目录。
5. 修复权限。
6. 启动 Prometheus 并检查日志。

Snapshot 恢复示例：

```bash
systemctl stop prometheus  # 停止 Prometheus 服务
mv /var/lib/prometheus /var/lib/prometheus.bak  # 备份当前数据目录
mkdir -p /var/lib/prometheus  # 创建新的数据目录
cp -a /backup/prometheus/2026-05-06/20260506T120000Z-xxxxxxxx/* /var/lib/prometheus/  # 恢复 TSDB 快照数据
cp -a /backup/prometheus/2026-05-06/prometheus /etc/  # 恢复 Prometheus 配置目录
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus  # 修复目录权限
systemctl start prometheus  # 启动 Prometheus 服务
```

## 12.8 恢复后检查

检查项：

- Prometheus 服务能否启动。
- `/targets` 是否正常。
- 历史数据是否可查询。
- 告警规则是否正常加载。

常用命令：

```bash
systemctl status prometheus  # 查看 Prometheus 服务状态
journalctl -u prometheus -n 200 --no-pager  # 查看最近服务日志
curl http://localhost:9090/-/ready  # 检查 Prometheus 是否 ready
curl http://localhost:9090/api/v1/rules  # 检查规则是否正常加载
```

## 12.9 生产建议

- 配置文件纳入 Git。
- TSDB 快照定期执行。
- 数据目录独立磁盘。
- 长期保留交给远端存储，不靠单机 Prometheus。
- 恢复流程至少做一次演练。

## 12.10 常见问题

### 12.10.1 直接复制 `/var/lib/prometheus` 可以吗

可以停机后复制。

如果在线直接复制，容易拿到不一致数据，不建议作为标准做法。

### 12.10.2 Snapshot 能不能替代长期存储

不能。

Snapshot 更适合故障恢复，不适合当长期归档系统。

### 12.10.3 恢复后历史数据缺一段

常见原因：

- 快照创建时间点之后的新数据未包含。
- 误删了 block。
- 恢复时复制了错误快照目录。

## 12.11 参考资料

- [Prometheus Storage](https://prometheus.io/docs/prometheus/latest/storage/)
- [Prometheus Snapshot API](https://prometheus.io/docs/prometheus/latest/querying/api/#tsdb-admin-apis)
- [Promtool TSDB](https://prometheus.io/docs/prometheus/latest/command-line/promtool/)
