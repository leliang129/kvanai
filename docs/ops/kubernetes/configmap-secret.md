---
title: ConfigMap 与 Secret
sidebar_position: 8
---

# ConfigMap 与 Secret

在 Kubernetes 里，应用配置通常分成两类：

- **普通配置**：例如服务地址、开关、业务参数、Nginx 配置文件
- **敏感配置**：例如数据库密码、Token、证书、私钥

Kubernetes 为这两类配置分别提供了两个核心对象：

- `ConfigMap`：用于保存**非敏感配置**
- `Secret`：用于保存**敏感信息**

这两个资源的核心价值都是：**把配置从镜像里解耦出来**。这样当配置变化时，不需要重新构建镜像，只需要更新配置对象和对应工作负载即可。

## 1. 什么时候用 ConfigMap，什么时候用 Secret

### 用 ConfigMap 的场景

适合保存：

- 应用配置项
- 启动参数
- 连接地址
- Feature Flag
- Nginx / Redis / MySQL 的配置文件片段

例如：

- `APP_ENV=prod`
- `LOG_LEVEL=info`
- `REDIS_HOST=redis.default.svc.cluster.local`

### 用 Secret 的场景

适合保存：

- 用户名 / 密码
- API Token
- Access Key / Secret Key
- TLS 证书和私钥
- Docker 镜像仓库认证信息

例如：

- `DB_PASSWORD`
- `JWT_SECRET`
- `tls.crt` / `tls.key`

### 不要混用的原因

虽然从“Pod 使用方式”上看，`ConfigMap` 和 `Secret` 很像，但它们的语义不同：

- `ConfigMap` 表示“可公开的业务配置”
- `Secret` 表示“必须谨慎访问的敏感数据”

特别要注意：

- `Secret` **默认并不等于强加密**
- 如果 etcd 没启用加密，Secret 在底层存储中默认仍可能是明文可恢复的
- 所以生产环境还应结合：etcd encryption、RBAC、审计、外部密钥管理系统

## 2. ConfigMap：保存普通配置

`ConfigMap` 是一个用于保存**非机密数据**的 API 对象。

和大多数 Kubernetes 资源不同，`ConfigMap` 没有典型的 `spec` 结构，而是主要使用：

- `data`：保存 UTF-8 字符串
- `binaryData`：保存二进制内容（Base64）
- `immutable`：设置后不可变更

## 3. ConfigMap 完整资源清单（含注释）

下面这个例子包含两类内容：

- 简单键值对（如 `APP_ENV`）
- 一个完整配置文件（如 `application.yaml`）

```yaml
apiVersion: v1  # API 版本，ConfigMap 属于核心组 v1
kind: ConfigMap  # 资源类型：普通配置对象
metadata:
  name: app-config  # ConfigMap 名称
  namespace: default  # 命名空间
  labels:
    app.kubernetes.io/name: demo-app
immutable: false  # 是否不可变；设为 true 后只能删除重建，不能直接修改
data:
  APP_ENV: "prod"  # 普通键值配置
  LOG_LEVEL: "info"
  REDIS_HOST: "redis.default.svc.cluster.local"
  application.yaml: |  # 也可以把整段配置文件直接保存进去
    server:
      port: 8080
    spring:
      datasource:
        host: mysql.default.svc.cluster.local
        port: 3306
```

## 4. ConfigMap 关键字段解释

- `apiVersion: v1`：ConfigMap 属于 Kubernetes 核心 API 组。
- `kind: ConfigMap`：声明资源类型为 ConfigMap。
- `metadata.name`：ConfigMap 名称，Pod 引用时要用到。
- `metadata.namespace`：作用域所在命名空间，Pod 只能引用同命名空间下的 ConfigMap。
- `immutable`：设置为 `true` 后不能修改内容，只能删除后重建。
- `data`：保存普通文本配置，最常用。
- `binaryData`：保存二进制内容，值需要 Base64 编码。
- `data.<key>`：每个 key 都会被消费方映射为环境变量或文件名。
- `application.yaml: |`：多行文本写法，常用于整份配置文件挂载。

可以把 ConfigMap 理解为：

- `metadata` 决定“它是谁”
- `data/binaryData` 决定“它装了什么配置”
- `immutable` 决定“它能不能在线修改”

## 5. ConfigMap 使用实例

