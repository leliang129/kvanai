---
title: Blackbox Exporter 安装部署
sidebar_position: 9
---

# Blackbox Exporter 安装部署


## 9.1 Blackbox Exporter 作用

Blackbox Exporter 用于从“外部视角”探测目标服务，而不是采集主机内部资源指标。

常见探测类型：

- HTTP / HTTPS
- TCP
- ICMP
- DNS

适合场景：

- 站点可用性探测
- API 健康检查
- TCP 端口连通性检测
- 域名解析检测

## 9.2 和 Node Exporter 的区别

| 工具 | 作用 |
| --- | --- |
| Node Exporter | 采集主机内部 CPU、内存、磁盘、网络等指标 |
| Blackbox Exporter | 从外部探测 HTTP、TCP、ICMP、DNS 等目标可用性 |

## 9.3 安装方式

常见方式：

| 方式 | 说明 | 适用场景 |
| --- | --- | --- |
| 二进制包 + systemd | 结构清晰，适合生产 | 物理机 / 虚拟机 |
| Docker / Compose | 部署快 | 测试环境 / 容器环境 |

本文以 **二进制包 + systemd** 为主。

## 9.4 下载与安装

创建目录和用户：

```bash
useradd -r -s /sbin/nologin blackbox_exporter  # 创建 Blackbox Exporter 系统用户
mkdir -p /etc/blackbox_exporter  # 创建配置目录
mkdir -p /opt/blackbox_exporter  # 创建安装目录
chown -R blackbox_exporter:blackbox_exporter /etc/blackbox_exporter /opt/blackbox_exporter  # 修正目录权限
```

下载：

```bash
cd /opt  # 进入安装目录
wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.26.0/blackbox_exporter-0.26.0.linux-amd64.tar.gz  # 下载 Blackbox Exporter 二进制包
tar zxf blackbox_exporter-0.26.0.linux-amd64.tar.gz  # 解压安装包
ln -s blackbox_exporter-0.26.0.linux-amd64 blackbox_exporter  # 创建稳定软连接
cp /opt/blackbox_exporter/blackbox_exporter /usr/local/bin/  # 复制 Blackbox Exporter 主程序
```

## 9.5 配置文件

创建配置文件：

```bash
# 写入 Blackbox Exporter 主配置文件
cat > /etc/blackbox_exporter/config.yml <<'EOF'
modules:  # 探测模块列表
  http_2xx:  # HTTP 2xx 探测模块
    prober: http  # 使用 HTTP 探测器
    timeout: 5s  # 单次探测超时时间
    http:  # HTTP 探测参数
      method: GET  # 使用 GET 请求
      valid_status_codes: []  # 空列表表示默认接受 2xx 状态码
      preferred_ip_protocol: ip4  # 优先使用 IPv4

  tcp_connect:  # TCP 连通性探测模块
    prober: tcp  # 使用 TCP 探测器
    timeout: 5s  # 单次探测超时时间

  icmp:  # ICMP 探测模块
    prober: icmp  # 使用 ICMP 探测器
    timeout: 5s  # 单次探测超时时间
EOF
```

## 9.6 systemd 托管

