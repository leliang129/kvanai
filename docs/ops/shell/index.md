---
sidebar_position: 1
---

# Shell 工具箱概览

Shell 更像一把瑞士军刀：写得少、跑得快、哪里都能用。适合做现场排障、批量操作、日志切片和临时自动化。

## 推荐习惯

- 默认开启严格模式：`set -euo pipefail`
- 明确输入输出：参数、环境变量、日志、退出码
- 先做 dry-run，再批量执行：`--dry-run=client` / `--server-dry-run`
- 批量操作要可回滚：记录变更前状态、保留执行清单

## 常用工具栈

- 文本：`awk` / `sed` / `jq` / `yq`
- 并发：`xargs -P` / `parallel`
- 网络：`curl` / `dig` / `tcpdump`
- 容器与集群：`docker` / `kubectl` / `helm`

