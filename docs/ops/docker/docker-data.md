---
title: Docker 数据目录管理
sidebar_position: 5
---

Docker 默认为 `/var/lib/docker` 存放镜像、容器、卷等数据。随着容器数量与镜像增多，磁盘空间往往成为运维瓶颈。本章介绍数据目录结构、迁移策略、清理方法与备份建议。

## 1. 目录结构概览

```text
/var/lib/docker/
├── overlay2/        # 层文件系统，存储镜像和容器的读写层
├── containers/      # 容器元数据、日志（*.log）
├── volumes/         # docker volume 挂载数据
├── image/           # 镜像元信息
├── network/         # 自定义网络信息
└── swarm/           # 仅在开启 Swarm 时使用
```

### 查看占用

```bash
docker system df
sudo du -sh /var/lib/docker/*
```

## 2. 自定义 data-root

在生产环境建议将数据目录挂载到独立磁盘或 LVM，以免与系统盘争抢空间。修改 `/etc/docker/daemon.json`：

```json
{
  "data-root": "/data/docker"
}
```

操作步骤：

1. 停止 docker：`sudo systemctl stop docker`；
2. 将原目录迁移：

   ```bash
   sudo rsync -aHAX /var/lib/docker/ /data/docker/
   ```

3. 修改配置并重启 docker：

   ```bash
   sudo mkdir -p /data/docker
   sudo chown root:root /data/docker
   sudo systemctl daemon-reload && sudo systemctl start docker
   ```

4. 验证 `docker info | grep "Docker Root Dir"`。

> 若使用 Containerd，可在 `/etc/containerd/config.toml` 中修改 `root = "/data/containerd"`。

## 3. 卷与 Bind Mount

| 类型        | 说明                                            | 命令示例                                      | 适用场景                     |
| ----------- | ----------------------------------------------- | --------------------------------------------- | ---------------------------- |
| Volume      | 由 Docker 管理，路径 `/var/lib/docker/volumes` | `docker volume create pgdata`                 | 数据需跨容器持久化          |
| Bind Mount  | 绑定宿主机目录                                 | `docker run -v /data/log:/var/log/nginx -d`   | 宿主机已有文件/需要共享目录 |
| Tmpfs       | 内存文件系统，容器退出即销毁                   | `docker run --tmpfs /run Secrets`             | 存放敏感或临时数据           |

卷相关命令：

```bash
docker volume ls
docker volume inspect pgdata
docker volume rm pgdata
```

## 4. 日志与清理

容器日志默认存放于 `/var/lib/docker/containers/<id>/<id>-json.log`，随着时间推移容易占满磁盘。

- 在 `daemon.json` 中配置：

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  }
}
```

- 手动清理：

```bash
# 截断超大日志
find /var/lib/docker/containers/ -name "*-json.log" -size +500M -exec truncate -s 0 {} \;
```

- 监控磁盘占用：配合 `node_exporter` 的 `filesystem` 指标或 `Prometheus` `node_filesystem_avail_bytes` 告警。

## 5. 数据备份与恢复

### 镜像备份

```bash
# 保存/加载镜像
docker save nginx:1.25 -o nginx-1.25.tar
docker load -i nginx-1.25.tar
```

### 容器卷备份

```bash
# 备份 volume
docker run --rm -v pgdata:/data -v $(pwd):/backup busybox \
  tar -czf /backup/pgdata-$(date +%F).tar.gz -C /data .

# 恢复
tar -xzf pgdata-2024-05-01.tar.gz -C /var/lib/docker/volumes/pgdata/_data
```

### Bind Mount 目录

直接使用系统级工具（`rsync`, `tar`, `xfsdump`）。同时可利用 LVM snapshot 或云盘快照形成一致性备份。

## 6. 清理策略建议

1. 启用 CI/CD 镜像清理任务，删除超过 N 天未用的镜像；
2. 定期执行 `docker system prune`，或使用 `cron`：

   ```bash
   0 3 * * 0 docker system prune -f --volumes
   ```

3. 对 volume 建立命名规范，并在应用下线时同步删除；
4. 对数据目录设置磁盘报警阈值，例如 80%；
5. 在 Kubernetes 场景使用 `emptyDir`/`PersistentVolume` 管理数据，更换 runtime 时保持一致策略。

## 7. 常见问题排查

| 现象                         | 处理思路                                                                                  |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| `/var/lib/docker` 磁盘满     | `docker system df`, `du -sh /var/lib/docker/overlay2`；清理旧镜像/停止容器日志            |
| volume 无法删除             | 确认未被容器使用 `docker ps -a --filter volume=pgdata`，必要时 `docker volume rm -f`      |
| 数据目录迁移后 Docker 启动失败 | 检查新目录权限（必须为 root:root），或 `daemon.json` 拼写是否正确                       |
| 备份恢复后权限异常          | 使用 `tar --same-owner` 或 `chown -R` 修正权限；对数据库 volume 需保持软硬链接一致        |

合理规划数据目录、养成定期清理和备份的习惯，可以显著降低磁盘风险并提升容器运行时的稳定性。
