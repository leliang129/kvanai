---
title: Docker Harbor私有仓库
sidebar_position: 8
---

Harbor 是企业常用的 OCI 镜像仓库（Registry）方案，在原生 `registry:2` 的基础上提供 **项目/权限、审计、漏洞扫描、镜像复制（Replication）、保留策略（Retention）、Robot 账号、OIDC/LDAP** 等能力，适合在内网搭建统一的镜像分发中心。

> 本文以运维落地为主：部署方式、TLS、权限模型、CI/CD 推送、清理与 GC、备份与升级、常见故障排查。

## 1. 核心概念

- **Project（项目）**：镜像的逻辑隔离空间（如 `ops/`、`platform/`、`biz-a/`），可设为 Public/Private。
- **Repository（仓库）**：项目下的镜像仓库（如 `ops/app`）。
- **Artifact（制品）**：镜像、Helm Chart、SBOM、签名等（取决于启用的功能）。
- **Robot Account**：机器人账号（适合 CI），支持按项目授权、可生成 token。
- **Retention（保留策略）**：保留指定数量/规则的标签，配合 GC 控制存储。
- **GC（Garbage Collection）**：清理“未被引用的 layer”（保留策略只是删除 tag/manifest，空间回收需要 GC）。

## 2. Harbor 架构简图（理解排障方向）

```text
------------------------+
|  Nginx / Harbor Portal|
|  (HTTPS 443)          |
+----------+------------+
           |
           v
 +--------------------+       +------------------+
 | core / registry    | <---> | jobservice       |
 | token/auth, api    |       | async jobs       |
 +--------------------+       +------------------+
           |
           v
 +--------------------+       +------------------+
 | database (Postgres)|       | redis            |
 +--------------------+       +------------------+
           |
           v
 +--------------------+
 | storage (fs/s3/...)|
 +--------------------+
```

运维常用入口：

- UI：`https://harbor.example.com/`
- Docker Registry API：`https://harbor.example.com/v2/`

## 3. 部署方式选择（建议）

### 3.1 单机/中小规模：offline installer + docker compose

优点：部署简单、维护成本低；缺点：单点。

### 3.2 生产/HA：外置 Postgres/Redis + 对象存储（S3/OSS）+ 多副本

优点：可用性与扩展性更好；缺点：组件更多，需要规范化运维（备份、升级、监控）。

## 4. 安装（推荐：官方 offline installer）

> 以下步骤示例以 Linux 主机为例；真实环境请按公司域名、证书、存储与账号策略调整。

### 4.0 下载地址（示例版本 v2.14.1）

离线安装包（offline installer）下载地址：

