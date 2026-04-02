---
title: RBAC 权限控制
sidebar_position: 9
---

# RBAC 权限控制

在 Kubernetes 中，认证（Authentication）解决的是“**你是谁**”，授权（Authorization）解决的是“**你能做什么**”。

`RBAC`（Role-Based Access Control，基于角色的访问控制）是 Kubernetes 最常用的授权模型。它的目标不是把所有人都挡在门外，而是：

- 让用户、程序、控制器只拿到**最小必要权限**
- 把“谁能访问什么资源、能做哪些动作”配置成可审计、可声明式管理的对象
- 避免直接把 `cluster-admin` 这种超级权限发给所有人

如果你把 Kubernetes 看成一个资源系统，那么 RBAC 本质上就是：

- 对哪些资源（resources）
- 可以做哪些动作（verbs）
- 这些权限授予给谁（subjects）

## 1. RBAC 解决什么问题

Kubernetes 集群里几乎所有对象都可以通过 API 操作，例如：

- `Pods`
- `Deployments`
- `ConfigMaps`
- `Secrets`
- `Services`
- `Namespaces`
- `Nodes`

而这些对象的常见操作包括：

- `get`
- `list`
- `watch`
- `create`
- `update`
- `patch`
- `delete`

如果没有合理的权限边界，就会出现典型风险：

- 普通业务账号可以误删生产资源
- 任意 Pod 都能读取 Secret
- 自动化程序拥有远超实际需要的权限
- 某个命名空间内的服务账号被横向扩展为“全集群管理员”

所以 RBAC 的核心不是“配出来能用”，而是“**按最小权限原则配出来**”。

## 2. RBAC 的五个核心对象

RBAC 最重要的对象有 5 个：

- `Role`
- `ClusterRole`
- `RoleBinding`
- `ClusterRoleBinding`
- `ServiceAccount`

### 2.1 `Role`

`Role` 用来定义**某个命名空间内**的一组权限规则。

它只在自己所在的 namespace 内生效。

### 2.2 `ClusterRole`

`ClusterRole` 用来定义**集群级别**的一组权限规则。

它有两种常见用途：

- 给集群级资源授权，例如 `nodes`、`persistentvolumes`
- 定义“可复用角色模板”，再通过 `RoleBinding` 绑定到某个具体 namespace 中使用

### 2.3 `RoleBinding`

`RoleBinding` 用来把一个 `Role` 或 `ClusterRole` 绑定给某些主体（subjects），但授权范围只在**当前 namespace** 内。

一个非常容易混淆但非常重要的点：

- `RoleBinding` **即使绑定的是 `ClusterRole`**
- 它授予的权限范围依然只在**当前命名空间**

### 2.4 `ClusterRoleBinding`

`ClusterRoleBinding` 用来把 `ClusterRole` 绑定给主体，而且授权范围是**整个集群**。

这类绑定要特别谨慎，因为一旦配置过宽，影响的是所有 namespace。

### 2.5 `ServiceAccount`

`ServiceAccount` 是 Kubernetes 内部工作负载最常见的身份载体。

它主要给：

- Pod
- 控制器
- 自动化任务
- 集群内程序

提供访问 API Server 的身份。

与之相对：

- `User`：通常由集群外部身份系统管理，Kubernetes 不直接存储“普通用户对象”
- `Group`：也是逻辑身份集合，通常来自外部认证系统或系统内置组
- `ServiceAccount`：Kubernetes 内部原生对象，可通过 YAML 和 API 管理

## 3. 先理解：RBAC 是怎么表达权限的

一条典型的 RBAC 权限规则通常由以下要素组成：

- `apiGroups`：操作哪个 API 组
- `resources`：操作哪类资源
- `verbs`：允许做哪些动作
- `resourceNames`：可选，限制到具体资源名

比如：

- 允许读取某个 namespace 中的 Pod：
  - `apiGroups: [""]`
  - `resources: ["pods"]`
  - `verbs: ["get", "list", "watch"]`

