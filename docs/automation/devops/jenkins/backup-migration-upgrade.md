---
title: Jenkins 备份迁移与升级
sidebar_position: 13
---

# Jenkins 备份迁移与升级


## 13.1 备份目标

Jenkins 的核心数据主要在 Jenkins Home 中。只备份 Job 配置而不备份 `secrets/`，可能导致凭据无法解密。

常见 Jenkins Home：

| 安装方式 | Jenkins Home |
| --- | --- |
| Linux 软件包 | `/var/lib/jenkins` |
| Docker 官方镜像 | `/var/jenkins_home` |
| 自定义部署 | 以实际 `JENKINS_HOME` 为准 |

查看 Jenkins Home：

```text
Manage Jenkins -> System Information -> JENKINS_HOME
```

或：

```bash
ps aux | grep jenkins
```

## 13.2 需要备份的内容

重点内容：

| 路径 | 说明 |
| --- | --- |
| `config.xml` | Jenkins 全局配置 |
| `jobs/` | Job 配置和构建记录 |
| `users/` | 用户配置 |
| `plugins/` | 插件文件 |
| `secrets/` | Jenkins 密钥，必须备份 |
| `credentials.xml` | 凭据索引 |
| `nodes/` | 节点配置 |
| `updates/` | 插件更新元数据 |
| `userContent/` | 用户静态内容 |
| `fingerprints/` | 构建制品指纹 |

可按需排除：

| 路径 | 说明 |
| --- | --- |
| `workspace/` | 工作区，通常可重建 |
| `caches/` | 缓存 |
| `logs/` | 日志，可另行采集 |
| `tmp/` | 临时目录 |

建议：

- 全量冷备份用于灾难恢复。
- 高频备份可以排除 workspace 和 cache。
- 凭据恢复必须包含 `secrets/` 和相关配置文件。

## 13.3 Linux 软件包备份

### 13.3.1 冷备份

冷备份最稳妥，先停止 Jenkins 再打包。

```bash
systemctl stop jenkins

tar czf /backup/jenkins_home_$(date +%F_%H%M%S).tar.gz \
  --exclude='/var/lib/jenkins/workspace' \
  --exclude='/var/lib/jenkins/caches' \
  --exclude='/var/lib/jenkins/tmp' \
  /var/lib/jenkins

systemctl start jenkins
```

### 13.3.2 热备份

热备份不停止 Jenkins，但可能遇到构建中数据变化。

```bash
tar czf /backup/jenkins_home_$(date +%F_%H%M%S).tar.gz \
  --exclude='/var/lib/jenkins/workspace' \
  --exclude='/var/lib/jenkins/caches' \
  --exclude='/var/lib/jenkins/tmp' \
  /var/lib/jenkins
```

建议：

- 热备份前暂停构建队列。
- 关键升级前使用冷备份。
- 定期做恢复演练，不只检查备份文件存在。

## 13.4 Docker 部署备份

如果使用宿主机目录挂载：

```bash
docker stop jenkins

tar czf /backup/jenkins_home_$(date +%F_%H%M%S).tar.gz \
  --exclude='/data/jenkins_home/workspace' \
  --exclude='/data/jenkins_home/caches' \
  --exclude='/data/jenkins_home/tmp' \
  /data/jenkins_home

docker start jenkins
```

如果使用 Docker Volume：

```bash
docker run --rm \
  -v jenkins_home:/var/jenkins_home \
  -v /backup:/backup \
  busybox \
  tar czf /backup/jenkins_home_$(date +%F_%H%M%S).tar.gz /var/jenkins_home
```

## 13.5 自动备份脚本

示例：

```bash title="/usr/local/bin/backup-jenkins.sh"
#!/usr/bin/env bash
set -euo pipefail

JENKINS_HOME="/var/lib/jenkins"
BACKUP_DIR="/backup/jenkins"
KEEP_DAYS=14
NOW="$(date +%F_%H%M%S)"

mkdir -p "${BACKUP_DIR}"

systemctl stop jenkins

tar czf "${BACKUP_DIR}/jenkins_home_${NOW}.tar.gz" \
  --exclude="${JENKINS_HOME}/workspace" \
  --exclude="${JENKINS_HOME}/caches" \
  --exclude="${JENKINS_HOME}/tmp" \
  "${JENKINS_HOME}"

systemctl start jenkins

find "${BACKUP_DIR}" -name 'jenkins_home_*.tar.gz' -mtime +"${KEEP_DAYS}" -delete
```

授权：

```bash
chmod +x /usr/local/bin/backup-jenkins.sh
```

crontab：

```bash
0 2 * * * /usr/local/bin/backup-jenkins.sh >> /var/log/backup-jenkins.log 2>&1
```

## 13.6 恢复流程

### 13.6.1 Linux 软件包恢复

```bash
systemctl stop jenkins

mv /var/lib/jenkins /var/lib/jenkins.bak.$(date +%F_%H%M%S)
mkdir -p /var/lib/jenkins

tar xzf /backup/jenkins_home_2026-05-06_020000.tar.gz -C /

chown -R jenkins:jenkins /var/lib/jenkins

systemctl start jenkins
```

检查：

```bash
systemctl status jenkins
journalctl -u jenkins -n 200 --no-pager
```

### 13.6.2 Docker 恢复

```bash
docker stop jenkins

mv /data/jenkins_home /data/jenkins_home.bak.$(date +%F_%H%M%S)
mkdir -p /data/jenkins_home

tar xzf /backup/jenkins_home_2026-05-06_020000.tar.gz -C /
chown -R 1000:1000 /data/jenkins_home

docker start jenkins
```