[harbor-offline-installer-v2.14.1.tgz](https://github.com/goharbor/harbor/releases/download/v2.14.1/harbor-offline-installer-v2.14.1.tgz)

示例命令：

```bash
wget -c https://github.com/goharbor/harbor/releases/download/v2.14.1/harbor-offline-installer-v2.14.1.tgz
tar -xzf harbor-offline-installer-v2.14.1.tgz
cd harbor
```

### 4.1 准备

- CPU/内存：最少 2C4G（建议更高）
- 磁盘：根据镜像量规划（建议独立挂载点）
- 端口：443（或 80/443）
- DNS：`harbor.example.com` 指向 Harbor 主机/负载均衡

### 4.2 配置 `harbor.yml`

常见关键项（示意）：

```yaml
hostname: harbor.example.com
http:
  port: 80
https:
  port: 443
  certificate: /data/cert/harbor.crt
  private_key: /data/cert/harbor.key

harbor_admin_password: "ChangeMe!"
database:
  password: "ChangeMeDB!"

data_volume: /data/harbor
```

初始化并启动：

```bash
./install.sh
# 或：./install.sh --with-trivy（启用漏洞扫描组件）
```

启动后验证：

```bash
curl -kI https://harbor.example.com/
curl -k https://harbor.example.com/v2/  # 返回 401/UNAUTHORIZED 代表 registry alive
```

## 5. TLS 与客户端信任（非常关键）

Harbor 建议一律用 HTTPS（公司 CA 或 Let’s Encrypt/自签均可）。常见踩坑：客户端不信任证书导致 `docker login` 报错。

### 5.1 Docker 客户端信任自签/企业证书

把 CA 或服务端证书放到 Docker 的 cert 目录（按域名:端口）：

```bash
sudo mkdir -p /etc/docker/certs.d/harbor.example.com
sudo cp ca.crt /etc/docker/certs.d/harbor.example.com/ca.crt
sudo systemctl restart docker
```

> 若 Harbor 使用了非 443 端口，例如 `harbor.example.com:8443`，目录要对应：`/etc/docker/certs.d/harbor.example.com:8443/ca.crt`。

### 5.2 不推荐：insecure registry

仅在测试环境临时使用：

```json
{
  "insecure-registries": ["harbor.example.com"]
}
```

## 6. 权限模型与最佳实践（项目/账号/Robot）

### 6.1 项目划分建议

- `platform/`：基础镜像、统一工具镜像（如 `alpine` 定制、`runner` 等）
- `ops/`：运维工具、内部脚本镜像
- `biz-*/`：业务项目隔离

### 6.2 CI/CD 推送：用 Robot Account，不要用个人账号

在项目中创建 Robot（只给 push/pull 权限），CI 中使用：

```bash
docker login harbor.example.com -u 'robot$ci' -p "$HARBOR_ROBOT_TOKEN"
docker build -t harbor.example.com/ops/app:1.2.3-$(git rev-parse --short HEAD) .
docker push harbor.example.com/ops/app:1.2.3-$(git rev-parse --short HEAD)
```

> 标签策略与构建建议可参考：[`docker-build-image`](./docker-build-image)

## 7. 推送/拉取工作流（开发与生产）

### 7.1 基础命令

```bash
docker login harbor.example.com
docker tag app:local harbor.example.com/ops/app:1.0.0
docker push harbor.example.com/ops/app:1.0.0

docker pull harbor.example.com/ops/app:1.0.0
```

### 7.2 Kubernetes 使用 Harbor

创建 `imagePullSecret`：

```bash
kubectl create secret docker-registry harbor-pull \
  --docker-server=harbor.example.com \
  --docker-username='robot$ci' \
  --docker-password="$HARBOR_ROBOT_TOKEN" \
  --docker-email=devnull@example.com \
  -n <ns>
```

在 Deployment 中引用：

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        - name: harbor-pull
      containers:
        - name: app
          image: harbor.example.com/ops/app:1.0.0
```

## 8. 镜像复制（Replication）与镜像同步

常见场景：

- 多机房 Harbor 之间同步（容灾/就近拉取）
- 从公网仓库（Docker Hub/GHCR）同步到内网（合规/加速）

要点：

- 复制是异步任务，由 jobservice 执行；失败先看 UI 任务详情，再看 jobservice 日志。
- 对公网同步建议设置白名单（按项目/仓库），避免“全量镜像”把存储打爆。

## 9. Retention 与 GC：空间治理的两步

### 9.1 Retention（保留策略）

建议策略（示例）：

- release：保留 `semver` 最新 50 个
- canary：保留最近 30 天
- 分支构建：只保留最近 N 个或 N 天

### 9.2 GC（垃圾回收）

重要事实：**删除 tag 不一定释放空间**，只有 GC 才会清理不再被引用的 layer。

运维建议：

- 低峰执行 GC（I/O 压力较大）
- 先跑 Retention，再跑 GC
- 生产上 GC 建议纳入变更流程并做监控

## 10. 漏洞扫描（Trivy）与准入建议

Harbor 可集成 Trivy 扫描镜像。

落地建议：

- CI 中也扫描一次（更早失败，减少推送无效制品）
- 生产准入：阻断 `CRITICAL/HIGH`（按公司策略）
- 对“基础镜像”定期重建/重新扫描，避免长期堆积漏洞

## 11. 备份与恢复（务必演练）

Harbor 的核心数据包括：

- **数据库（Postgres）**：项目/用户/权限、制品元信息、扫描结果等
- **存储（filesystem 或 S3）**：镜像 layer 与 manifests
- **配置与证书**：`harbor.yml`、TLS 证书等

最低可用的备份策略：

1. 定期备份 Postgres（逻辑备份或快照）
2. 定期备份存储目录（或对象存储版本化）
3. 备份 `harbor.yml` 与证书
4. 恢复演练：至少在测试环境演练一次“从 0 恢复”

## 12. 升级策略（避坑清单）

- 先看官方 release notes（是否涉及 DB 迁移/组件变更）
- 先在测试环境升级验证（push/pull、扫描、复制、GC）
- 升级前备份（DB + storage）
- 升级窗口内冻结推送（或通知业务）

## 13. 常见问题排查

### 13.1 `docker login` 失败

排查顺序：

1. DNS/网络：`curl -k https://harbor.example.com/v2/`
2. 证书信任：是否安装了 CA 到 `/etc/docker/certs.d/.../ca.crt`
3. 账号权限：Robot 是否有目标项目 push 权限

典型报错：

- `x509: certificate signed by unknown authority`：证书不信任
- `unauthorized: authentication required`：账号/权限问题或项目私有

### 13.2 push/pull 卡住或慢

- 看磁盘/IO：Harbor 存储目录是否满、是否有高延迟盘
- 看 Nginx/registry 日志
- 是否启用了代理/负载均衡导致上传超时（调大超时配置）

### 13.3 删除镜像后空间不降

- 先确认 Retention 是否只是删 tag
- 执行 GC 后才会释放 layer 空间

## 14. 运维清单（建议落地到 SOP）

- [ ] 新项目：命名规范、权限与 Robot 创建
- [ ] Tag 策略：禁止生产用 `latest`
- [ ] Retention + GC：低峰定时、执行记录、监控告警
- [ ] 扫描：CI 扫描 + Harbor 扫描，制定阻断策略
- [ ] 备份：DB + storage + 配置，定期恢复演练
