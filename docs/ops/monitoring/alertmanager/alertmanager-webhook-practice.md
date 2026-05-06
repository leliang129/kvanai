---
title: Alertmanager Webhook 对接实践
sidebar_position: 5
---

# Alertmanager Webhook 对接实践


## 5.1 适用场景

Alertmanager 最通用的通知方式就是 Webhook。

适合场景：

- 对接自研告警平台
- 对接企业微信 / 钉钉中转服务
- 对接内部机器人
- 做告警再加工和二次路由

推荐思路：

- Alertmanager 不直接耦合太多通知逻辑
- 复杂逻辑放到 Webhook 接收端处理

## 5.2 基本链路

```text
Prometheus -> Alertmanager -> Webhook Receiver -> 企业微信 / 钉钉 / 自研平台
```

好处：

- 告警模板统一在接收端处理
- 更容易做鉴权、重试和审计
- 不同通知渠道可以复用同一接收服务

## 5.3 Webhook Receiver 基础配置

最简单示例：

```yaml title="/etc/alertmanager/alertmanager.yml"
receivers:  # 接收器列表
  - name: default-webhook  # 默认 Webhook 接收器名称
    webhook_configs:  # Webhook 通知配置
      - url: http://127.0.0.1:5001/alert  # Webhook 接收地址
        send_resolved: true  # 告警恢复时也发送通知
```

说明：

- `url`：Webhook 接收端地址
- `send_resolved`：是否发送恢复通知

## 5.4 路由到不同 Webhook

按告警级别分流：

```yaml
route:  # 根路由
  receiver: default-webhook  # 默认接收器
  routes:  # 子路由列表
    - matchers:  # critical 告警匹配条件
        - severity="critical"  # 匹配 critical 级别告警
      receiver: oncall-webhook  # 发送到值班 Webhook

    - matchers:  # warning 告警匹配条件
        - severity="warning"  # 匹配 warning 级别告警
      receiver: normal-webhook  # 发送到普通 Webhook

receivers:  # 接收器列表
  - name: default-webhook  # 默认接收器
    webhook_configs:  # Webhook 配置
      - url: http://127.0.0.1:5001/default  # 默认告警接收地址

  - name: oncall-webhook  # 严重告警接收器
    webhook_configs:  # Webhook 配置
      - url: http://127.0.0.1:5001/oncall  # 严重告警接收地址

  - name: normal-webhook  # 普通告警接收器
    webhook_configs:  # Webhook 配置
      - url: http://127.0.0.1:5001/normal  # 普通告警接收地址
```

## 5.5 按团队分流

```yaml
route:  # 根路由
  receiver: default-webhook  # 默认接收器
  routes:  # 子路由列表
    - matchers:  # 平台团队匹配条件
        - team="platform"  # 匹配 team=platform 的告警
      receiver: platform-webhook  # 发送到平台团队 Webhook

    - matchers:  # 数据库团队匹配条件
        - team="database"  # 匹配 team=database 的告警
      receiver: database-webhook  # 发送到数据库团队 Webhook
```

前提：

- Prometheus 告警规则里必须带上 `team` 标签。

## 5.6 本地测试方式

最简单测试：

```bash
nc -l 5001  # 临时监听 Webhook 请求
```

或者直接查询 Alertmanager 状态和告警：

```bash
curl http://localhost:9093/api/v2/status  # 查看 Alertmanager 当前状态
curl http://localhost:9093/api/v2/alerts  # 查看 Alertmanager 当前告警
```

## 5.7 接收端处理建议

Webhook 接收端通常至少需要做这些事情：

- 校验来源
- 解析 firing / resolved 状态
- 提取核心标签和注释
- 组装消息模板
- 转发到企业微信、钉钉或内部系统
- 记录发送日志

推荐字段：

- `alertname`
- `severity`
- `team`
- `service`
- `instance`
- `summary`
- `description`
- `status`

## 5.8 企业微信 / 钉钉实践建议

建议不要让 Alertmanager 直接硬编码到多个群机器人地址。

更稳妥的方案：

1. Alertmanager 统一发给 Webhook 服务。
2. Webhook 服务根据 `team`、`severity`、`service` 再分流。
3. 接收端自行拼装机器人消息格式。

这样做的好处：

- 路由逻辑集中
- 消息格式统一
- 更方便切换通知渠道

## 5.9 自研告警平台对接建议

对接自研平台时，接收端建议增加：

- 鉴权
- 幂等处理
- 重试
- 审计日志
- 失败回退策略

关键点：

- 同一告警重复发送时，不要重复创建工单
- 恢复通知要能和 firing 告警关联

## 5.10 常见问题

### 5.10.1 Alertmanager 有告警，但 Webhook 没收到

排查：

```bash
curl http://localhost:9093/api/v2/alerts  # 查看 Alertmanager 当前告警
journalctl -u alertmanager -n 200 --no-pager  # 查看 Alertmanager 日志
curl http://127.0.0.1:5001/health  # 检查 Webhook 服务是否可访问
```

常见原因：

- receiver URL 写错
- Webhook 服务未启动
- 网络不通
- route 未命中目标 receiver

### 5.10.2 firing 发到了，resolved 没发到

常见原因：

- `send_resolved: true` 未开启
- 接收端只处理 firing，忽略了 resolved

### 5.10.3 所有告警都走了默认 Webhook

常见原因：

- route 的 `matchers` 不匹配
- Prometheus 告警标签缺失
- 子路由顺序不合理

## 5.11 参考资料

- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Alertmanager Webhook Receiver Example](https://prometheus.io/docs/alerting/latest/notification_examples/)