如果备份包里是 `/var/jenkins_home`，需要按实际路径解压或迁移内容。

## 13.7 迁移流程

迁移常见场景：

- 从旧服务器迁移到新服务器。
- 从软件包部署迁移到 Docker。
- 从 Docker 迁移到 Kubernetes 或新存储。
- 更换域名、证书、反向代理。

迁移步骤：

1. 记录旧环境 Jenkins 版本、Java 版本、插件列表。
2. 停止旧 Jenkins 或暂停构建。
3. 备份 Jenkins Home。
4. 在新环境安装相同或兼容 Jenkins 版本。
5. 恢复 Jenkins Home。
6. 修正文件权限。
7. 启动 Jenkins。
8. 检查插件、凭据、节点、Job、构建历史。
9. 更新 Jenkins URL 和 Webhook 地址。
10. 验证典型流水线。

导出插件列表：

```bash
curl -s http://localhost:8080/pluginManager/api/json?depth=1 \
  | jq -r '.plugins[] | "\(.shortName):\(.version)"' \
  > plugins.txt
```

如果无法使用 API，也可以查看：

```bash
ls /var/lib/jenkins/plugins/*.jpi
ls /var/lib/jenkins/plugins/*.hpi
```

## 13.8 升级前检查

升级前必须确认：

- 已完成 Jenkins Home 备份。
- 备份可以解压，且包含 `secrets/`。
- 当前 Java 版本满足目标 Jenkins 要求。
- 插件兼容目标 Jenkins 版本。
- 有回滚方案。
- 已在测试环境验证关键 Job。

查看版本：

```bash
java -version
curl -s http://127.0.0.1:8080/login | grep -i jenkins
```

查看 Jenkins 日志：

```bash
journalctl -u jenkins -n 200 --no-pager
```

## 13.9 软件包升级

Ubuntu / Debian：

```bash
apt update
apt install --only-upgrade jenkins
systemctl restart jenkins
```

RHEL / Rocky / AlmaLinux：

```bash
dnf update jenkins
systemctl restart jenkins
```

升级后检查：

```bash
systemctl status jenkins
journalctl -u jenkins -n 200 --no-pager
```

浏览器检查：

```text
Manage Jenkins -> System Information
Manage Jenkins -> Plugins
```

## 13.10 Docker 升级

```bash
docker pull jenkins/jenkins:lts-jdk21

docker stop jenkins
docker rm jenkins

docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /data/jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts-jdk21
```

建议：

- 不使用裸 `lts` 浮动标签做生产升级依据。
- 先记录旧镜像版本。
- 新镜像启动失败时，可以用旧镜像快速回退。

查看旧镜像：

```bash
docker inspect jenkins --format '{{.Config.Image}}'
```

## 13.11 插件升级

插件升级风险通常高于 Jenkins 本体小版本升级。

建议：

- 不要在生产环境一次性无验证升级全部插件。
- 先升级安全相关插件。
- 关键插件升级前查看 release notes。
- 升级后验证核心 Job。
- 插件升级和 Jenkins 主版本升级不要同时大跨度进行。

插件目录备份：

```bash
tar czf /backup/jenkins_plugins_$(date +%F).tar.gz /var/lib/jenkins/plugins
```

常见关键插件：

- Pipeline。
- Git。
- Credentials。
- GitLab。
- Kubernetes。
- Role Strategy。
- Matrix Auth。

## 13.12 回滚方案

软件包回滚：

1. 停止 Jenkins。
2. 安装旧版本 Jenkins。
3. 恢复升级前 Jenkins Home。
4. 启动 Jenkins。

Docker 回滚：

```bash
docker stop jenkins
docker rm jenkins

docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /data/jenkins_home:/var/jenkins_home \
  jenkins/jenkins:<old-version>
```

注意：

- 如果升级后 Jenkins Home 已被新版本修改，回滚时应恢复升级前备份。
- 只回滚程序不回滚数据，可能仍然无法启动。

## 13.13 常见问题

### 13.13.1 恢复后凭据无法解密

原因：

- 没有恢复 `secrets/`。
- `credentials.xml` 和 `secrets/` 不匹配。
- 从其他 Jenkins 复制了部分配置但没有复制密钥。

处理：

- 使用同一份完整 Jenkins Home 备份恢复。
- 不要只复制 `jobs/` 和 `credentials.xml`。

### 13.13.2 恢复后 Job 不见了

排查：

- `jobs/` 是否恢复到正确路径。
- 文件权限是否正确。
- Jenkins 启动日志是否有 XML 解析错误。
- 是否恢复到了错误的 `JENKINS_HOME`。

### 13.13.3 升级后插件报错

处理：

- 查看 `Manage Jenkins -> Plugins`。
- 查看 Jenkins 日志。
- 回退插件版本或升级依赖插件。
- 必要时恢复升级前备份。

### 13.13.4 Webhook 失效

迁移或更换域名后需要检查：

- Jenkins URL。
- GitLab Webhook URL。
- 反向代理配置。
- HTTPS 证书。
- Jenkins crumb / token 配置。

## 13.14 参考资料

- [Jenkins Backup and Restore](https://www.jenkins.io/doc/book/system-administration/backing-up/)
- [Jenkins Upgrade Guide](https://www.jenkins.io/doc/book/platform-information/upgrade-guide/)
- [Jenkins Docker](https://www.jenkins.io/doc/book/installing/docker/)
- [Jenkins Managing Plugins](https://www.jenkins.io/doc/book/managing/plugins/)
