---
title: 监控系统架构总览
sidebar_position: 2
---

# 监控系统架构总览


## 2.1 目标

这一组监控文档的推荐边界是：

- `Prometheus` 负责采集、存储、查询、规则计算
- `Alertmanager` 负责告警路由、分组、静默、抑制、通知
- `Grafana` 负责展示、查询分析和权限协作

这样分层后，职责清晰，不会出现“Grafana 也做一套告警，Alertmanager 又做一套”的混乱情况。

## 2.2 三个组件的职责

| 组件 | 主要职责 |
| --- | --- |
| Prometheus | 抓取指标、存储 TSDB、执行 PromQL、计算告警规则 |
| Alertmanager | 接收告警、路由、分组、抑制、静默、通知发送 |
| Grafana | 展示面板、Explore 查询、数据源管理、权限与协作 |

核心原则：

- 采集和规则在 Prometheus
- 通知和降噪在 Alertmanager
- 展示和分析在 Grafana

## 2.3 基本数据流

```text
Exporter / Application
        |
        v
   Prometheus
        |
        +--> Grafana
        |
        +--> Alert Rules
               |
               v
         Alertmanager
               |
               v
        Webhook / Mail / IM
```

说明：

- 应用和 Exporter 暴露 `/metrics`
- Prometheus 定时抓取并入库
- Grafana 从 Prometheus 查询数据
- Prometheus 告警规则触发后发给 Alertmanager
- Alertmanager 负责路由和通知

## 2.4 推荐部署结构

### 2.4.1 单环境基础版

```text
Node Exporter / App Exporter
           |
           v
      Prometheus ----> Grafana
           |
           v
      Alertmanager
           |
           v
       企业微信 / 钉钉 / Webhook
```

适合：

- 单机房
- 小团队
- 测试环境

### 2.4.2 生产推荐版

```text
Exporters / Applications
           |
           v
   Prometheus A ----\
                     \
                      -> Thanos / Remote Storage -> Grafana
                     /
   Prometheus B ----/
           |
           v
   Alertmanager A <-> Alertmanager B
           |
           v
      通知渠道
```

适合：

- 生产环境
- 多实例高可用
- 需要长期存储
- 需要统一查询入口

## 2.5 文档边界建议

这套文档建议按下面方式理解：

- `monitoring/prometheus/`：采集、PromQL、规则、Exporter、排障、存储
- `monitoring/alertmanager/`：安装、路由、静默、抑制、通知、排障
- `monitoring/grafana/`：安装、provisioning、权限、面板、排障

这样拆分有两个好处：

- 阅读路径更清晰。
- 后期扩展 Loki、Tempo、VictoriaMetrics、Thanos 时也有位置可放。

## 2.6 推荐实践

- Prometheus 只做采集和规则，不直接承担复杂展示职责。
- Alertmanager 统一做告警通知，不在 Grafana 再做一套主告警体系。
- Grafana 聚焦可视化、权限和协作。
- 生产环境至少规划双 Prometheus 和双 Alertmanager。
- 长期存储和全局查询尽量交给 Thanos 或远端存储方案。

## 2.7 后续扩展方向

如果后面继续补文档，监控系统目录（`monitoring`）可以继续扩展：

- `thanos/`
- `victoriametrics/`
- `loki/`
- `tempo/`
- `otel/`

这样监控系统会从“指标监控”自然扩展到“完整可观测性”。