这里 `apiGroups: [""]` 表示 Kubernetes 核心组（core API group），例如：

- `pods`
- `services`
- `configmaps`
- `secrets`

而像 `deployments` 则属于：

- `apiGroups: ["apps"]`

## 4. 一个最常见的 RBAC 场景

假设你要给某个业务 Pod 只授予下面这类权限：

- 只能在 `default` 命名空间内
- 读取 `pods` 和 `configmaps`
- 不能创建、删除、修改任何资源

这就是一个非常典型的 **namespace 内只读权限** 场景。

通常会用到 3 个对象：

1. `ServiceAccount`
2. `Role`
3. `RoleBinding`

## 5. ServiceAccount 完整资源清单（含注释）

```yaml
apiVersion: v1  # API 版本，ServiceAccount 属于核心组 v1
kind: ServiceAccount  # 资源类型：服务账号
metadata:
  name: app-reader  # ServiceAccount 名称
  namespace: default  # 所属命名空间
  labels:
    app.kubernetes.io/name: app-reader
```

### 5.1 ServiceAccount 关键字段解释

- `apiVersion: v1`：ServiceAccount 属于 Kubernetes 核心 API 组。
- `kind: ServiceAccount`：声明资源类型为服务账号。
- `metadata.name`：ServiceAccount 名称，Pod 引用时要用到。
- `metadata.namespace`：ServiceAccount 的作用域命名空间。

可以把它理解为：

- `ServiceAccount` 决定“Pod 以什么身份访问 API Server”
- 但它本身**不直接等于权限**
- 真正的权限还要靠 `Role/ClusterRole + Binding` 授予

## 6. Role 完整资源清单（含注释）

下面这个 `Role` 表示：

- 只在 `default` 命名空间生效
- 允许读取 `pods` 和 `configmaps`
- 不允许修改资源

```yaml
apiVersion: rbac.authorization.k8s.io/v1  # RBAC API 版本
kind: Role  # 资源类型：命名空间级角色
metadata:
  name: pod-configmap-reader  # Role 名称
  namespace: default  # Role 只在该 namespace 内生效
rules:
  - apiGroups: [""]  # 核心 API 组，pods/configmaps 都属于这里
    resources: ["pods", "configmaps"]  # 允许访问的资源类型
    verbs: ["get", "list", "watch"]  # 允许执行的动作：只读
```

### 6.1 Role 关键字段解释

- `apiVersion: rbac.authorization.k8s.io/v1`：RBAC 对象所属 API 组。
- `kind: Role`：声明这是一个命名空间级角色。
- `metadata.namespace`：Role 只在当前命名空间里有效。
- `rules`：权限规则列表。
- `apiGroups`：指定资源所属 API 组。
- `resources`：指定允许访问哪些资源。
- `verbs`：指定允许执行哪些操作。

### 6.2 常见 `verbs` 怎么理解

- `get`：读取单个对象
- `list`：列出对象集合
- `watch`：持续监听对象变化
- `create`：创建对象
- `update`：整体更新对象
- `patch`：局部更新对象
- `delete`：删除对象

只读场景，最常见的组合就是：

```yaml
verbs: ["get", "list", "watch"]
```

## 7. RoleBinding 完整资源清单（含注释）

这个 `RoleBinding` 的作用是：

- 把 `pod-configmap-reader` 这个 Role
- 绑定给 `app-reader` 这个 ServiceAccount
- 授权范围只在 `default` namespace

```yaml
apiVersion: rbac.authorization.k8s.io/v1  # RBAC API 版本
kind: RoleBinding  # 资源类型：命名空间级角色绑定
metadata:
  name: app-reader-binding  # RoleBinding 名称
  namespace: default  # 权限生效范围仍然是当前 namespace
subjects:
  - kind: ServiceAccount  # 被授权主体类型：服务账号
    name: app-reader  # ServiceAccount 名称
    namespace: default  # ServiceAccount 所在命名空间
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role  # 绑定的是一个 Role
  name: pod-configmap-reader  # 被绑定的 Role 名称
```

