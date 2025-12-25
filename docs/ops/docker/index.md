---
sidebar_position: 1
---

# Docker 专题

面向运维场景的 Docker 知识整理：镜像构建、仓库管理、运行时排障与安全基线。

## 镜像构建

- 优先使用多阶段构建（multi-stage）减小镜像体积
- 使用 BuildKit / Buildx 开启缓存与并行
- 固定依赖版本，避免「今天能构建、明天不行」

## 仓库与分发

- 私有仓库（Harbor / Registry）权限与审计
- 镜像同步与加速：按业务优先级做白名单镜像列表
- Tag 策略：`<app>:<semver>-<gitsha>`（可追溯可回滚）

## 运行时排障

```bash
# 容器资源与进程
docker stats
docker top <container>
```

```bash
# 快速定位网络/DNS
docker exec -it <container> sh -lc 'cat /etc/resolv.conf; nslookup kubernetes.default.svc'
```

## 安全与基线

- 最小权限：非 root、只读文件系统、drop capabilities
- 镜像扫描：Trivy/Grype + CI 阶段阻断高危
- 运行时加固：seccomp/apparmor（或迁移到 K8s PSP/PodSecurity）

