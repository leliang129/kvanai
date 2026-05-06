---
title: Prometheus 采集配置
sidebar_position: 3
---

# Prometheus 采集配置


## 3.1 配置结构

Prometheus 采集配置核心在 `prometheus.yml`。

常见结构：

```yaml title="prometheus.yml"
global:  # 全局配置，未单独指定时作为默认值
  scrape_interval: 15s  # 默认每 15 秒抓取一次指标
  evaluation_interval: 15s  # 默认每 15 秒计算一次规则

rule_files:  # 告警规则和记录规则文件列表
  - /etc/prometheus/rules/*.yml  # 加载 rules 目录下所有 yml 文件

scrape_configs:  # 指标采集任务列表
  - job_name: prometheus  # 采集任务名称
    static_configs:  # 使用静态目标配置
      - targets:  # 当前任务的目标列表
          - localhost:9090  # Prometheus 自身指标地址
```

配置说明：

| 配置 | 说明 |
| --- | --- |
| `global.scrape_interval` | 默认采集间隔 |
| `global.evaluation_interval` | 规则计算间隔 |
| `rule_files` | 告警规则和记录规则文件 |
| `scrape_configs` | 指标采集任务 |

修改后先校验：

```bash
promtool check config /etc/prometheus/prometheus.yml  # 校验 Prometheus 主配置文件
```

reload：

```bash
curl -X POST http://localhost:9090/-/reload  # 重新加载 Prometheus 配置
```

## 3.2 static_configs

静态目标适合小规模环境或固定主机。

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: node  # 采集 Node Exporter 指标
    static_configs:  # 使用静态目标配置
      - targets:  # 当前任务的目标列表
          - 10.0.0.11:9100  # 第一台主机的 Node Exporter 地址
          - 10.0.0.12:9100  # 第二台主机的 Node Exporter 地址
          - 10.0.0.13:9100  # 第三台主机的 Node Exporter 地址
        labels:  # 给该组目标附加统一标签
          env: prod  # 标识环境为生产
          team: platform  # 标识负责团队为平台团队
```

建议：

- `job_name` 表示采集任务类型，不建议放具体 IP。
- `labels` 用于补充环境、团队、服务等维度。
- 多环境目标不要混在一个无法区分的 job 中。

## 3.3 file_sd_configs

文件发现适合目标经常变化但还没有接入完整服务发现的场景。

主配置：

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: node  # 采集 Node Exporter 指标
    file_sd_configs:  # 使用文件服务发现
      - files:  # target 文件匹配规则
          - /etc/prometheus/targets/node/*.yml  # 加载 node 目录下所有 yml target 文件
        refresh_interval: 30s  # 每 30 秒重新扫描一次 target 文件
```

目标文件：

```yaml title="/etc/prometheus/targets/node/prod.yml"
- targets:  # 第一组采集目标
    - 10.0.0.11:9100  # 生产环境第一台主机
    - 10.0.0.12:9100  # 生产环境第二台主机
  labels:  # 第一组目标的统一标签
    env: prod  # 标识环境为生产
    team: platform  # 标识负责团队为平台团队

- targets:  # 第二组采集目标
    - 10.0.1.11:9100  # 测试环境主机
  labels:  # 第二组目标的统一标签
    env: test  # 标识环境为测试
    team: backend  # 标识负责团队为后端团队
```

优点：

- 新增目标不需要修改主配置。
- 可以由 CMDB、脚本或发布系统生成 target 文件。
- 标签管理更清晰。

## 3.4 标签规划

推荐基础标签：

| 标签 | 示例 | 说明 |
| --- | --- | --- |
| `env` | `prod`、`test` | 环境 |
| `team` | `platform` | 负责团队 |
| `service` | `mysql`、`kafka` | 服务名 |
| `cluster` | `prod-a` | 集群 |
| `region` | `cn-shanghai` | 区域 |
| `role` | `broker`、`controller` | 节点角色 |

原则：