### 7.1 RoleBinding 关键字段解释

- `kind: RoleBinding`：声明这是命名空间级绑定对象。
- `subjects`：权限授予给谁，可以是 `User`、`Group` 或 `ServiceAccount`。
- `subjects[].kind`：主体类型。
- `roleRef`：引用被绑定的角色。
- `roleRef.kind`：可以是 `Role`，也可以是 `ClusterRole`。
- `metadata.namespace`：决定最终权限在哪个 namespace 生效。

这里最关键的理解是：

- `subjects` 决定“给谁”
- `roleRef` 决定“给什么权限”
- `metadata.namespace` 决定“权限在哪儿生效”

## 8. 把 ServiceAccount 用到 Pod 里

上面创建完 `ServiceAccount`、`Role` 和 `RoleBinding` 之后，还需要在 Pod / Deployment 中显式指定：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rbac-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rbac-demo
  template:
    metadata:
      labels:
        app: rbac-demo
    spec:
      serviceAccountName: app-reader  # Pod 使用这个 ServiceAccount 身份
      containers:
        - name: app
          image: bitnami/kubectl:1.30
          command: ["sleep", "3600"]
```

如果不指定 `serviceAccountName`，Pod 默认会使用当前 namespace 的 `default` ServiceAccount。

## 9. 如何验证 RBAC 是否生效

最常用的是 `kubectl auth can-i`。

### 9.1 验证某个 ServiceAccount 是否有权限

```bash
kubectl auth can-i get pods \
  --as=system:serviceaccount:default:app-reader \
  -n default

kubectl auth can-i delete pods \
  --as=system:serviceaccount:default:app-reader \
  -n default
```

预期通常是：

- `get pods` → `yes`
- `delete pods` → `no`

### 9.2 验证 Pod 内的实际权限

如果容器镜像中有 `kubectl`，也可以在 Pod 内直接测：

```bash
kubectl exec -it deploy/rbac-demo -- sh
kubectl get pods
kubectl get configmaps
kubectl delete pod xxx
```

这样能验证“这个工作负载实际拿到的权限”是否符合预期。

## 10. ClusterRole 与 ClusterRoleBinding

当权限不再局限于单个 namespace，而是涉及全局资源或全局范围时，就需要 `ClusterRole` 和 `ClusterRoleBinding`。

### 10.1 ClusterRole 完整资源清单（含注释）

下面这个例子表示：

- 允许读取整个集群的 `nodes`
- 同时允许读取所有 namespace 中的 `namespaces`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole  # 资源类型：集群级角色
metadata:
  name: node-reader
rules:
  - apiGroups: [""]
    resources: ["nodes", "namespaces"]
    verbs: ["get", "list", "watch"]
```

### 10.2 ClusterRole 关键字段解释

- `kind: ClusterRole`：声明为集群级角色。
- `rules`：和 `Role` 一样，都是权限规则集合。
- `ClusterRole` 没有 `metadata.namespace`，因为它天然是全局对象。

### 10.3 ClusterRoleBinding 完整资源清单（含注释）

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding  # 资源类型：集群级角色绑定
metadata:
  name: app-reader-node-view
subjects:
  - kind: ServiceAccount
    name: app-reader
    namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole  # 绑定集群角色
  name: node-reader
```

### 10.4 ClusterRoleBinding 关键字段解释

- `kind: ClusterRoleBinding`：声明这是一个全局绑定。
- `subjects`：定义哪些主体拿到权限。
- `roleRef.kind: ClusterRole`：只能绑定 `ClusterRole`。
- `ClusterRoleBinding` 一旦生效，权限影响范围是整个集群。

## 11. 一个非常重要的面试 / 实战点

### `RoleBinding` 可以绑定 `ClusterRole`

这是 Kubernetes RBAC 里非常实用的一种用法。

例如，你可以定义一个可复用的 `ClusterRole`：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
```

