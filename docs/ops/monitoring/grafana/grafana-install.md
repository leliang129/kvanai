---
title: Grafana 安装部署
sidebar_position: 2
---

# Grafana 安装部署


## 2.1 Grafana 作用

Grafana 用于展示监控指标、日志和告警结果，最常见的场景是作为 Prometheus 的可视化入口。

常见用途：

- 展示主机、中间件、业务服务监控面板。
- 通过变量进行环境、集群、实例筛选。
- 在 Explore 中调试 PromQL 查询。
- 统一查看监控告警和趋势。

## 2.2 安装方式

常见安装方式：

| 方式 | 说明 | 适用场景 |
| --- | --- | --- |
| RPM / DEB | 官方仓库安装，升级维护方便 | 物理机 / 虚拟机 |
| 二进制包 | 手工安装，可控性高 | 特殊环境 |
| Docker / Compose | 部署快，便于测试和小规模使用 | 测试环境 / 容器环境 |
| Helm Chart | Kubernetes 内快速部署 | 云原生环境 |

本文以 **RPM / DEB + systemd** 为主，同时补充 Docker Compose 示例。

## 2.3 环境准备

建议配置：

- 测试环境：`2C 2G` 起步。
- 生产环境：按数据源数量、面板复杂度、用户并发评估。
- 持久化目录建议独立磁盘或独立数据卷。

常用端口：

| 端口 | 说明 |
| --- | --- |
| `3000` | Grafana Web 默认端口 |

## 2.4 RPM / DEB 安装

### 2.4.1 RHEL / Rocky / AlmaLinux

添加仓库：

```bash
cat > /etc/yum.repos.d/grafana.repo <<'EOF'  # 写入 Grafana YUM 仓库配置
[grafana]  # 仓库 ID
name=grafana  # 仓库名称
baseurl=https://rpm.grafana.com  # Grafana 官方 RPM 仓库地址
repo_gpgcheck=1  # 启用仓库元数据 GPG 校验
enabled=1  # 启用该仓库
gpgcheck=1  # 启用安装包 GPG 校验
gpgkey=https://rpm.grafana.com/gpg.key  # Grafana 官方 GPG 公钥地址
sslverify=1  # 启用 SSL 证书校验
sslcacert=/etc/pki/tls/certs/ca-bundle.crt  # CA 证书路径
EOF
```

安装：

```bash
dnf makecache  # 刷新软件仓库缓存
dnf install -y grafana  # 安装 Grafana
```

### 2.4.2 Ubuntu / Debian

安装依赖：

```bash
apt update  # 更新软件源
apt install -y wget gpg apt-transport-https software-properties-common  # 安装仓库管理依赖
```

导入仓库密钥：

```bash
mkdir -p /etc/apt/keyrings  # 创建 APT keyrings 目录
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null  # 下载并导入 Grafana 仓库 GPG 公钥
```

添加仓库：

```bash
cat > /etc/apt/sources.list.d/grafana.list <<'EOF'  # 写入 Grafana APT 仓库配置
deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main  # Grafana 官方 APT 仓库
EOF
```

安装：

```bash
apt update  # 刷新软件源
apt install -y grafana  # 安装 Grafana
```

## 2.5 启动与开机自启

systemd 启动：

```bash
systemctl daemon-reload  # 重新加载 systemd 配置
systemctl enable --now grafana-server  # 设置 Grafana 开机自启并立即启动
systemctl status grafana-server  # 查看 Grafana 服务状态
```

查看日志：

```bash
journalctl -u grafana-server -f  # 实时查看 Grafana 服务日志
```

访问地址：

```text
http://服务器IP:3000
```

## 2.6 默认目录说明

常见目录：

| 路径 | 说明 |
| --- | --- |
| `/etc/grafana/grafana.ini` | 主配置文件 |
| `/var/lib/grafana` | 数据目录 |
| `/var/log/grafana` | 日志目录 |
| `/usr/share/grafana` | 程序安装目录 |

## 2.7 Grafana 主配置

主配置文件：

```ini title="/etc/grafana/grafana.ini"
[server]
; protocol = http
; http_addr =
; http_port = 3000
; domain = localhost
; root_url = %(protocol)s://%(domain)s:%(http_port)s/

[security]
; admin_user = admin
; admin_password = admin

[users]
; allow_sign_up = false

[paths]
; data = /var/lib/grafana
; logs = /var/log/grafana
```