- 标签值保持稳定，不要使用高频变化值。
- 不要把 request id、用户 id、订单 id 等高基数字段放入指标标签。
- 告警路由依赖的标签必须规范化。
- Grafana 面板筛选依赖的标签必须统一。

## 3.5 relabel_configs

`relabel_configs` 在采集前处理 target 标签，常用于改写地址、过滤目标、生成标签。

### 3.5.1 改写 instance

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: node  # 采集 Node Exporter 指标
    static_configs:  # 使用静态目标配置
      - targets:  # 当前任务的目标列表
          - 10.0.0.11:9100  # Node Exporter 地址
    relabel_configs:  # 采集前对 target 标签做重写
      - source_labels: [__address__]  # 读取原始目标地址
        target_label: instance  # 写入 instance 标签
```

### 3.5.2 丢弃目标

```yaml
relabel_configs:  # 采集前对 target 标签做重写或过滤
  - source_labels: [env]  # 读取 env 标签
    regex: dev  # 匹配 dev 环境
    action: drop  # 丢弃匹配到的目标
```

### 3.5.3 保留目标

```yaml
relabel_configs:  # 采集前对 target 标签做重写或过滤
  - source_labels: [env]  # 读取 env 标签
    regex: prod  # 匹配 prod 环境
    action: keep  # 只保留匹配到的目标
```

## 3.6 metric_relabel_configs

`metric_relabel_configs` 在抓取指标后处理样本，适合丢弃不需要的指标或高基数标签。

丢弃指定指标：

```yaml
metric_relabel_configs:  # 抓取后、入库前对指标样本做处理
  - source_labels: [__name__]  # 读取指标名称
    regex: 'go_memstats_.*'  # 匹配 go_memstats_ 开头的指标
    action: drop  # 丢弃匹配到的指标样本
```

删除高基数标签：

```yaml
metric_relabel_configs:  # 抓取后、入库前对指标样本做处理
  - regex: 'pod_uid|container_id'  # 匹配 pod_uid 或 container_id 标签名
    action: labeldrop  # 删除匹配到的标签
```

注意：

- `metric_relabel_configs` 已经发生抓取，不能减少目标抓取成本，只能减少入库数据。
- 大规模环境应优先从 exporter 或应用侧减少高基数指标。

## 3.7 Blackbox 探测入口

Blackbox Exporter 常用于 HTTP、TCP、ICMP 探测。

```yaml
scrape_configs:  # 指标采集任务列表
  - job_name: blackbox-http  # HTTP 黑盒探测任务名称
    metrics_path: /probe  # 请求 Blackbox Exporter 的探测入口
    params:  # 传给 Blackbox Exporter 的请求参数
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

## 3.8 配置拆分建议

Prometheus 原生不支持直接 include 多个 scrape 文件。常见做法：

- 主配置保持稳定。
- target 使用 `file_sd_configs` 拆分。
- rule 使用 `rule_files` 拆分。
- 使用配置管理工具渲染 `prometheus.yml`。

目录示例：

```text
/etc/prometheus
├── prometheus.yml
├── rules
│   ├── node.yml
│   └── kafka.yml
└── targets
    ├── node
    │   ├── prod.yml
    │   └── test.yml
    └── blackbox
        └── http.yml
```

## 3.9 Targets down 排查

页面：

```text
http://prometheus.example.com:9090/targets
```

命令：

```bash
curl http://target:port/metrics  # 直接访问目标 Exporter 指标
curl http://localhost:9090/api/v1/targets  # 查看 Prometheus Targets API
```

常见原因：

- Exporter 未启动。
- Prometheus 到目标网络不通。
- `targets` 地址错误。
- 防火墙或安全组未放行。
- exporter 暴露路径不是 `/metrics`。
- 目标返回慢，超过 `scrape_timeout`。

## 3.10 参考资料

- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Prometheus File SD](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#file_sd_config)
- [Prometheus Relabeling](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#relabel_config)
- [Blackbox Exporter](https://github.com/prometheus/blackbox_exporter)
