---
title: Prometheus 安装部署
sidebar_position: 2
---

# Prometheus 安装部署


## 2.1 安装方式说明

Prometheus 常见部署方式：

| 方式 | 说明 | 适用场景 |
| --- | --- | --- |
| 二进制包 + systemd | 官方包直接部署，结构清晰 | VM / 物理机生产部署 |
| Docker / Compose | 容器化启动，维护简单 | 测试、小规模环境 |
| Kubernetes / Operator | Prometheus Operator 管理 | Kubernetes 生产环境 |
| Helm Chart | 基于 kube-prometheus-stack 快速部署 | 云原生监控栈 |

本文以 **二进制包 + systemd** 为主，同时给出 Docker Compose 示例。

## 2.2 组件说明

常见组件：

| 组件 | 说明 |
| --- | --- |
| Prometheus | 指标采集、存储、查询和规则计算 |
| Node Exporter | 主机 CPU、内存、磁盘、网络指标 |
| Alertmanager | 告警分组、抑制、路由和通知 |
| Grafana | 指标可视化 |
| Blackbox Exporter | HTTP、TCP、ICMP 探测 |
| Pushgateway | 短生命周期任务推送指标 |

最小可用安装：

```text
Prometheus + Node Exporter
```

生产常用组合：

```text
Prometheus + Alertmanager + Grafana + Node Exporter + 业务 Exporter
```

## 2.3 环境准备

建议配置：

- 测试环境：`CPU 2C+`、内存 `2G+`、磁盘 `20G+`。
- 生产环境：按采集目标数、指标基数、保留时间和查询压力评估。
- Prometheus 数据目录建议独立磁盘。

创建用户和目录：

```bash
useradd -r -s /sbin/nologin prometheus  # 创建 Prometheus 系统用户

mkdir -p /etc/prometheus  # 创建配置目录
mkdir -p /var/lib/prometheus  # 创建数据目录
mkdir -p /opt/prometheus  # 创建安装目录

chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus /opt/prometheus  # 授权目录给 prometheus 用户
```

安装基础工具：

```bash
# Ubuntu / Debian
apt update  # 更新软件源
apt install -y wget tar curl  # 安装下载、解压和测试工具

# RHEL / Rocky / AlmaLinux
dnf install -y wget tar curl  # 安装下载、解压和测试工具
```

## 2.4 下载与安装 Prometheus

下载：

```bash
cd /opt  # 进入安装目录
wget https://github.com/prometheus/prometheus/releases/download/v3.11.2/prometheus-3.11.2.linux-amd64.tar.gz  # 下载 Prometheus 二进制包
tar zxf prometheus-3.11.2.linux-amd64.tar.gz  # 解压缩安装包
ln -s prometheus-3.11.2.linux-amd64 prometheus  # 创建稳定软连接，便于后续升级切换
```

复制文件：

```bash
cp /opt/prometheus/prometheus /usr/local/bin/  # 复制 Prometheus 主程序到 PATH
cp /opt/prometheus/promtool /usr/local/bin/  # 复制 promtool 校验工具到 PATH
cp -r /opt/prometheus/consoles /etc/prometheus/  # 复制控制台模板
cp -r /opt/prometheus/console_libraries /etc/prometheus/  # 复制控制台依赖库

chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus  # 修正配置和数据目录权限
```

检查版本：

```bash
prometheus --version  # 查看 Prometheus 版本
promtool --version  # 查看 promtool 版本
```

说明：

