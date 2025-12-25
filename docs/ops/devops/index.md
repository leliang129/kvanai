---
sidebar_position: 1
---

# DevOps 与自动化流水线

本章节聚焦 CI/CD、GitOps 与运维脚本自动化，帮助团队将变更可视化、可审计并快速回滚。

## CI/CD 模板

- Build 阶段：Docker Buildx、Kaniko 或 BuildKit 以缓存优化。
- Test 阶段：并行化 e2e 与集成测试，利用 `kubectl-neat` 收集部署结果。
- Deploy 阶段：ArgoCD、Flux 或 Tekton 触发的渐进式发布。

## GitOps 工作流

1. Feature 合并后触发自动化部署。
2. ArgoCD 监控 Git 仓库并同步状态。
3. 通过 `ApplicationSet` 管理多集群部署。

## Shell/Python 工具片段

也可以分别查看：

- [Shell 工具箱](/docs/automation/shell/intro)
- [Python 自动化](/docs/automation/python/intro)

```bash
#!/usr/bin/env bash
set -euo pipefail

# 用于批量刷新集群镜像拉取密钥
declare -a namespaces=("prod" "staging")
for ns in "${namespaces[@]}"; do
  kubectl -n "$ns" create secret docker-registry regcred \
    --docker-server=registry.example.com \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_PASS" \
    --dry-run=client -o yaml | kubectl apply -f -
done
```

```python
# 连接数据库执行巡检 SQL
import mysql.connector

conn = mysql.connector.connect(host="db", user="ops", password="***", database="app")
cur = conn.cursor()
cur.execute("SHOW SLAVE STATUS")
print(cur.fetchone())
```

## 变更窗口策略

- Freeze：高风险节假日触发自动冻结，所有部署通过审批。
- Progressive Delivery：利用 Argo Rollouts/Flagger 进行流量切分，监控指标决定推进或回滚。
- 回滚：`kubectl rollout undo` + 数据库备份点恢复。

## 推荐工具

- Terraform、Crossplane 管理基础设施。
- Ansible、SaltStack 做配置统一。
- Argo Workflows 处理批处理/数据任务。

