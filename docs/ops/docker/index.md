---
title: Docker 专题
sidebar_position: 1
slug: /docker
---

面向运维场景的 Docker 知识整理：镜像构建、仓库分发、Compose 编排、运行时资源治理、网络与存储排障。

## 推荐阅读路径

1. 先通读：[`docker-intro`](/ops/docker/docker-intro)
2. 常用命令与运维动作：[`docker-image`](/ops/docker/docker-image)
3. 镜像构建与可追溯：[`docker-build-image`](/ops/docker/docker-build-image)
4. 多容器编排：[`docker-compose`](/ops/docker/docker-compose)
5. 资源限制与 OOM 排查：[`docker-resource`](/ops/docker/docker-resource)
6. 监控与告警落地：[`docker-monitor`](/ops/docker/docker-monitor)

## 运维速查

```bash
# 资源与日志
docker stats
docker logs -f <container>

# 磁盘
docker system df
docker system prune -a

# 网络
docker network ls
docker network inspect <net>
```
