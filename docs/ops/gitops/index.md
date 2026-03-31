---
sidebar_position: 1
---

# GitOps

GitOps 作为独立专题，与 `Kubernetes` 平级，用于承载声明式交付、持续同步、环境管理与发布治理相关内容。

## 适合纳入本专题的内容

- ArgoCD
- FluxCD
- Argo Rollouts
- ApplicationSet
- GitOps 仓库结构设计
- 多环境发布策略
- 权限控制与审计
- 常见故障排查

## 当前内容

- [ArgoCD](./argocd/index.md)

## 推荐目录结构

```text
docs/ops/gitops/
├── _category_.json
├── index.md
├── argocd/
│   ├── _category_.json
│   ├── index.md
│   ├── install.md
│   ├── application.md
│   └── troubleshooting.md
├── fluxcd/
└── rollout/
```
