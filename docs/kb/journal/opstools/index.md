---
sidebar_position: 1
---

# 运维工具索引

以“拿来就用”为标准，记录命令、脚本片段、参数与注意事项。

## 常用命令模板

```bash
# 统一输出：时间 + 关键字段
date -Is; kubectl get po -A -o wide | rg "<keyword>"
```

```bash
# 快速定位某服务 5xx top 路径
rg " 5\\d\\d " access.log | awk '{print $7}' | sort | uniq -c | sort -nr | head
```

## 约定

- 命令尽量可复制执行（避免“口述步骤”）
- 一条工具记录包含：用途、示例、输出解释、风险点/回滚

## 新增一条记录

在 `docs/journal/opstools/` 下新建 `*.md`（例如 `kubectl-tricks.md`），建议包含：

```md
---
sidebar_position: 10
---

# <标题>

用途：…
示例：…
注意：…
```
