---
title: Grafana Provisioning
sidebar_position: 3
---

# Grafana Provisioning


## 3.1 Provisioning 作用

Grafana Provisioning 用于把数据源、Dashboard、目录等配置从“页面手工操作”变成“文件声明式管理”。

适合场景：

- 多环境统一初始化 Grafana。
- 面板和数据源纳入 Git 管理。
- 容器化部署后自动完成初始化。
- 避免人工点点点造成配置漂移。

常见管理对象：

- Data sources
- Dashboards
- Dashboard providers

## 3.2 默认目录

Grafana Provisioning 默认目录：

| 路径 | 说明 |
| --- | --- |
| `/etc/grafana/provisioning/datasources` | 数据源配置目录 |
| `/etc/grafana/provisioning/dashboards` | Dashboard provider 配置目录 |
| `/var/lib/grafana/dashboards` | 常见的 Dashboard JSON 挂载目录 |

推荐目录结构：

```text
grafana
├── docker-compose.yml
├── provisioning
│   ├── datasources
│   │   └── prometheus.yml
│   └── dashboards
│       └── dashboards.yml
└── dashboards
    ├── node-overview.json
    └── prometheus-overview.json
```

## 3.3 数据源 Provisioning

Prometheus 数据源示例：

```yaml title="provisioning/datasources/prometheus.yml"
apiVersion: 1  # Grafana provisioning API 版本

datasources:  # 数据源列表
  - name: Prometheus  # 数据源名称
    type: prometheus  # 数据源类型
    access: proxy  # 由 Grafana 服务端代理访问数据源
    url: http://prometheus:9090  # Prometheus 访问地址
    isDefault: true  # 设置为默认数据源
    editable: true  # 允许在 Grafana 页面中修改
```

字段说明：

| 字段 | 说明 |
| --- | --- |
| `apiVersion` | Provisioning 文件版本 |
| `datasources` | 数据源列表 |
| `name` | 数据源名称 |
| `type` | 数据源类型 |
| `access` | 访问模式，常用 `proxy` |
| `url` | 数据源访问地址 |
| `isDefault` | 是否默认数据源 |
| `editable` | 页面中是否允许编辑 |

## 3.4 多数据源示例

```yaml title="provisioning/datasources/datasources.yml"
apiVersion: 1  # Grafana provisioning API 版本

datasources:  # 数据源列表
  - name: Prometheus-prod  # 生产环境 Prometheus 数据源名称
    type: prometheus  # 数据源类型
    access: proxy  # 由 Grafana 服务端代理访问
    url: http://prometheus-prod:9090  # 生产环境 Prometheus 地址
    isDefault: true  # 设为默认数据源
    editable: false  # 页面中不允许随意修改

  - name: Prometheus-test  # 测试环境 Prometheus 数据源名称
    type: prometheus  # 数据源类型
    access: proxy  # 由 Grafana 服务端代理访问
    url: http://prometheus-test:9090  # 测试环境 Prometheus 地址
    editable: false  # 页面中不允许随意修改
```

建议：

- 生产和测试分成不同数据源。
- 正式环境建议 `editable: false`，减少手工漂移。
- 数据源名称保持统一命名规则，如 `Prometheus-prod`、`Prometheus-test`。

## 3.5 Dashboard Provider

Dashboard Provider 用于告诉 Grafana 去哪里加载 JSON Dashboard 文件。

示例：

```yaml title="provisioning/dashboards/dashboards.yml"
apiVersion: 1  # Grafana provisioning API 版本

providers:  # Dashboard provider 列表
  - name: default  # provider 名称
    orgId: 1  # 所属组织 ID
    folder: Platform  # 导入到 Grafana 中的目录名称
    type: file  # 从文件系统加载 Dashboard
    disableDeletion: false  # 删除文件后允许 Grafana 删除对应 Dashboard
    updateIntervalSeconds: 30  # 每 30 秒扫描一次文件变更
    allowUiUpdates: false  # 不允许在页面修改后覆盖文件管理状态
    options:  # provider 额外参数
      path: /var/lib/grafana/dashboards  # Dashboard JSON 文件所在目录
```

字段说明：

| 字段 | 说明 |
| --- | --- |
| `providers` | Dashboard provider 列表 |
| `name` | provider 名称 |
| `orgId` | 组织 ID |
| `folder` | Dashboard 所属目录 |
| `type` | 常用为 `file` |
| `disableDeletion` | 是否禁止随着文件删除而删除 Dashboard |
| `updateIntervalSeconds` | 扫描文件变更周期 |
| `allowUiUpdates` | 页面修改是否允许保留 |
| `options.path` | JSON 文件路径 |

