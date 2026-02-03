---
title: Docker 容器介绍
sidebar_position: 2
---

Docker 是 Ops 团队最常用的容器运行时之一。本篇从架构、镜像、运行生命周期、网络与存储、运维排障以及安全实践等角度，帮助你快速建立 Docker 工程化运维的知识框架。

## 1. 为什么需要 Docker

- **环境一致性**：镜像把应用、依赖、系统库封装在一起，一次构建可在任意节点运行。
- **弹性扩缩容**：容器可快速启动/销毁，易于配合 Kubernetes、Nomad 等编排器扩展。
- **资源隔离**：基于 Linux Namespace 与 Cgroup，提供进程、网络、磁盘等隔离能力。
- **交付流水线友好**：镜像构建+推送天然适配 CI/CD，支持多阶段构建、缓存命中。

## 2. 架构概览

```text
+-------------------+       +-------------------+
|   docker client   | <---> | docker daemon     |
+-------------------+       |  - dockerd        |
                            |  - containerd     |
                            |  - runc           |
                            +-------------------+
                                    |
                                    v
                            +-------------------+
                            |  registry (ACR/   |
                            |  Harbor/ECR etc.) |
                            +-------------------+
```

- `docker client`：CLI/SDK，负责发起 build、pull、run 等 API 请求。
- `dockerd`：守护进程，暴露 REST API，处理镜像管理、网络、存储。
- `containerd`：容器运行时，用于拉取镜像、管理 container lifecycle。
- `runc`：OCI 标准实现，真正负责创建 Linux Namespace/Cgroup。
- `registry`：镜像仓库，支持企业部署 Harbor、使用阿里云/腾讯云、GitHub Container Registry 等。

## 3. 镜像与多阶段构建

```dockerfile
# syntax=docker/dockerfile:1.7
FROM golang:1.22 AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o app ./cmd/server

FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=builder /src/app ./app
USER nonroot
ENTRYPOINT ["/app/app"]
```

**镜像优化建议**：

1. 添加 `.dockerignore` 减少上下文大小；
2. 使用多阶段构建保留最小运行时；
3. 设置 `USER`，避免容器以 root 运行；
4. 通过 `LABEL` 标注版本、责任人、Git 提交信息，方便追溯；
5. 缓存层过多时可以拆分模块，结合 BuildKit `--mount=type=cache` 提升速度。

## 4. 容器生命周期管理

```bash
# 创建并启动
kubectl run tmp --image=nginx:1.25

# docker run 关键参数
# -d 后台运行
# --restart=always 配合 systemd 保证自愈
# -m / --cpus 控制资源
# --log-driver json-file/syslog/fluentd

docker run -d --name web \
  --cpus=1.5 --memory=768m \
  --restart=on-failure:3 \
  -p 8080:80 nginx:1.25

# 日志、进入容器、文件拷贝

docker logs -f web
docker exec -it web /bin/sh
docker cp web:/var/log/nginx/access.log ./

# 清理异常资源
docker rm -f $(docker ps -aq)
docker system prune --volumes
```

**建议**：

- 在生产环境禁用 `latest` 标签，改用语义化版本；
- 日志默认保存在主机 `/var/lib/docker/containers/...`，应交给 Fluent Bit/Logstash 收集；
- 设置 `--log-opt max-size`, `max-file` 避免日志满盘。

## 5. 网络模式与调试

| 模式        | 描述                           | 使用场景                                                     |
| ----------- | ------------------------------ | ------------------------------------------------------------ |
| bridge      | 默认模式，容器通过 NAT 出网    | 单机部署、docker-compose、CI 等                             |
| host        | 与宿主机共享网络命名空间       | 需要避免 NAT、提高性能（需注意端口冲突）                     |
| none        | 无网络，需要自定义 namespace   | 特殊安全场景                                                 |
| overlay/macvlan | 多主机网络/二层网络         | 搭配 Swarm、手写网络策略、与物理网络集成                     |

调试技巧：

