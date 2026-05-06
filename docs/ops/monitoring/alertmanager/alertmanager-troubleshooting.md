---
title: Alertmanager 故障排查
sidebar_position: 4
---

# Alertmanager 故障排查


## 4.1 排查思路

Alertmanager 故障建议按链路排查：

1. Alertmanager 服务是否正常启动。
2. Alertmanager 配置是否正确加载。
3. Prometheus 是否真正把告警发到了 Alertmanager。
4. route 是否命中正确 receiver。
5. 告警是否被 silence 或 inhibit。
6. receiver 是否成功把通知发到外部系统。
7. HA 集群节点是否正常同步。

常用入口：

```text
http://alertmanager.example.com:9093
http://alertmanager.example.com:9093/#/alerts
http://alertmanager.example.com:9093/#/silences
```

## 4.2 服务启动失败

排查：

```bash
systemctl status alertmanager  # 查看 Alertmanager 服务状态
journalctl -u alertmanager -n 300 --no-pager  # 查看最近启动日志
amtool check-config /etc/alertmanager/alertmanager.yml  # 校验 Alertmanager 配置
```

常见原因：

- YAML 格式错误。
- route / receiver 配置不合法。
- Webhook URL 写错但语法仍然通过。
- 配置文件权限错误。
- 端口 `9093` 被占用。

端口检查：

```bash
ss -lntp | grep 9093  # 检查 9093 端口是否被占用
```

## 4.3 Prometheus 没把告警发过来

排查：

```bash
curl http://localhost:9090/api/v1/alerts  # 查看 Prometheus 当前告警
curl http://localhost:9093/api/v2/alerts  # 查看 Alertmanager 当前告警
```

检查 Prometheus 配置：

```yaml
alerting:  # Prometheus 告警发送配置
  alertmanagers:  # Alertmanager 实例列表
    - static_configs:  # 使用静态地址配置
        - targets:  # Alertmanager 地址列表
            - localhost:9093  # 本机 Alertmanager 地址
```

常见原因：

- Prometheus 未配置 `alerting.alertmanagers`。
- Prometheus 侧地址写错。
- Prometheus 到 Alertmanager 网络不通。
- Prometheus 当前并没有 firing 告警。
- Prometheus 规则未触发或 `for` 条件未满足。

## 4.4 Alertmanager 收到告警但没通知

排查方向：

- route 是否命中了正确 receiver。
- receiver 配置是否完整。
- 外部通知地址是否可访问。
- 告警是否被 silence。
- 告警是否被 inhibit。

检查 API：

```bash
curl http://localhost:9093/api/v2/alerts  # 查看 Alertmanager 当前告警
curl http://localhost:9093/api/v2/status  # 查看 Alertmanager 当前配置和状态
```

常见原因：

- 根路由 `receiver` 写错。
- 子路由 `matchers` 不匹配。
- Webhook URL 无法访问。
- 邮件或机器人配置缺失。
- 告警被静默或抑制。

## 4.5 路由不生效

现象：

- 所有告警都落到默认 receiver。
- `critical` 和 `warning` 没有分开。
- 团队路由没有命中。

检查配置重点：

```yaml
route:  # 根路由
  receiver: default-webhook  # 默认接收器
  routes:  # 子路由列表
    - matchers:  # 第一条子路由匹配条件
        - severity="critical"  # 匹配 critical 告警
      receiver: oncall-webhook  # 命中后发送到 oncall receiver
```

常见原因：

- `matchers` 标签名和 Prometheus 告警标签不一致。
- `team`、`severity`、`service` 标签未在告警规则中设置。
- 子路由顺序不合理，前面的规则已经吃掉了告警。

建议：

- 先确认 Prometheus 告警里实际有哪些标签。
- route 命中逻辑按“最具体优先，默认兜底”组织。

## 4.6 静默不生效

排查：

```bash
amtool --alertmanager.url=http://localhost:9093 silence query  # 查看当前静默列表
curl http://localhost:9093/api/v2/silences  # 查看静默 API 返回
```

常见原因：

- silence 匹配条件和告警标签不一致。
- 静默时间窗口已过期。
- 查询的是错误的 Alertmanager 节点。
- HA 集群同步异常，静默没有传播。

## 4.7 抑制不生效

检查配置：

```yaml
inhibit_rules:  # 抑制规则列表
  - source_matchers:  # 触发抑制的源告警
      - alertname="NodeDown"  # 节点不可达告警
    target_matchers:  # 被抑制的目标告警
      - severity=~"warning|critical"  # 抑制 warning 和 critical
    equal:  # 只有这些标签相同才抑制
      - instance  # 同一 instance 才生效
```

常见原因：

- 源告警并未 firing。
- `equal` 指定的标签值不同。
- `instance`、`cluster` 等标签没有统一。
- 目标告警标签条件不满足。

## 4.8 告警重复过多

常见原因：

- `group_by` 过细，导致无法合并。
- `repeat_interval` 太短。
- 两个 Prometheus 实例重复发送，但路由分组不合理。
- HA 集群配置不完整。

检查配置：

```yaml
route:  # 根路由
  group_by: [alertname, cluster, service]  # 告警分组标签
  group_wait: 30s  # 首次等待时间
  group_interval: 5m  # 同组新增告警发送间隔
  repeat_interval: 4h  # 未恢复告警重复通知间隔
```

处理建议：

- 不要把 `instance` 盲目放进 `group_by`。
- 调大 `repeat_interval`。
- Prometheus HA 场景下统一标签规划。

## 4.9 Webhook 通知失败

排查：

```bash
nc -l 5001  # 临时监听 Webhook 请求
curl http://localhost:9093/api/v2/status  # 查看 Alertmanager 状态
journalctl -u alertmanager -n 200 --no-pager  # 查看最近日志
```

常见原因：

- Webhook 服务未启动。
- URL 路径错误。
- DNS 解析异常。
- 防火墙或安全组未放行。
- 对方服务响应过慢或返回 5xx。

## 4.10 HA 集群不同步

现象：

- 一个节点有 silence，另一个没有。
- 集群内通知去重异常。
- 节点页面显示状态不一致。

检查：

```bash
ss -lntp | grep 9094  # 检查 9094 集群通信端口
curl http://localhost:9093/api/v2/status  # 查看集群状态
```

常见原因：

- `--cluster.listen-address` 未配置。
- `--cluster.peer` 配置错误。
- 9094 端口未放通。
- 节点之间主机名或 IP 无法互通。

## 4.11 常用诊断命令

```bash
systemctl status alertmanager  # 查看 Alertmanager 服务状态
journalctl -u alertmanager -n 300 --no-pager  # 查看 Alertmanager 日志
amtool check-config /etc/alertmanager/alertmanager.yml  # 校验 Alertmanager 配置
curl http://localhost:9093/api/v2/status  # 查看 Alertmanager 状态
curl http://localhost:9093/api/v2/alerts  # 查看 Alertmanager 当前告警
curl http://localhost:9093/api/v2/silences  # 查看 Alertmanager 当前静默
amtool --alertmanager.url=http://localhost:9093 silence query  # 查看静默列表
ss -lntp | grep 9093  # 检查 Web 端口监听状态
ss -lntp | grep 9094  # 检查集群通信端口监听状态
```

## 4.12 参考资料

- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [amtool](https://prometheus.io/docs/alerting/latest/amtool/)