## 3.6 Dashboard JSON 管理

将 Dashboard JSON 放入挂载目录，例如：

```text
/var/lib/grafana/dashboards/node-overview.json
/var/lib/grafana/dashboards/prometheus-overview.json
```

来源通常有两种：

1. 从社区 Dashboard 导入后再导出 JSON。
2. 在本地 Grafana 调整完成后导出 JSON 纳入 Git。

建议：

- 导入社区 Dashboard 后先裁剪，再入库。
- JSON 文件名和 Dashboard 名称保持对应。
- 每个系统单独一个 JSON，避免一个文件过大。

## 3.7 Docker Compose 挂载示例

```yaml title="docker-compose.yml"
services:  # Compose 服务列表
  grafana:  # Grafana 服务
    image: grafana/grafana:12.3.0  # 使用固定版本 Grafana 镜像
    container_name: grafana  # 容器名称
    restart: unless-stopped  # 容器异常退出后自动重启，手动停止除外
    ports:  # 端口映射
      - "3000:3000"  # 暴露 Grafana Web 端口
    volumes:  # 挂载配置和 Dashboard 文件
      - ./provisioning/datasources:/etc/grafana/provisioning/datasources:ro  # 只读挂载数据源配置
      - ./provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro  # 只读挂载 Dashboard provider 配置
      - ./dashboards:/var/lib/grafana/dashboards:ro  # 只读挂载 Dashboard JSON 文件
      - grafana_data:/var/lib/grafana  # 持久化 Grafana 自身数据

volumes:  # Compose 数据卷定义
  grafana_data:  # Grafana 数据卷
```

启动：

```bash
docker compose up -d  # 后台启动 Grafana
docker compose logs -f grafana  # 查看 Grafana 启动日志
```

## 3.8 生效方式

Provisioning 文件通常在 Grafana 启动时加载。

常见处理方式：

- 容器场景：修改文件后重建或重启容器。
- systemd 场景：修改文件后重启 Grafana 服务。
- Dashboard provider 会周期性扫描 JSON 文件变化，但数据源配置通常以重启最稳妥。

重启命令：

```bash
systemctl restart grafana-server  # 重启 Grafana 服务
systemctl status grafana-server  # 查看服务状态
```

## 3.9 Git 管理建议

推荐做法：

- `provisioning/` 和 `dashboards/` 目录纳入 Git。
- 生产和测试环境按目录或文件拆分。
- Dashboard JSON 变更走 PR 审核。
- 社区导入的 JSON 先清理无关变量和无用面板。

常见拆分方式：

```text
dashboards
├── platform
│   ├── node-overview.json
│   └── prometheus-overview.json
├── middleware
│   ├── kafka-overview.json
│   └── redis-overview.json
└── application
    └── service-overview.json
```

## 3.10 常见问题

### 3.10.1 数据源没有自动出现

排查：

```bash
docker exec -it grafana ls -R /etc/grafana/provisioning  # 检查容器内 provisioning 文件是否挂载成功
docker exec -it grafana cat /etc/grafana/provisioning/datasources/prometheus.yml  # 检查数据源配置内容
docker compose logs -f grafana  # 查看 Grafana 启动和加载日志
```

常见原因：

- 挂载路径错误。
- YAML 格式错误。
- 文件权限不对。
- 容器没有重启。

### 3.10.2 Dashboard 没有自动加载

排查：

```bash
docker exec -it grafana ls -R /var/lib/grafana/dashboards  # 检查 Dashboard JSON 是否挂载成功
docker exec -it grafana cat /etc/grafana/provisioning/dashboards/dashboards.yml  # 检查 provider 配置
docker compose logs -f grafana  # 查看 Dashboard 加载日志
```

常见原因：

- `options.path` 写错。
- JSON 文件格式不合法。
- Provider 文件未加载。
- `orgId` 不匹配。

### 3.10.3 页面改了 Dashboard，但重启后丢失

原因：

- Dashboard 来源于 provisioning 文件。
- `allowUiUpdates: false` 时，页面修改不会反写到文件。

建议：

- 页面修改后重新导出 JSON。
- 把更新后的 JSON 提交回 Git。
- 不要把“页面临时改动”当成最终配置源。

## 3.11 参考资料

- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Grafana Data Sources Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources)
- [Grafana Dashboards Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards)