```bash
# 查看容器网络
ip link
brctl show docker0

# 宿主机进入容器 namespace
nsenter --target $(docker inspect -f '{{.State.Pid}}' web) --net bash
```

## 6. 存储与数据持久化

- **Bind Mount**：`-v /data/nginx:/var/log/nginx`，适合共享宿主机目录。
- **Named Volume**：`docker volume create pgdata`，由 Docker 管理，存储于 `/var/lib/docker/volumes`。
- **Tmpfs**：`--tmpfs /run`，存放临时敏感数据，容器销毁即清理。

备份/迁移：

```bash
# 导出 volume
sudo tar -czf pgdata.tar.gz -C /var/lib/docker/volumes/pgdata/_data .

# 镜像备份/迁移
docker save -o nginx.tar nginx:1.25
docker load -i nginx.tar
```

## 7. 安全与合规

- 最小权限：`USER nonroot`，结合 `--cap-drop ALL`、`--security-opt no-new-privileges:true`；
- 根文件系统只读：`--read-only`，配合 `tmpfs` 写入临时目录；
- 镜像扫描：Trivy、Grype、Clair，CI 阶段执行 `trivy image <image>`；
- 运行时防护：开启 AppArmor/SELinux policy，或部署 Falco；
- 机密管理：不要把凭证写进镜像，使用环境变量+外部 secret（KMS、Vault）。

## 8. 监控与排障

- **指标**：
  - `container_cpu_usage_seconds_total`
  - `container_memory_working_set_bytes`
  - `container_fs_usage_bytes`
- **日志**：Docker 默认 json-file，可结合 `dockerd --log-driver=fluentd` 直接推送；
- **常见问题**：

| 现象                         | 排查命令/策略                                                                                 |
| ---------------------------- | ---------------------------------------------------------------------------------------------- |
| 容器无法启动                | 查看 `docker logs`、`docker inspect` 的 `State` 与 `OOMKilled`；检查镜像 ENTRYPOINT | 
| 磁盘占用高                   | `docker system df`, `du -sh /var/lib/docker`; 定期清理 dangling images | 
| 网桥异常/冲突                | `docker network ls`, `iptables -t nat -L`; 与宿主机 firewall 规则冲突时需要保留 docker chain | 
| DNS 失效                     | 设置 `/etc/docker/daemon.json` 中 `"dns": ["223.5.5.5", "1.1.1.1"]` 并重启 dockerd | 

## 9. 与 Kubernetes 的关系

- 生产环境通常使用 Containerd 作为 kubelet runtime，但 Docker 镜像仍然可用（符合 OCI 标准）。
- 开发/调试：可先用 `docker compose` 验证组件，再迁移到 Helm/Operator。
- 模板化：把 Dockerfile、compose、K8s manifests 存入同一个 repo，与 GitOps 工具 (ArgoCD/Flux) 联动。

## 10. 推荐工具

| 场景         | 工具                                   | 备注                                            |
| ------------ | -------------------------------------- | ----------------------------------------------- |
| 镜像构建     | BuildKit, Kaniko, Buildx               | 支持缓存、跨架构、CI 无 Docker 特权构建        |
| 镜像仓库     | Harbor, GitHub Container Registry      | 企业级访问控制、漏洞扫描                        |
| 安全扫描     | Aqua Trivy, Anchore Grype, Clair       | 集成 CI 阶段，阻断有高危漏洞的镜像              |
| 调试/排障    | Dive, ctop, nerdctl, lazydocker         | 快速查看镜像层、实时资源占用                   |
| 日志/监控    | Docker Logging Driver, Prometheus cAdvisor | 与 Loki/Grafana 联动可视化                      |

## 11. 小结

Docker 作为基础设施栈的一环，既要关注镜像构建质量，也要关注运行态安全、资源与日志治理。理解其架构、生命周期、网络/存储模型与常用排障手段，可以帮助运维工程师更快定位问题，并与上层编排系统（Kubernetes、Argo、GitOps）更好联动。
