---
sidebar_position: 1
---

# ArgoCD

ArgoCD 归类在 `GitOps` 专题下，用于承载应用同步、声明式发布、权限控制与故障排查等内容。

## 当前文档

- [ArgoCD 安装部署](./install.md)

## 建议收录主题

- 安装与初始化
- Application / AppProject 设计
- Repository 与凭据管理
- Sync Policy 与自动同步策略
- RBAC 与 SSO
- 常见故障排查

## 推荐文档结构

```text
docs/ops/gitops/argocd/
├── _category_.json
├── index.md
├── install.md
├── application.md
├── sync-policy.md
├── rbac.md
└── troubleshooting.md
```

## 后续建议

如果你后面准备继续补内容，建议优先新增以下几篇：

1. `install.md`：安装、访问、初始密码、仓库接入
2. `application.md`：`Application` 与 `AppProject` 基础用法
3. `troubleshooting.md`：同步失败、健康检查异常、权限问题