- 版本号按实际需要选择，生产环境建议固定版本。
- 最新版本以 [Prometheus Download](https://prometheus.io/download/) 为准。

## 2.5 Prometheus 配置

创建配置文件：

```bash
# 写入 Prometheus 主配置文件
cat > /etc/prometheus/prometheus.yml <<'EOF'
global:  # 全局配置，未单独指定时会作为默认值
  scrape_interval: 15s  # 默认每 15 秒抓取一次指标
  evaluation_interval: 15s  # 默认每 15 秒计算一次告警规则和记录规则

rule_files:  # 告警规则和记录规则文件列表
  - /etc/prometheus/rules/*.yml  # 加载 rules 目录下所有 yml 规则文件

scrape_configs:  # 指标采集任务列表
  - job_name: prometheus  # 采集 Prometheus 自身指标的任务名称
    static_configs:  # 使用静态目标配置
      - targets:  # 当前任务的采集目标列表
          - localhost:9090  # Prometheus 自身 metrics 地址

  - job_name: node  # 采集主机指标的任务名称
    static_configs:  # 使用静态目标配置
      - targets:  # 当前任务的采集目标列表
          - localhost:9100  # Node Exporter metrics 地址
EOF
```

创建规则目录：

```bash
mkdir -p /etc/prometheus/rules  # 创建规则文件目录
chown -R prometheus:prometheus /etc/prometheus  # 修正配置目录权限
```

检查配置：

```bash
promtool check config /etc/prometheus/prometheus.yml  # 校验 Prometheus 主配置
```

配置说明：

| 配置 | 说明 |
| --- | --- |
| `scrape_interval` | 默认抓取间隔 |
| `evaluation_interval` | 告警和记录规则计算间隔 |
| `rule_files` | 告警规则和记录规则文件 |
| `scrape_configs` | 抓取目标配置 |

## 2.6 systemd 托管 Prometheus

创建服务文件：

```bash
# 写入 systemd 服务文件
cat > /etc/systemd/system/prometheus.service <<'EOF'
# Unit 段描述服务元信息和启动顺序
[Unit]
# 服务名称，systemctl status 中会显示
Description=Prometheus
# 服务相关文档地址
Documentation=https://prometheus.io/docs/
# 在网络可用后再启动服务
After=network.target

# Service 段描述进程启动方式和运行参数
[Service]
# simple 表示 ExecStart 启动的进程就是主进程
Type=simple
# 使用 prometheus 用户运行，降低权限
User=prometheus
# 使用 prometheus 用户组运行
Group=prometheus
# Prometheus 启动命令和参数：
# --config.file 指定主配置文件
# --storage.tsdb.path 指定 TSDB 数据目录
# --storage.tsdb.retention.time 设置本地数据保留时间
# --storage.tsdb.retention.size 设置本地数据最大保留容量
# --web.console.templates 指定控制台模板目录
# --web.console.libraries 指定控制台依赖库目录
# --web.enable-lifecycle 开启 HTTP reload 能力
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=15d \
  --storage.tsdb.retention.size=50GB \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.enable-lifecycle
# 进程异常退出时自动重启
Restart=on-failure
# 失败后等待 5 秒再重启
RestartSec=5
# 提高进程可打开文件数
LimitNOFILE=65536

# Install 段描述开机自启挂载目标
[Install]
# 挂载到多用户运行级别
WantedBy=multi-user.target
EOF
```

启动：

```bash
systemctl daemon-reload  # 重新加载 systemd 配置
systemctl enable --now prometheus  # 设置 Prometheus 开机自启并立即启动
systemctl status prometheus  # 查看 Prometheus 服务状态
```

查看日志：

```bash
journalctl -u prometheus -f  # 实时查看 Prometheus 日志
```

访问：

```text
http://服务器IP:9090
```

## 2.7 安装 Node Exporter

下载：

```bash
cd /opt  # 进入安装目录
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz  # 下载 Node Exporter 二进制包
tar zxf node_exporter-1.9.1.linux-amd64.tar.gz  # 解压缩安装包
cp node_exporter-1.9.1.linux-amd64/node_exporter /usr/local/bin/  # 复制 node_exporter 到 PATH
```

创建用户：

```bash
useradd -r -s /sbin/nologin node_exporter  # 创建 Node Exporter 系统用户
```

systemd：

```bash
# 写入 Node Exporter systemd 服务文件
cat > /etc/systemd/system/node_exporter.service <<'EOF'
# Unit 段描述服务元信息和启动顺序
[Unit]
# 服务名称，systemctl status 中会显示
Description=Node Exporter
# 服务相关文档地址
Documentation=https://prometheus.io/docs/guides/node-exporter/
# 在网络可用后再启动服务
After=network.target

# Service 段描述进程启动方式和运行参数
[Service]
# simple 表示 ExecStart 启动的进程就是主进程
Type=simple
# 使用 node_exporter 用户运行，降低权限
User=node_exporter
# 使用 node_exporter 用户组运行
Group=node_exporter
# Node Exporter 启动命令，默认监听 9100 端口
ExecStart=/usr/local/bin/node_exporter
# 进程异常退出时自动重启
Restart=on-failure
# 失败后等待 5 秒再重启
RestartSec=5

# Install 段描述开机自启挂载目标
[Install]
# 挂载到多用户运行级别
WantedBy=multi-user.target
EOF
```

启动：

```bash
systemctl daemon-reload  # 重新加载 systemd 配置
systemctl enable --now node_exporter  # 设置 Node Exporter 开机自启并立即启动
systemctl status node_exporter  # 查看 Node Exporter 服务状态
```

验证：

```bash
curl http://localhost:9100/metrics | head  # 验证 Node Exporter 指标输出
```

## 2.8 配置 reload

Prometheus 配置变更后，先检查：

```bash
promtool check config /etc/prometheus/prometheus.yml  # reload 前先校验配置
```

方式一：systemd reload，发送 `SIGHUP`：

```bash
systemctl reload prometheus  # 通过 systemd reload 触发 Prometheus 重新加载配置
```

如需支持 `systemctl reload`，可以给 service 增加：

```ini
# systemctl reload prometheus 时向主进程发送 SIGHUP
ExecReload=/bin/kill -HUP $MAINPID
```

方式二：HTTP reload，需要启动参数包含 `--web.enable-lifecycle`：

```bash
curl -X POST http://localhost:9090/-/reload  # 通过 HTTP API 触发配置 reload
```

验证：

```bash
curl http://localhost:9090/-/healthy  # 检查 Prometheus 健康状态
curl http://localhost:9090/-/ready  # 检查 Prometheus 是否 ready
```

## 2.9 告警规则示例

创建规则：

```bash
# 写入 Node 告警规则文件
cat > /etc/prometheus/rules/node-alerts.yml <<'EOF'
groups:  # 规则组列表
  - name: node  # 规则组名称，用于页面展示和日志定位
    rules:  # 当前规则组内的规则列表
      - alert: NodeDown  # 告警名称
        expr: up{job="node"} == 0  # 当 node 任务的目标不可达时触发
        for: 1m  # 条件持续 1 分钟后进入 firing 状态
        labels:  # 告警标签，用于分级和路由
          severity: critical  # 告警级别为 critical
        annotations:  # 告警描述信息，用于通知内容
          summary: "Node exporter is down"  # 告警摘要
          description: "{{ $labels.instance }} is down"  # 告警详情，引用实例标签

      - alert: DiskUsageHigh  # 告警名称
        expr: (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) > 0.85  # 非临时文件系统磁盘使用率超过 85%
        for: 5m  # 条件持续 5 分钟后触发
        labels:  # 告警标签，用于分级和路由
          severity: warning  # 告警级别为 warning
        annotations:  # 告警描述信息，用于通知内容
          summary: "Disk usage is high"  # 告警摘要
          description: "{{ $labels.instance }} disk usage is over 85%"  # 告警详情，引用实例标签
EOF
```

检查：

```bash
promtool check rules /etc/prometheus/rules/node-alerts.yml  # 校验告警规则文件
curl -X POST http://localhost:9090/-/reload  # 重新加载 Prometheus 配置和规则
```

页面查看：

```text
http://服务器IP:9090/alerts
```

## 2.10 Docker Compose 示例

目录：

```text
monitoring
├── docker-compose.yml
└── prometheus.yml
```

`prometheus.yml`：

```yaml title="prometheus.yml"
global:  # 全局配置
  scrape_interval: 15s  # 默认每 15 秒抓取一次指标
  evaluation_interval: 15s  # 默认每 15 秒计算一次规则

scrape_configs:  # 指标采集任务列表
  - job_name: prometheus  # 采集 Prometheus 自身指标
    static_configs:  # 使用静态目标配置
      - targets:  # 采集目标列表
          - prometheus:9090  # Compose 网络中的 Prometheus 服务地址

  - job_name: node  # 采集 Node Exporter 主机指标
    static_configs:  # 使用静态目标配置
      - targets:  # 采集目标列表
          - node-exporter:9100  # Compose 网络中的 Node Exporter 服务地址
```

`docker-compose.yml`：

```yaml title="docker-compose.yml"
services:  # Compose 服务列表
  prometheus:  # Prometheus 服务
    image: prom/prometheus:v3.11.2  # 使用固定版本 Prometheus 镜像
    container_name: prometheus  # 容器名称
    restart: unless-stopped  # 容器异常退出后自动重启，手动停止除外
    ports:  # 端口映射
      - "9090:9090"  # 暴露 Prometheus Web 和 API 端口
    volumes:  # 挂载配置和数据卷
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro  # 只读挂载 Prometheus 配置文件
      - prometheus_data:/prometheus  # 持久化 Prometheus TSDB 数据
    command:  # 覆盖容器启动参数
      - "--config.file=/etc/prometheus/prometheus.yml"  # 指定配置文件路径
      - "--storage.tsdb.path=/prometheus"  # 指定容器内数据目录
      - "--storage.tsdb.retention.time=15d"  # 本地数据保留 15 天
      - "--web.enable-lifecycle"  # 开启 HTTP reload 能力

  node-exporter:  # Node Exporter 服务
    image: prom/node-exporter:v1.9.1  # 使用固定版本 Node Exporter 镜像
    container_name: node-exporter  # 容器名称
    restart: unless-stopped  # 容器异常退出后自动重启，手动停止除外
    ports:  # 端口映射
      - "9100:9100"  # 暴露 Node Exporter metrics 端口

volumes:  # Compose 数据卷定义
  prometheus_data:  # Prometheus 数据卷
```

启动：

```bash
docker compose up -d  # 后台启动 Prometheus 和 Node Exporter
docker compose logs -f prometheus  # 实时查看 Prometheus 容器日志
```

## 2.11 常用检查

Targets：

```text
http://服务器IP:9090/targets
```

PromQL 测试：

```promql
up
up{job="node"}
rate(prometheus_tsdb_head_samples_appended_total[5m])
```

API：

```bash
curl 'http://localhost:9090/api/v1/query?query=up'  # 通过 API 查询 up 指标
curl http://localhost:9090/api/v1/targets  # 通过 API 查看 Targets 状态
```

存储目录：

```bash
du -sh /var/lib/prometheus  # 查看 Prometheus 数据目录总大小
ls -lh /var/lib/prometheus  # 查看 TSDB 数据目录内容
```

## 2.12 常见问题

### 2.12.1 Prometheus 启动失败

排查：

```bash
systemctl status prometheus  # 查看 Prometheus 服务状态
journalctl -u prometheus -n 200 --no-pager  # 查看最近 200 行服务日志
promtool check config /etc/prometheus/prometheus.yml  # 校验配置文件
```

常见原因：

- YAML 格式错误。
- 数据目录权限错误。
- 端口 `9090` 被占用。
- 启动参数写错。

### 2.12.2 Targets 显示 down

排查：

```bash
curl http://目标IP:端口/metrics  # 直接访问目标 Exporter 指标
curl http://localhost:9090/api/v1/targets  # 查看 Prometheus 侧 Targets 状态
```

常见原因：

- Exporter 未启动。
- Prometheus 到目标网络不通。
- `targets` 地址写错。
- 防火墙或安全组未放行。

### 2.12.3 配置 reload 不生效

排查：

- 是否先执行 `promtool check config`。
- 是否启用了 `--web.enable-lifecycle`。
- 是否调用了正确地址 `/-/reload`。
- 日志中是否提示加载失败。

### 2.12.4 磁盘增长过快

处理：

- 降低保留时间 `--storage.tsdb.retention.time`。
- 设置保留大小 `--storage.tsdb.retention.size`。
- 降低 scrape 频率。
- 减少高基数指标。
- 对长期存储接入 Thanos、VictoriaMetrics 或远端存储。

## 2.13 参考资料

- [Prometheus Installation](https://prometheus.io/docs/prometheus/latest/installation/)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Prometheus Storage](https://prometheus.io/docs/prometheus/latest/storage/)
- [Node Exporter](https://github.com/prometheus/node_exporter)
