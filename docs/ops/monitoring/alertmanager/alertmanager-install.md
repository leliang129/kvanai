---
title: Alertmanager 安装部署
sidebar_position: 2
---

# Alertmanager 安装部署


## 2.1 Alertmanager 作用

Alertmanager 负责接收 Prometheus 发出的告警，并完成分组、路由、抑制、静默和通知发送。

核心能力：

- 告警分组
- 告警路由
- 告警抑制
- 告警静默
- 通知重试
- 对接邮件、Webhook、钉钉、企业微信、Slack 等渠道

链路：

```text
Prometheus -> Alertmanager -> 通知渠道
```

## 2.2 安装方式

常见方式：

| 方式 | 说明 | 适用场景 |
| --- | --- | --- |
| 二进制包 + systemd | 官方推荐方式，结构清晰 | 物理机 / 虚拟机生产环境 |
| Docker / Compose | 部署快，适合测试环境 | 测试环境 / 小规模使用 |
| Kubernetes | 配合 Prometheus Operator 使用 | 云原生环境 |

本文以 **二进制包 + systemd** 为主，并补充 Docker Compose 示例。

## 2.3 环境准备

建议配置：

- 测试环境：`1C 1G` 起步。
- 生产环境：按告警量、路由复杂度和高可用需求评估。

常用端口：

| 端口 | 说明 |
| --- | --- |
| `9093` | Alertmanager Web 和 API 端口 |
| `9094` | Alertmanager 集群通信端口 |

创建目录和用户：

```bash
useradd -r -s /sbin/nologin alertmanager  # 创建 Alertmanager 系统用户
mkdir -p /etc/alertmanager  # 创建 Alertmanager 配置目录
mkdir -p /var/lib/alertmanager  # 创建 Alertmanager 数据目录
mkdir -p /opt/alertmanager  # 创建安装目录
chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager /opt/alertmanager  # 修正目录权限
```

## 2.4 下载与安装

下载：

```bash
cd /opt  # 进入安装目录
wget https://github.com/prometheus/alertmanager/releases/download/v0.28.1/alertmanager-0.28.1.linux-amd64.tar.gz  # 下载 Alertmanager 二进制包
tar zxf alertmanager-0.28.1.linux-amd64.tar.gz  # 解压安装包
ln -s alertmanager-0.28.1.linux-amd64 alertmanager  # 创建稳定软连接
```

复制文件：

```bash
cp /opt/alertmanager/alertmanager /usr/local/bin/  # 复制 Alertmanager 主程序
cp /opt/alertmanager/amtool /usr/local/bin/  # 复制 amtool 管理工具
chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager  # 修正配置和数据目录权限
```

检查版本：

```bash
alertmanager --version  # 查看 Alertmanager 版本
amtool --version  # 查看 amtool 版本
```

## 2.5 基础配置

创建配置文件：

```bash
# 写入 Alertmanager 主配置文件
cat > /etc/alertmanager/alertmanager.yml <<'EOF'
global:  # 全局配置
  resolve_timeout: 5m  # 告警恢复后等待 5 分钟再标记为 resolved

route:  # 根路由，所有告警先进入这里
  receiver: default-webhook  # 默认接收器名称
  group_by:  # 告警分组标签，相同标签值会合并通知
    - alertname  # 按告警名称分组
    - cluster  # 按集群分组
    - service  # 按服务分组
  group_wait: 30s  # 首次收到同组告警后等待 30 秒再发送
  group_interval: 5m  # 同组新增告警至少间隔 5 分钟再发送
  repeat_interval: 4h  # 未恢复告警每 4 小时重复通知一次

receivers:  # 接收器列表
  - name: default-webhook  # 接收器名称，需要和 route.receiver 对应
    webhook_configs:  # Webhook 通知配置
      - url: http://127.0.0.1:5001/alert  # Webhook 接收地址
        send_resolved: true  # 告警恢复时也发送通知
EOF
```

校验配置：

```bash
amtool check-config /etc/alertmanager/alertmanager.yml  # 校验 Alertmanager 配置
```

## 2.6 systemd 托管

```bash
# 写入 Alertmanager systemd 服务文件
cat > /etc/systemd/system/alertmanager.service <<'EOF'
# Unit 段描述服务元信息和启动顺序
[Unit]
# 服务名称，systemctl status 中会显示
Description=Alertmanager
# 服务相关文档地址
Documentation=https://prometheus.io/docs/alerting/latest/alertmanager/
# 在网络可用后再启动服务
After=network.target

# Service 段描述进程启动方式和运行参数
[Service]
# simple 表示 ExecStart 启动的进程就是主进程
Type=simple
# 使用 alertmanager 用户运行，降低权限
User=alertmanager
# 使用 alertmanager 用户组运行
Group=alertmanager
# Alertmanager 启动命令和参数：
# --config.file 指定 Alertmanager 配置文件
# --storage.path 指定 Alertmanager 本地状态数据目录
# --web.listen-address 指定 Web 和 API 监听地址
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager \
  --web.listen-address=:9093
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
systemctl enable --now alertmanager  # 设置开机自启并立即启动
systemctl status alertmanager  # 查看服务状态
```

