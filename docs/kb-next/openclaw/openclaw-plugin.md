---
title: OpenClaw 运维技能速查表
tags: [openclaw, plugin, devops, cloud]
sidebar_position: 3
---

## 容器 & 编排

### `k8s-capi`

Kubernetes 集群生命周期管理，支持 Cluster API 自动化集群创建、升级、节点扩缩容与跨云迁移。

```bash
openclaw plugins install k8s-capi
```

### `docker-manager`

Docker 容器与镜像管理，支持镜像构建、容器生命周期管理与资源监控。

```bash
openclaw plugins install docker-manager
```

### `helm-charts`

Helm 包管理与部署，支持 Chart 拉取、安装、升级和回滚。

```bash
openclaw plugins install helm-charts
```

## 基础设施即代码

### `terraform-engineer`

Terraform IaC 工程能力，覆盖 AWS / Azure / GCP 三大云，支持模块化、状态管理与 plan/apply 自动化。

```bash
openclaw plugins install terraform-engineer
```

### `ansible-automation`

Ansible 配置管理，支持 Playbook 编排、批量配置、动态 Inventory 与自动化故障恢复。

```bash
openclaw plugins install ansible-automation
```

## CI/CD 流水线

### `cicd-automation`

CI/CD 流水线自动化，支持 GitHub Actions、GitLab CI、Jenkins 等平台的流程管理。

```bash
openclaw plugins install cicd-automation
```

### `github`

GitHub 全功能集成，支持 PR、Actions、Release、仓库管理与自动化工作流创建。

```bash
openclaw plugins install github
```

## 监控 & 可观测性

### `prometheus-monitoring`

Prometheus 监控规则与指标采集，支持 PromQL 查询与告警策略配置。

```bash
openclaw plugins install prometheus-monitoring
```

### `grafana-dashboards`

Grafana 可视化仪表盘，支持仪表盘模板管理与 Loki 日志可视化联动。

```bash
openclaw plugins install grafana-dashboards
```

### `elk-log-analysis`

ELK 日志分析，支持 Elasticsearch 检索、Logstash 管道与 Kibana 可视化。

```bash
openclaw plugins install elk-log-analysis
```

## 云平台管理

### `aws-cli-manager`

AWS 资源管理，覆盖 EC2、S3、RDS、Lambda、EKS，支持 IAM 自动化与成本分析。

```bash
openclaw plugins install aws-cli-manager
```

### `azure-devops`

Azure 平台自动化，覆盖 Azure 资源编排、AKS 集群、Azure DevOps 流水线与权限管理。

```bash
openclaw plugins install azure-devops
```

## 安全 & 合规

### `security-audit`

安全审计与漏洞扫描，支持漏洞检测（CVE）、IAM 权限审计与基线合规检查。

```bash
openclaw plugins install security-audit
```

### `secrets-manager`

密钥与凭证管理，支持 Vault、AWS Secrets Manager 等集中式密钥托管。

```bash
openclaw plugins install secrets-manager
```

## 自动化 & 工作流

### `automation-workflows`

自动化工作流设计与执行，支持跨工具编排（如 Slack、PagerDuty、监控告警系统）。

```bash
openclaw plugins install automation-workflows
```

## 系统 & 数据运维

### `linux-sysadmin`

Linux 系统管理，覆盖性能分析、用户权限、systemd 服务管理与任务调度。

```bash
openclaw plugins install linux-sysadmin
```

### `database-ops`

数据库运维管理，支持 MySQL / PostgreSQL / Redis 的备份恢复、性能优化与迁移。

```bash
openclaw plugins install database-ops
```

## 技能优先级参考

| 技能                    | 优先级 | 适用场景     |
| ----------------------- | ------ | ------------ |
| `k8s-capi`              | ★★★    | K8s 集群运维 |
| `terraform-engineer`    | ★★★    | 云基础设施   |
| `docker-manager`        | ★★★    | 容器化管理   |
| `prometheus-monitoring` | ★★★    | 系统监控     |
| `cicd-automation`       | ★★☆    | 自动化发布   |
| `security-audit`        | ★★☆    | 安全合规     |
| `automation-workflows`  | ★★☆    | 流程自动化   |
| `elk-log-analysis`      | ★★☆    | 日志分析     |

## 最佳实践

- 安全隔离：通过容器运行 OpenClaw，为 Agent 分配最小权限，避免直接使用高权限凭证。
- 密钥管理：集中管理密钥（如 Vault），所有 API Key 通过密钥系统注入，避免明文写入配置文件。
- 版本控制：基础设施代码统一由 Git 管理，先在测试环境验证后再进入生产。