```bash
# 写入 Blackbox Exporter systemd 服务文件
cat > /etc/systemd/system/blackbox_exporter.service <<'EOF'
[Unit]
Description=Blackbox Exporter
Documentation=https://github.com/prometheus/blackbox_exporter
After=network.target

[Service]
Type=simple
User=blackbox_exporter
Group=blackbox_exporter
ExecStart=/usr/local/bin/blackbox_exporter \
  --config.file=/etc/blackbox_exporter/config.yml \
  --web.listen-address=:9115
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

启动：

```bash
systemctl daemon-reload  # 重新加载 systemd 配置
systemctl enable --now blackbox_exporter  # 设置 Blackbox Exporter 开机自启并立即启动
systemctl status blackbox_exporter  # 查看 Blackbox Exporter 服务状态
```

检查：

```bash
curl http://localhost:9115/metrics | head  # 检查 Blackbox Exporter 指标输出
curl 'http://localhost:9115/probe?target=https://example.com&module=http_2xx'  # 手动测试 HTTP 探测
```

## 9.7 Prometheus 对接

Prometheus 配置示例：

```yaml title="/etc/prometheus/prometheus.yml"
scrape_configs:  # 指标采集任务列表
  - job_name: blackbox-http  # HTTP 黑盒探测任务名称
    metrics_path: /probe  # 请求 Blackbox Exporter 探测接口
    params:  # 传给 Blackbox Exporter 的参数
      module: [http_2xx]  # 使用 http_2xx 探测模块
    static_configs:  # 使用静态目标配置
      - targets:  # 需要探测的真实业务地址
          - https://example.com  # 第一个 HTTP 探测目标
          - https://api.example.com/health  # 第二个 HTTP 健康检查地址
    relabel_configs:  # 采集前改写 target 标签
      - source_labels: [__address__]  # 读取原始目标地址
        target_label: __param_target  # 写入 target 查询参数
      - source_labels: [__param_target]  # 读取真实探测目标
        target_label: instance  # 将真实目标展示为 instance
      - target_label: __address__  # 改写实际抓取地址
        replacement: 127.0.0.1:9115  # 指向 Blackbox Exporter 地址
```

配置校验和重载：

```bash
promtool check config /etc/prometheus/prometheus.yml  # 校验 Prometheus 配置
curl -X POST http://localhost:9090/-/reload  # 重新加载 Prometheus 配置
```

## 9.8 Docker Compose 示例

```yaml title="docker-compose.yml"
services:  # Compose 服务列表
  blackbox-exporter:  # Blackbox Exporter 服务
    image: prom/blackbox-exporter:v0.26.0  # 使用固定版本 Blackbox Exporter 镜像
    container_name: blackbox-exporter  # 容器名称
    restart: unless-stopped  # 容器异常退出后自动重启，手动停止除外
    ports:  # 端口映射
      - "9115:9115"  # 暴露 Blackbox Exporter 端口
    volumes:  # 挂载配置文件
      - ./config.yml:/etc/blackbox_exporter/config.yml:ro  # 只读挂载 Blackbox 配置文件
    command:  # 覆盖容器启动参数
      - "--config.file=/etc/blackbox_exporter/config.yml"  # 指定配置文件路径
      - "--web.listen-address=:9115"  # 指定监听地址和端口
```

启动：

```bash
docker compose up -d  # 后台启动 Blackbox Exporter
docker compose logs -f blackbox-exporter  # 查看 Blackbox Exporter 容器日志
```

## 9.9 常用指标

| 指标 | 说明 |
| --- | --- |
| `probe_success` | 探测是否成功 |
| `probe_duration_seconds` | 探测耗时 |
| `probe_http_status_code` | HTTP 状态码 |
| `probe_ssl_earliest_cert_expiry` | 证书过期时间 |
| `probe_dns_lookup_time_seconds` | DNS 解析耗时 |

## 9.10 常见问题

### 9.10.1 Prometheus 中 probe_success 一直为 0

排查：

```bash
curl 'http://localhost:9115/probe?target=https://example.com&module=http_2xx'  # 手动探测目标
curl http://localhost:9090/api/v1/targets  # 查看 Prometheus Targets 状态
```

常见原因：

- 目标服务本身不可达。
- 模块名称写错。
- Blackbox Exporter 地址写错。
- DNS 或网络异常。

### 9.10.2 ICMP 探测失败

常见原因：

- 进程权限不足。
- 系统禁止普通用户发送 ICMP。
- 防火墙屏蔽了 ICMP。

### 9.10.3 HTTPS 探测异常

常见原因：

- 证书过期。
- SNI / TLS 协议不兼容。
- 目标站点跳转逻辑异常。

## 9.11 参考资料

- [Blackbox Exporter](https://github.com/prometheus/blackbox_exporter)
- [Prometheus Blackbox Guide](https://prometheus.io/docs/guides/multi-target-exporter/)