然后在某个 namespace 里，只通过 `RoleBinding` 授权：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: development
subjects:
  - kind: ServiceAccount
    name: app-reader
    namespace: development
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: secret-reader
```

这时虽然绑定的是 `ClusterRole`，但权限范围仍然只在：

- `development` 这个 namespace

这是很多团队做“统一角色模板 + 按 namespace 发放权限”的常见方式。

## 12. 常见内置角色怎么用

Kubernetes 自带一些常用 `ClusterRole`，例如：

- `view`：只读
- `edit`：可修改大多数命名空间资源
- `admin`：namespace 管理员
- `cluster-admin`：集群管理员

一个很常见的绑定方式是，把 `view` 绑定给某个 ServiceAccount：

```bash
kubectl create rolebinding my-sa-view \
  --clusterrole=view \
  --serviceaccount=default:app-reader \
  --namespace=default
```

这比手写一大堆只读规则更快，但要注意：

- 内置角色方便，但不一定最细粒度
- 生产环境优先考虑按需自定义最小权限规则

## 13. 常见问题与排错

### 13.1 为什么 Pod 访问 API 被拒绝？

优先检查：

```bash
kubectl get sa -n default
kubectl get role,rolebinding -n default
kubectl get clusterrole,clusterrolebinding
kubectl auth can-i get pods \
  --as=system:serviceaccount:default:app-reader \
  -n default
```

常见原因：

- Pod 没指定 `serviceAccountName`
- `RoleBinding` 绑错了对象
- Role 在错误的 namespace
- `verbs/resources/apiGroups` 写错

### 13.2 为什么有了 Role 还是没有权限？

因为 `Role` 只是“定义权限规则”，它本身不会自动生效。

必须再有：

- `RoleBinding`
- 或 `ClusterRoleBinding`

才能把权限真正授予某个主体。

### 13.3 为什么绑定了 ClusterRole，权限还是只有单 namespace？

因为你用的是 `RoleBinding`，而不是 `ClusterRoleBinding`。

- `RoleBinding`：权限范围看绑定对象所在 namespace
- `ClusterRoleBinding`：权限范围是整个集群

### 13.4 为什么不要随便给 `cluster-admin`？

因为它几乎等于“全权限”。

一旦给到：

- 普通业务 Pod
- 默认 ServiceAccount
- 不受控的自动化脚本

就可能带来严重横向风险。

## 14. 生产实践建议

1. **优先给 ServiceAccount 授权，不直接复用 default。**
2. **一个应用一个 ServiceAccount。** 不要多个系统共用同一身份。
3. **先写最小权限，再逐步放开。** 不要一开始就给 `edit` / `admin` / `cluster-admin`。
4. **能用 RoleBinding 就不要用 ClusterRoleBinding。**
5. **优先自定义精细 Role。** 内置角色适合快速起步，不一定适合生产最小权限治理。
6. **上线前用 `kubectl auth can-i` 做验证。**
7. **对 Secret 的读权限要格外谨慎。** “能读 Secret” 往往意味着能拿到更高权限凭据。

## 15. 常用命令速查

```bash
# 查看 RBAC 对象
kubectl get sa
kubectl get role -A
kubectl get rolebinding -A
kubectl get clusterrole
kubectl get clusterrolebinding

# 查看详细定义
kubectl describe role <name> -n <namespace>
kubectl describe rolebinding <name> -n <namespace>
kubectl describe clusterrole <name>
kubectl describe clusterrolebinding <name>

# 权限验证
kubectl auth can-i get pods --as=system:serviceaccount:default:app-reader -n default
kubectl auth can-i create deployments --as=system:serviceaccount:default:app-reader -n default
```

## 参考资料

- Using RBAC Authorization:
  - https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- Authorization:
  - https://kubernetes.io/docs/reference/access-authn-authz/authorization/
- Authentication:
  - https://kubernetes.io/docs/reference/access-authn-authz/authentication/
- Service Accounts:
  - https://kubernetes.io/docs/concepts/security/service-accounts/