ConfigMap 最常见的两种使用方式：

- 作为环境变量注入
- 作为文件挂载到容器里

### 5.1 通过环境变量注入 ConfigMap

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: configmap-env-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: configmap-env-demo
  template:
    metadata:
      labels:
        app: configmap-env-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "env | grep -E 'APP_ENV|LOG_LEVEL|REDIS_HOST'; sleep 3600"]
          envFrom:
            - configMapRef:
                name: app-config  # 把 ConfigMap 中所有 key 批量注入为环境变量
```

验证：

```bash
kubectl apply -f app-config.yaml
kubectl apply -f configmap-env-demo.yaml
kubectl logs deploy/configmap-env-demo
```

### 5.2 通过文件挂载 ConfigMap

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: configmap-volume-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: configmap-volume-demo
  template:
    metadata:
      labels:
        app: configmap-volume-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "cat /etc/app/application.yaml; sleep 3600"]
          volumeMounts:
            - name: app-config-volume
              mountPath: /etc/app  # ConfigMap 会以文件形式挂到这个目录
              readOnly: true
      volumes:
        - name: app-config-volume
          configMap:
            name: app-config
            items:
              - key: application.yaml
                path: application.yaml  # 指定挂载后文件名
```

验证：

```bash
kubectl apply -f configmap-volume-demo.yaml
kubectl logs deploy/configmap-volume-demo
```

### 5.3 ConfigMap 更新行为说明

这里有一个非常容易踩坑的点：

- **作为 Volume 挂载的 ConfigMap**：更新后通常会被 kubelet 逐步同步到 Pod 内
- **作为环境变量注入的 ConfigMap**：更新后不会自动刷新，需要重建 Pod

所以：

- 想要配置热更新，优先考虑 volume 挂载
- 如果是 env 注入，通常要配合 rollout 重启

## 6. Secret：保存敏感信息

`Secret` 和 `ConfigMap` 的使用方式很像，但语义上用于保存敏感数据。

Kubernetes 常见 Secret 类型包括：

- `Opaque`：最常见，自定义键值敏感信息
- `kubernetes.io/tls`：TLS 证书
- `kubernetes.io/dockerconfigjson`：镜像仓库认证
- `kubernetes.io/basic-auth`：用户名密码
- `kubernetes.io/ssh-auth`：SSH 私钥

最常见的业务场景，通常使用 `Opaque` 即可。

## 7. Secret 完整资源清单（含注释）

写 Secret 时，最实用的方式通常是 `stringData`，因为它支持直接写明文字符串，Kubernetes 会自动转成 `data`。

```yaml
apiVersion: v1  # API 版本
kind: Secret  # 资源类型：敏感配置对象
metadata:
  name: app-secret  # Secret 名称
  namespace: default
  labels:
    app.kubernetes.io/name: demo-app
type: Opaque  # 最常见的 Secret 类型，自定义敏感键值对
stringData:  # 推荐写法：直接写明文，提交到 API 时会自动转成 data(base64)
  DB_USERNAME: "appuser"
  DB_PASSWORD: "S3cr3t-P@ssw0rd"
  JWT_SECRET: "replace-me-with-real-secret"
```

## 8. Secret 关键字段解释

- `apiVersion: v1`：Secret 属于 Kubernetes 核心 API 组。
- `kind: Secret`：声明资源类型为 Secret。
- `metadata.name`：Secret 名称，Pod 引用时使用。
- `type`：Secret 类型；业务场景里最常见的是 `Opaque`。
- `data`：保存 Base64 编码后的敏感内容。
- `stringData`：保存明文字符串，API Server 会自动转换为 `data`。
- `stringData.<key>`：每个 key 后续都可作为环境变量名或文件名被消费。

### `data` 和 `stringData` 的区别

- `data`：值必须是 Base64 编码
- `stringData`：值可以直接写明文，更适合 YAML 编写与维护

例如下面这种是 `data` 写法：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret-base64
type: Opaque
data:
  DB_PASSWORD: UzNjcjN0LVBAc3N3MHJk
```

但大多数手工维护场景，更推荐 `stringData`。

## 9. Secret 使用实例

### 9.1 通过环境变量注入 Secret

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-env-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secret-env-demo
  template:
    metadata:
      labels:
        app: secret-env-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "echo USER=$DB_USERNAME; echo PASS_LEN=${#DB_PASSWORD}; sleep 3600"]
          env:
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: app-secret
                  key: DB_USERNAME
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secret
                  key: DB_PASSWORD
```

