---
title: Alertmanager 告警路由
sidebar_position: 3
---

# Alertmanager 告警路由


## 6.1 Alertmanager 作用

Alertmanager 负责处理 Prometheus 发来的告警。

核心能力：

- 告警分组。
- 告警路由。
- 告警抑制。
- 告警静默。
- 通知重试。
- 对接邮件、Webhook、Slack、企业微信、钉钉等。

链路：

```text
Prometheus -> Alertmanager -> 通知渠道
```

## 6.2 基础配置

```yaml title="/etc/alertmanager/alertmanager.yml"
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
```

检查配置：

```bash
amtool check-config /etc/alertmanager/alertmanager.yml  # 校验 Alertmanager 配置
```

## 6.3 路由配置

按 `severity` 路由：

```yaml
route:  # 根路由
  receiver: default-webhook  # 默认接收器
  group_by: [alertname, cluster, service]  # 按告警名、集群和服务分组
  routes:  # 子路由列表，按顺序匹配
    - matchers:  # critical 告警匹配条件
        - severity="critical"  # 匹配 severity=critical 的告警
      receiver: oncall-webhook  # 发送到值班接收器
      repeat_interval: 30m  # 未恢复时每 30 分钟重复通知

    - matchers:  # warning 告警匹配条件
        - severity="warning"  # 匹配 severity=warning 的告警
      receiver: warning-webhook  # 发送到 warning 接收器
      repeat_interval: 4h  # 未恢复时每 4 小时重复通知
```

按团队路由：

```yaml
routes:  # 子路由列表
  - matchers:  # 平台团队匹配条件
      - team="platform"  # 匹配 team=platform 的告警
    receiver: platform-webhook  # 发送到平台团队接收器

  - matchers:  # 数据库团队匹配条件
      - team="database"  # 匹配 team=database 的告警
    receiver: database-webhook  # 发送到数据库团队接收器
```

## 6.4 分组策略

常用参数：

| 参数 | 说明 |
| --- | --- |
| `group_by` | 哪些标签相同的告警合并 |
| `group_wait` | 首次等待多久再发送 |
| `group_interval` | 同组新告警间隔 |
| `repeat_interval` | 未恢复告警重复通知间隔 |

建议：

- `group_by` 至少包含 `alertname`、`cluster`、`service`。
- `critical` 告警重复间隔短一些。
- `warning` 告警重复间隔长一些。

## 6.5 抑制规则

抑制用于避免上游故障导致下游大量告警。

示例：节点宕机时，抑制该节点上的服务告警。

```yaml
inhibit_rules:  # 抑制规则列表
  - source_matchers:  # 触发抑制的源告警
      - alertname="NodeDown"  # 节点不可达告警作为源告警
    target_matchers:  # 被抑制的目标告警
      - severity=~"warning|critical"  # 抑制 warning 或 critical 级别告警
    equal:  # 源告警和目标告警必须相同的标签
      - instance  # 只有同一 instance 的告警才会被抑制
```

说明：

- `source_matchers` 是触发抑制的告警。
- `target_matchers` 是被抑制的告警。
- `equal` 表示这些标签相同才抑制。

## 6.6 静默

Web 页面：

```text
http://alertmanager.example.com:9093/#/silences
```

命令创建静默：

```bash
amtool --alertmanager.url=http://localhost:9093 silence add alertname=NodeDown instance=10.0.0.11:9100 --duration=2h --comment="maintenance"  # 创建 2 小时静默
```

查看静默：

```bash
amtool --alertmanager.url=http://localhost:9093 silence query  # 查看静默列表
```

## 6.7 Webhook 接收示例

Alertmanager Webhook 会发送 JSON。

测试用 nc：

```bash
nc -l 5001  # 临时监听 Webhook 请求
```

Receiver：

```yaml
receivers:  # 接收器列表
  - name: default-webhook  # 接收器名称
    webhook_configs:  # Webhook 通知配置
      - url: http://127.0.0.1:5001/alert  # Webhook 接收地址
        send_resolved: true  # 告警恢复时也发送通知
```

生产环境通常对接：

- 自研告警平台。
- 钉钉机器人。
- 企业微信机器人。
- PagerDuty / Opsgenie。
- Slack / Teams。

## 6.8 常见问题

### 6.8.1 Prometheus 告警没有到 Alertmanager

排查：

```bash
curl http://localhost:9090/api/v1/alerts  # 查看 Prometheus 当前告警
curl http://localhost:9093/api/v2/alerts  # 查看 Alertmanager 当前告警
```

常见原因：

- Prometheus 未配置 `alerting.alertmanagers`。
- Alertmanager 地址错误。
- 网络不通。
- Prometheus 规则未触发。

### 6.8.2 告警没有通知

排查：

- Alertmanager 是否收到告警。
- route 是否匹配正确 receiver。
- receiver Webhook 是否可访问。
- 告警是否被 silence。
- 告警是否被 inhibit。

### 6.8.3 告警重复太多

处理：

- 调整 `group_by`。
- 增大 `repeat_interval`。
- 配置 `inhibit_rules`。
- 优化 Prometheus 告警规则。

## 6.9 参考资料

- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [amtool](https://prometheus.io/docs/alerting/latest/amtool/)
