---
title: Pushgateway 安装部署
sidebar_position: 10
---

# Pushgateway 安装部署


## 10.1 Pushgateway 作用

Pushgateway 用于接收短生命周期任务或批处理任务主动推送的指标，再由 Prometheus 去抓取。

适合场景：

- 定时任务
- 一次性批处理任务
- 脚本执行结果上报
- 无法长期暴露 `/metrics` 的作业

不适合场景：

- 常驻服务
- Web 应用
- 长期运行的 Worker

对于长期运行的服务，应该直接暴露 `/metrics` 给 Prometheus 抓取，而不是走 Pushgateway。

## 10.2 基本工作方式

```text
Batch Job -> Pushgateway -> Prometheus -> Grafana / Alertmanager
```

说明：

- 批任务执行完成后，把结果推送到 Pushgateway。
- Prometheus 定时抓取 Pushgateway 上的指标。
- 指标不会自动过期，需要显式删除或覆盖。

## 10.3 安装方式

常见方式：

| 方式 | 说明 | 适用场景 |
| --- | --- | --- |
| 二进制包 + systemd | 结构清晰，适合生产 | 物理机 / 虚拟机 |
| Docker / Compose | 部署快 | 测试环境 / 容器环境 |

本文以 **二进制包 + systemd** 为主。

## 10.4 下载与安装

创建目录和用户：

```bash
useradd -r -s /sbin/nologin pushgateway  # 创建 Pushgateway 系统用户
mkdir -p /opt/pushgateway  # 创建安装目录
chown -R pushgateway:pushgateway /opt/pushgateway  # 修正安装目录权限
```

下载：

```bash
cd /opt  # 进入安装目录
wget https://github.com/prometheus/pushgateway/releases/download/v1.11.1/pushgateway-1.11.1.linux-amd64.tar.gz  # 下载 Pushgateway 二进制包
tar zxf pushgateway-1.11.1.linux-amd64.tar.gz  # 解压安装包
ln -s pushgateway-1.11.1.linux-amd64 pushgateway  # 创建稳定软连接
cp /opt/pushgateway/pushgateway /usr/local/bin/  # 复制 Pushgateway 主程序
```

检查版本：

```bash
pushgateway --version  # 查看 Pushgateway 版本
```

## 10.5 systemd 托管

```bash
# 写入 Pushgateway systemd 服务文件
cat > /etc/systemd/system/pushgateway.service <<'EOF'
[Unit]
Description=Pushgateway
Documentation=https://github.com/prometheus/pushgateway
After=network.target

[Service]
Type=simple
User=pushgateway
Group=pushgateway
ExecStart=/usr/local/bin/pushgateway \
  --web.listen-address=:9091
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

启动：

```bash
systemctl daemon-reload  # 重新加载 systemd 配置
systemctl enable --now pushgateway  # 设置 Pushgateway 开机自启并立即启动
systemctl status pushgateway  # 查看 Pushgateway 服务状态
```

访问：

```text
http://服务器IP:9091
```

## 10.6 Prometheus 对接

Prometheus 配置：

```yaml title="/etc/prometheus/prometheus.yml"
scrape_configs:  # 指标采集任务列表
  - job_name: pushgateway  # 采集 Pushgateway 指标
    honor_labels: true  # 保留 Pushgateway 中推送的原始标签
    static_configs:  # 使用静态目标配置
      - targets:  # Pushgateway 地址列表
          - 10.0.0.50:9091  # Pushgateway 地址
```

配置校验和重载：

```bash
promtool check config /etc/prometheus/prometheus.yml  # 校验 Prometheus 配置
curl -X POST http://localhost:9090/-/reload  # 重新加载 Prometheus 配置
```

## 10.7 推送指标示例

最简单示例：

```bash
echo 'backup_job_status 1' | curl --data-binary @- http://localhost:9091/metrics/job/backup  # 推送 backup 任务状态指标
```

带 instance 标签：

```bash
echo 'backup_job_duration_seconds 12.5' | curl --data-binary @- http://localhost:9091/metrics/job/backup/instance/db01  # 推送 backup 任务耗时指标
```

多指标示例：

```bash
cat <<'EOF' | curl --data-binary @- http://localhost:9091/metrics/job/nightly_report  # 推送 nightly_report 批任务指标
# TYPE nightly_report_status gauge
nightly_report_status 1
# TYPE nightly_report_duration_seconds gauge
nightly_report_duration_seconds 23.4
EOF
```

## 10.8 删除指标

Pushgateway 中的指标不会自动过期，任务结束后如果不清理，旧数据会一直存在。

删除整个 job：

```bash
curl -X DELETE http://localhost:9091/metrics/job/backup  # 删除 backup 任务的全部指标
```

删除指定 job + instance：

```bash
curl -X DELETE http://localhost:9091/metrics/job/backup/instance/db01  # 删除 backup 任务在 db01 实例下的指标
```

## 10.9 Docker Compose 示例

```yaml title="docker-compose.yml"
services:  # Compose 服务列表
  pushgateway:  # Pushgateway 服务
    image: prom/pushgateway:v1.11.1  # 使用固定版本 Pushgateway 镜像
    container_name: pushgateway  # 容器名称
    restart: unless-stopped  # 容器异常退出后自动重启，手动停止除外
    ports:  # 端口映射
      - "9091:9091"  # 暴露 Pushgateway Web 和 metrics 端口
```

启动：

```bash
docker compose up -d  # 后台启动 Pushgateway
docker compose logs -f pushgateway  # 查看 Pushgateway 容器日志
```

## 10.10 使用建议

- 只给短生命周期任务使用。
- 推送完数据后，根据场景决定是否删除旧指标。
- 不要把业务实例级长期指标通过 Pushgateway 持续推送。
- `job`、`instance` 标签命名要统一。

## 10.11 常见问题

### 10.11.1 指标一直不消失

原因：

- Pushgateway 不会自动清理旧指标。
- 任务结束后没有执行删除。

### 10.11.2 为什么 Prometheus 里指标看起来很旧

原因：

- Pushgateway 保存的是最后一次推送结果。
- 任务已经不再运行，但旧值仍然存在。

### 10.11.3 为什么不建议把常驻服务接入 Pushgateway

原因：

- 这违背了 Prometheus 主动抓取模型。
- 容易造成脏数据和过期数据难以治理。
- 服务异常退出后指标状态不一定能及时反映。

## 10.12 参考资料

- [Pushgateway](https://github.com/prometheus/pushgateway)
- [Prometheus Pushgateway Best Practices](https://prometheus.io/docs/practices/pushing/)