验证：

```bash
kubectl apply -f app-secret.yaml
kubectl apply -f secret-env-demo.yaml
kubectl logs deploy/secret-env-demo
```

### 9.2 通过文件挂载 Secret

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-volume-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secret-volume-demo
  template:
    metadata:
      labels:
        app: secret-volume-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "ls -l /etc/secret && cat /etc/secret/DB_USERNAME && sleep 3600"]
          volumeMounts:
            - name: app-secret-volume
              mountPath: /etc/secret
              readOnly: true
      volumes:
        - name: app-secret-volume
          secret:
            secretName: app-secret
            items:
              - key: DB_USERNAME
                path: DB_USERNAME
              - key: DB_PASSWORD
                path: DB_PASSWORD
```

验证：

```bash
kubectl apply -f secret-volume-demo.yaml
kubectl exec -it deploy/secret-volume-demo -- ls -l /etc/secret
```

### 9.3 imagePullSecret 示例

如果你使用私有镜像仓库，常见做法是创建 `docker-registry` Secret：

```bash
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password='mypassword' \
  --docker-email=ops@example.com
```

然后在 Pod / Deployment 中引用：

```yaml
spec:
  imagePullSecrets:
    - name: regcred
```

这个 Secret 的用途不是给应用读，而是给 kubelet 拉私有镜像时认证用。

## 10. ConfigMap 与 Secret 的常见命令

### ConfigMap

```bash
kubectl get configmap
kubectl describe configmap app-config
kubectl get configmap app-config -o yaml
kubectl delete configmap app-config
```

### Secret

```bash
kubectl get secret
kubectl describe secret app-secret
kubectl get secret app-secret -o yaml
kubectl delete secret app-secret
```

### 从字面值快速创建

```bash
kubectl create configmap app-config-cli \
  --from-literal=APP_ENV=prod \
  --from-literal=LOG_LEVEL=info

kubectl create secret generic app-secret-cli \
  --from-literal=DB_USERNAME=appuser \
  --from-literal=DB_PASSWORD='S3cr3t-P@ssw0rd'
```

## 11. 常见问题与排错

### 11.1 Pod 启动失败：找不到 ConfigMap / Secret

排查：

```bash
kubectl get configmap
kubectl get secret
kubectl describe pod <pod-name>
```

常见原因：

- 名称写错
- 不在同一个 namespace
- key 名写错

### 11.2 更新 ConfigMap 后应用没生效

先确认你是怎么消费 ConfigMap 的：

- 如果是 **env 注入**：需要重建 Pod
- 如果是 **volume 挂载**：通常会逐步同步，但应用本身是否热加载还要看程序实现

### 11.3 Secret 明文暴露风险

要特别记住：

- `kubectl get secret -o yaml` 看到的是 Base64，不等于真正加密
- 有权限的人依然可以解码
- 生产环境要结合 etcd encryption、RBAC、审计与最小权限原则

### 11.4 挂载文件权限问题

Secret / ConfigMap 作为卷挂载后，如果应用读取失败，检查：

- `mountPath` 是否正确
- `subPath/items` 是否配置正确
- 容器用户权限是否允许读取

## 12. 生产实践建议

1. 普通配置统一放 `ConfigMap`，敏感数据统一放 `Secret`，不要混放。
2. 能按文件消费的配置，优先考虑 volume 挂载；更利于结构化配置管理。
3. `Secret` 不要直接提交到公共 Git 仓库，至少要结合 Sealed Secrets、External Secrets 或 Vault 一类方案。
4. 对高频变更配置，评估应用是否支持热加载；否则更新对象后仍需 rollout。
5. 大规模集群中，对长期稳定不变的配置可以考虑 `immutable: true`，减少误改和 watch 压力。
6. 对 Secret 的访问权限必须收敛，避免“能创建 Pod 就能间接读 Secret”的权限扩散问题。

## 参考资料

- ConfigMaps：
  - https://kubernetes.io/docs/concepts/configuration/configmap/
- Secrets：
  - https://kubernetes.io/docs/concepts/configuration/secret/
