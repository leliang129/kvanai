---
title: Grafana 备份迁移升级
sidebar_position: 7
---

# Grafana 备份迁移升级


## 7.1 需要备份什么

Grafana 的核心数据通常包括：

- 配置文件
- 数据库
- 插件目录
- Provisioning 配置
- Dashboard JSON 文件

常见路径：

| 路径 | 说明 |
| --- | --- |
| `/etc/grafana/grafana.ini` | 主配置文件 |
| `/etc/grafana/provisioning` | Provisioning 配置 |
| `/var/lib/grafana` | 默认数据目录 |
| `/var/lib/grafana/grafana.db` | SQLite 默认数据库 |
| `/var/lib/grafana/plugins` | 插件目录 |

## 7.2 数据库类型

Grafana 支持多种数据库后端：

| 类型 | 说明 |
| --- | --- |
| SQLite | 默认内置，适合小规模 |
| MySQL | 常见生产方案 |
| PostgreSQL | 常见生产方案 |

备份策略取决于数据库类型。

## 7.3 SQLite 备份

如果使用默认 SQLite，最关键的是备份 `grafana.db`。

建议步骤：

1. 停止 Grafana。
2. 备份配置和数据库文件。
3. 备份 provisioning 和 dashboard JSON。

示例：

```bash
systemctl stop grafana-server  # 停止 Grafana 服务
mkdir -p /backup/grafana/$(date +%F)  # 创建备份目录
cp -a /etc/grafana /backup/grafana/$(date +%F)/  # 备份 Grafana 配置目录
cp -a /var/lib/grafana/grafana.db /backup/grafana/$(date +%F)/  # 备份 SQLite 数据库文件
cp -a /var/lib/grafana/plugins /backup/grafana/$(date +%F)/  # 备份插件目录
systemctl start grafana-server  # 启动 Grafana 服务
```

注意：

- 在线直接复制 SQLite 文件有一致性风险。
- 更稳妥的方式是停服务后备份，或基于文件系统快照。

## 7.4 MySQL / PostgreSQL 备份

如果 Grafana 使用外部数据库，Grafana 本身配置目录仍要备份，但业务数据主要靠数据库备份。

MySQL 示例：

```bash
mysqldump -u root -p grafana > /backup/grafana/grafana-$(date +%F).sql  # 导出 Grafana MySQL 数据库
cp -a /etc/grafana /backup/grafana/$(date +%F)/  # 备份 Grafana 配置目录
```

PostgreSQL 示例：

```bash
pg_dump -U postgres grafana > /backup/grafana/grafana-$(date +%F).sql  # 导出 Grafana PostgreSQL 数据库
cp -a /etc/grafana /backup/grafana/$(date +%F)/  # 备份 Grafana 配置目录
```

## 7.5 Docker 部署备份

如果 Grafana 跑在 Docker 或 Compose 中，核心仍是备份：

- 数据卷
- 配置挂载目录
- provisioning 文件
- dashboard JSON

示例：

```bash
docker compose stop grafana  # 停止 Grafana 容器
docker run --rm -v grafana_data:/data -v $(pwd):/backup busybox tar czf /backup/grafana-data-$(date +%F).tar.gz /data  # 备份 Grafana 数据卷
tar czf grafana-config-$(date +%F).tar.gz provisioning dashboards docker-compose.yml  # 备份本地配置和 Dashboard 文件
docker compose start grafana  # 启动 Grafana 容器
```

## 7.6 恢复流程

SQLite 恢复思路：

1. 停止 Grafana。
2. 恢复配置目录。
3. 恢复 `grafana.db`。
4. 恢复插件目录。
5. 修复权限。
6. 启动 Grafana。

示例：

```bash
systemctl stop grafana-server  # 停止 Grafana 服务
cp -a /backup/grafana/2026-05-06/grafana.ini /etc/grafana/  # 恢复 Grafana 主配置
cp -a /backup/grafana/2026-05-06/grafana.db /var/lib/grafana/  # 恢复 SQLite 数据库文件
cp -a /backup/grafana/2026-05-06/plugins /var/lib/grafana/  # 恢复插件目录
chown -R grafana:grafana /etc/grafana /var/lib/grafana  # 修正目录权限
systemctl start grafana-server  # 启动 Grafana 服务
```

## 7.7 迁移到新机器

迁移通常需要这些内容：

- 复制配置目录
- 迁移数据库
- 恢复插件
- 保持版本一致或先做兼容验证
- 校验 `root_url`、域名和反向代理配置

建议：

- 迁移前先记录当前 Grafana 版本。
- 新旧环境尽量保持同版本。
- 插件兼容性单独验证。

## 7.8 升级建议

升级原则：

- 先备份，再升级。
- 先看官方 release notes。
- 生产环境先在测试环境验证。
- 核心风险在数据库迁移和插件兼容。

升级前建议备份：

- `grafana.ini`
- provisioning
- `grafana.db` 或外部数据库
- 插件目录

检查版本：

```bash
grafana-server -v  # 查看 Grafana 版本
grafana-cli plugins ls  # 查看当前已安装插件
```

## 7.9 常见问题

### 7.9.1 恢复后页面能打开但数据源丢失

常见原因：

- 只恢复了 Dashboard，没有恢复数据库。
- Provisioning 文件没有挂载。
- 恢复到了错误的 Organization。

### 7.9.2 升级后插件不可用

常见原因：

- 插件版本不兼容。
- 插件未签名或签名校验失败。
- 升级后插件目录未恢复。

### 7.9.3 迁移后登录地址异常

常见原因：

- `domain` 未更新。
- `root_url` 未更新。
- Nginx 或反向代理未同步修改。

## 7.10 参考资料

- [Grafana Backup and Restore](https://grafana.com/docs/grafana/latest/administration/back-up-grafana/)
- [Grafana Upgrade Guide](https://grafana.com/docs/grafana/latest/upgrade-guide/)
- [Grafana Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