查看日志：

```bash
journalctl -u alertmanager -f  # 实时查看 Alertmanager 日志
```

访问：

```text
http://服务器IP:9093
```

## 2.7 Prometheus 对接 Alertmanager

Prometheus 配置：

```yaml title="/etc/prometheus/prometheus.yml"
alerting:  # Prometheus 告警发送配置
  alertmanagers:  # Alertmanager 实例列表
    - static_configs:  # 使用静态地址配置
        - targets:  # Alertmanager 地址列表
            - localhost:9093  # 本机 Alertmanager 地址
```

校验并 reload：

```bash
promtool check config /etc/prometheus/prometheus.yml  # 校验 Prometheus 配置
curl -X POST http://localhost:9090/-/reload  # 重新加载 Prometheus 配置
```

## 2.8 Docker Compose 示例

```yaml title="docker-compose.yml"
services:  # Compose 服务列表
  alertmanager:  # Alertmanager 服务
    image: prom/alertmanager:v0.28.1  # 使用固定版本 Alertmanager 镜像
    container_name: alertmanager  # 容器名称
    restart: unless-stopped  # 容器异常退出后自动重启，手动停止除外
    ports:  # 端口映射
      - "9093:9093"  # 暴露 Alertmanager Web 和 API 端口
    volumes:  # 挂载配置和数据目录
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro  # 只读挂载 Alertmanager 配置文件
      - alertmanager_data:/alertmanager  # 持久化 Alertmanager 数据
    command:  # 覆盖容器启动参数
      - "--config.file=/etc/alertmanager/alertmanager.yml"  # 指定配置文件路径
      - "--storage.path=/alertmanager"  # 指定容器内数据目录
      - "--web.listen-address=:9093"  # 指定监听地址和端口

volumes:  # Compose 数据卷定义
  alertmanager_data:  # Alertmanager 数据卷
```

启动：

```bash
docker compose up -d  # 后台启动 Alertmanager
docker compose logs -f alertmanager  # 查看 Alertmanager 容器日志
```

## 2.9 高可用集群

Alertmanager 高可用通常部署两个及以上节点，通过 gossip 协议同步静默和通知状态。

示例：

```bash
alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager \
  --web.listen-address=:9093 \
  --cluster.listen-address=0.0.0.0:9094 \
  --cluster.peer=10.0.0.12:9094  # 启动 Alertmanager 并加入对端节点
```

Prometheus 对接多个 Alertmanager：

```yaml title="/etc/prometheus/prometheus.yml"
alerting:  # Prometheus 告警发送配置
  alertmanagers:  # Alertmanager 实例列表
    - static_configs:  # 使用静态地址配置
        - targets:  # Alertmanager 地址列表
            - 10.0.0.11:9093  # 第一个 Alertmanager 节点
            - 10.0.0.12:9093  # 第二个 Alertmanager 节点
```

## 2.10 常用检查

常见入口：

```text
http://服务器IP:9093
http://服务器IP:9093/#/alerts
http://服务器IP:9093/#/silences
```

API 检查：

```bash
curl http://localhost:9093/api/v2/status  # 查看 Alertmanager 状态
curl http://localhost:9093/api/v2/alerts  # 查看当前告警
curl http://localhost:9093/api/v2/silences  # 查看当前静默
```

## 2.11 常见问题

### 2.11.1 服务启动失败

排查：

```bash
systemctl status alertmanager  # 查看 Alertmanager 服务状态
journalctl -u alertmanager -n 200 --no-pager  # 查看最近服务日志
amtool check-config /etc/alertmanager/alertmanager.yml  # 校验 Alertmanager 配置
```

### 2.11.2 Web 页面打不开

排查：

```bash
ss -lntp | grep 9093  # 检查 9093 端口监听状态
curl http://localhost:9093/api/v2/status  # 检查 Alertmanager API 状态
```

### 2.11.3 Prometheus 没有发告警过来

排查：

```bash
curl http://localhost:9090/api/v1/alerts  # 查看 Prometheus 当前告警
curl http://localhost:9093/api/v2/alerts  # 查看 Alertmanager 当前告警
```

## 2.12 参考资料

- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [amtool](https://prometheus.io/docs/alerting/latest/amtool/)