配置说明：

- `http_port`：Grafana Web 监听端口。
- `domain`：对外访问域名。
- `root_url`：反向代理或子路径部署时必须设置。
- `admin_user`：初始化管理员账号。
- `admin_password`：初始化管理员密码。
- `allow_sign_up`：是否允许用户自行注册。
- `data`：Grafana 数据目录。
- `logs`：Grafana 日志目录。

## 2.8 常用配置示例

### 2.8.1 修改监听地址和端口

```ini title="/etc/grafana/grafana.ini"
[server]
http_addr = 0.0.0.0
http_port = 3000
domain = grafana.example.com
root_url = http://grafana.example.com:3000/
```

### 2.8.2 禁止用户自注册

```ini title="/etc/grafana/grafana.ini"
[users]
allow_sign_up = false
```

### 2.8.3 修改管理员密码

```ini title="/etc/grafana/grafana.ini"
[security]
admin_user = admin
admin_password = ChangeMe_123
```

修改后重启：

```bash
systemctl restart grafana-server  # 重启 Grafana 服务使配置生效
systemctl status grafana-server  # 查看 Grafana 服务状态
```

## 2.9 Docker Compose 安装

```yaml title="docker-compose.yml"
services:  # Compose 服务列表
  grafana:  # Grafana 服务
    image: grafana/grafana:12.3.0  # 使用固定版本 Grafana 镜像
    container_name: grafana  # 容器名称
    restart: unless-stopped  # 容器异常退出后自动重启，手动停止除外
    ports:  # 端口映射
      - "3000:3000"  # 暴露 Grafana Web 端口
    environment:  # Grafana 环境变量
      GF_SECURITY_ADMIN_USER: admin  # 初始化管理员用户名
      GF_SECURITY_ADMIN_PASSWORD: ChangeMe_123  # 初始化管理员密码
    volumes:  # 数据卷挂载
      - grafana_data:/var/lib/grafana  # 持久化 Grafana 数据

volumes:  # Compose 数据卷定义
  grafana_data:  # Grafana 数据卷
```

启动：

```bash
docker compose up -d  # 后台启动 Grafana
docker compose logs -f grafana  # 查看 Grafana 容器日志
```

## 2.10 首次登录

默认登录地址：

```text
http://服务器IP:3000/login
```

首次登录通常会要求修改管理员密码。

建议初始化后立刻完成：

- 修改管理员密码。
- 关闭匿名访问。
- 关闭自注册。
- 配置 HTTPS 或通过反向代理接入。
- 配置组织、团队和权限。

## 2.11 Prometheus 数据源对接

页面路径：

```text
Connections -> Data sources -> Add data source -> Prometheus
```

常用配置：

| 配置项 | 示例 |
| --- | --- |
| `Name` | `Prometheus` |
| `URL` | `http://prometheus:9090` |
| `Access` | `Server` |

自动化配置：

```yaml title="provisioning/datasources/prometheus.yml"
apiVersion: 1  # Grafana provisioning API 版本

datasources:  # 数据源列表
  - name: Prometheus  # 数据源名称
    type: prometheus  # 数据源类型
    access: proxy  # 由 Grafana 服务端访问 Prometheus
    url: http://prometheus:9090  # Prometheus 地址
    isDefault: true  # 设置为默认数据源
    editable: true  # 允许在页面编辑
```

## 2.12 常见问题

### 2.12.1 页面无法访问

排查：

```bash
systemctl status grafana-server  # 查看 Grafana 服务状态
ss -lntp | grep 3000  # 检查 3000 端口监听状态
curl http://localhost:3000/api/health  # 检查 Grafana 健康状态
```

### 2.12.2 忘记管理员密码

重置密码：

```bash
grafana-cli admin reset-admin-password NewPass_123  # 重置 Grafana 管理员密码
```

### 2.12.3 配置修改未生效

排查：

```bash
grafana-server -v  # 查看 Grafana 版本
grep -n '^[^;]' /etc/grafana/grafana.ini  # 查看主配置中实际启用的配置项
systemctl restart grafana-server  # 重启 Grafana 服务
journalctl -u grafana-server -n 200 --no-pager  # 查看最近日志
```

## 2.13 参考资料

- [Grafana Installation](https://grafana.com/docs/grafana/latest/setup-grafana/installation/)
- [Grafana Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
- [Grafana CLI](https://grafana.com/docs/grafana/latest/cli/)
