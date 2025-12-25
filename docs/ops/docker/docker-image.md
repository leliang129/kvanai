---
title: Docker 容器与镜像管理
sidebar_position: 3
---

本章聚焦如何管理 Docker 镜像与容器生命周期，包含常见命令、镜像优化、仓库推送、清理策略以及日常排障提示。

## 1. 镜像基础命令

```bash
# 列出本地镜像
docker images
docker image ls --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# 拉取镜像
docker pull nginx:1.25

# 删除镜像
docker rmi nginx:1.25

# 镜像重命名/打标签
docker tag nginx:1.25 registry.example.com/edge/nginx:prod

# 查看镜像历史层
docker history nginx:1.25
```

### 镜像体积分析

```bash
docker image inspect nginx:1.25 --format '{{.Size}}'
# 或使用 dive 工具可视化镜像层
```

## 2. 镜像构建

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY . .
RUN npm run build

FROM nginx:1.25-alpine
COPY --from=build /app/dist /usr/share/nginx/html
```

```bash
docker build -t web:latest .
docker buildx build --platform linux/amd64,linux/arm64 \
  -t registry.example.com/web:2024-05-01 --push .
```

优化建议：

1. 使用多阶段构建 + distroless/alpine 减小镜像；
2. `.dockerignore` 排除不必要文件；
3. `RUN` 命令合并、清理缓存，例如 `apt-get clean && rm -rf /var/lib/apt/lists/*`；
4. 设置 `LABEL maintainer`, `LABEL commit` 便于追溯。

## 3. 容器常用操作

```bash
# 启动容器
docker run -d --name web -p 8080:80 nginx:1.25

# 查看运行容器
docker ps

# 查看所有容器（包含退出的）
docker ps -a

# 打印日志
docker logs -f web

# 进入容器交互式 shell
docker exec -it web /bin/sh

# 查看容器 inspect 信息
docker inspect web

# 停止/启动/删除容器
docker stop web
docker start web
docker rm web

# 复制文件
docker cp web:/var/log/nginx/access.log ./access-log
```

### 容器资源限制

```bash
docker run --name job --cpus=1.5 --memory=768m \
  --pids-limit=100 --restart=on-failure:3 myjob:2024-05
```

## 4. 推送到镜像仓库

```bash
# 登录企业 Harbor 或 ACR
docker login harbor.example.com

# 打标签并推送
docker tag web:latest harbor.example.com/edge/web:1.0.0
docker push harbor.example.com/edge/web:1.0.0
```

可通过 `~/.docker/config.json` 配置多个 registry，CI/CD 中用 `docker login` + 环境变量传入凭据。

## 5. 镜像/容器清理

```bash
# 清理停止容器和未被使用的网络/镜像
docker system prune

# 保留卷的情况下清理所有
docker system prune -a --volumes

# 仅清理 dangling 镜像
docker image prune

# 清理旧日志
find /var/lib/docker/containers/ -name "*.log" -size +500M -exec truncate -s 0 {} \;
```

结合 `docker system df` 观察磁盘占用，必要时迁移 `data-root` 到更大的磁盘并做定期巡检。

## 6. 常见排障技巧

| 现象                                 | 命令/策略                                                                               |
| ------------------------------------ | --------------------------------------------------------------------------------------- |
| 容器持续重启                         | `docker inspect --format '{{.State.ExitCode}}'` 检查退出码；`docker logs` 查看报错       |
| 镜像被误删                           | 使用 `docker pull` 从仓库重新拉取，必要时 `docker load` 导入备份                         |
| 网络异常（无法访问外网）             | `docker inspect bridge`, `iptables -t nat -L`; 检查主机防火墙策略                       |
| CPU/内存飙升                         | `docker stats`, `docker top <container>`；考虑配置 `--cpus --memory`                     |
| 镜像版本未知                         | `docker inspect -f '{{.RepoTags}} {{.Config.Labels}}'`                                   |

## 7. 与 Compose/GitOps 联动

- `docker compose up -d` 可快速启动多容器应用；
- 将镜像 tag 与 Git 提交、版本策略绑定（如 `app:v1.2.3-gitsha`），便于 GitOps 工具（ArgoCD/Flux）回滚；
- 在 CI 中使用 BuildKit + `docker buildx bake`，利用缓存和多平台推送提升效率。

## 8. 附：常用命令速记

```bash
# 保存/加载镜像
docker save web:1.0 -o web.tar
docker load -i web.tar

# 导出/导入容器数据
docker export web > web.tar
docker import web.tar web:new

# 查看资源占用
docker stats
docker system df

# 查看事件
docker events --since 1h
```

掌握以上命令与策略，可以在日常运维中高效管理镜像与容器，快速发现并处理问题。
