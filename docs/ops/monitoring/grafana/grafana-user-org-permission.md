---
title: Grafana 用户组织与权限
sidebar_position: 5
---

# Grafana 用户组织与权限


## 5.1 权限模型概览

Grafana 的权限通常分为几层：

- Organization
- Team
- Folder
- Dashboard
- Data source

如果不提前规划，最常见的问题就是“所有人都是 Admin”或者“业务方能看到不该看的面板和数据源”。

## 5.2 基础角色

Grafana 常见基础角色：

| 角色 | 说明 |
| --- | --- |
| `Viewer` | 只能查看 Dashboard 和 Explore 权限范围内的数据 |
| `Editor` | 可以修改 Dashboard、面板和部分配置 |
| `Admin` | 拥有组织级管理权限 |

建议：

- 普通使用者默认 `Viewer`。
- 需要维护面板的同学给 `Editor`。
- `Admin` 只保留给平台管理员。

## 5.3 Organization

Organization 是 Grafana 内的逻辑隔离单位。

适合场景：

- 多租户场景。
- 内外部团队完全隔离。
- 不同业务线需要独立管理用户和面板。

建议：

- 小团队内部通常一个 Organization 就够。
- 不要为了环境区分而滥用多个 Organization，环境更适合用 Folder、Team 或数据源区分。

## 5.4 Team

Team 是权限管理的核心抓手，适合把用户按职责分组。

常见分组：

- `platform`
- `backend`
- `database`
- `middleware`
- `observer`

推荐做法：

- 权限尽量赋给 Team，不直接赋给个人。
- 用户加入对应 Team 后自动继承权限。

## 5.5 Folder 权限

Folder 是 Dashboard 权限管理的主要边界。

推荐目录：

```text
Platform
Application
Database
Middleware
Test
```

典型策略：

- `Platform`：平台团队可编辑，其他团队只读。
- `Application`：业务团队可编辑，平台团队可读或可管理。
- `Test`：测试环境面板允许更灵活调整。

## 5.6 Dashboard 权限

Dashboard 权限适合在 Folder 之上做更细粒度控制。

建议：

- 优先用 Folder 做大多数授权。
- 只有在个别敏感 Dashboard 需要单独控制时，再单独授权。
- 避免到处给单个 Dashboard 打散权限，后期会很难维护。

## 5.7 Data Source 权限

数据源权限决定了谁能查询哪些后端。

建议：

- 生产数据源不要默认开放给所有编辑者。
- 生产与测试环境数据源分开。
- 敏感数据源限制到指定 Team。

典型命名：

- `Prometheus-prod`
- `Prometheus-test`
- `Loki-prod`
- `Loki-test`

## 5.8 推荐授权模型

中小团队推荐模型：

| 对象 | 平台团队 | 业务团队 | 普通查看者 |
| --- | --- | --- | --- |
| 生产数据源 | 管理 | 只读或限制访问 | 不直接管理 |
| Platform Folder | 编辑 | 只读 | 只读 |
| Application Folder | 管理 | 编辑 | 只读 |
| Database Folder | 平台 / DBA 编辑 | 只读 | 只读 |

原则：

- 数据源控制比 Dashboard 控制更重要。
- 编辑权限只给真正维护面板的人。
- 通过 Team 统一授权，不直接给个人堆权限。

## 5.9 常见问题

### 5.9.1 为什么用户能看见不该看的面板

原因通常是：

- Folder 权限放得太宽。
- 用户被加进了错误 Team。
- Organization 没有做隔离。

### 5.9.2 为什么用户能改生产面板

原因通常是：

- 给了 `Editor` 角色且 Folder 可写。
- `allowUiUpdates` 配合 provisioning 没规划好。

### 5.9.3 为什么用户看不到数据源

原因通常是：

- 数据源权限没分配。
- 用户不在对应 Team。
- 所在 Organization 不一致。

## 5.10 实践建议

- 先设计 Folder 结构，再发放权限。
- Team 先行，个人权限后置。
- 生产和测试环境的数据源分离。
- 面板目录按职责分层，不按人分。
- 定期审计 Admin 用户和高权限 Team。

## 5.11 参考资料

- [Grafana Roles and Permissions](https://grafana.com/docs/grafana/latest/administration/roles-and-permissions/)
- [Grafana Teams](https://grafana.com/docs/grafana/latest/administration/team-management/)
- [Grafana Folder Permissions](https://grafana.com/docs/grafana/latest/administration/user-management/manage-dashboard-permissions/)
