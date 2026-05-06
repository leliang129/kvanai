---
title: Jenkins 安装与初始化
sidebar_position: 1
---

# Jenkins 安装与初始化


## 1.1 Jenkins 介绍

Jenkins 是一个开源自动化服务器，常用于持续集成、持续交付和自动化运维任务。它通过插件机制集成 Git、Maven、Gradle、Docker、Kubernetes、SonarQube、通知系统等工具，可以把代码拉取、编译、测试、扫描、制品构建、镜像推送、部署发布等步骤串成流水线。

Jenkins 常见使用场景：

- 代码提交后自动触发构建与测试。
- 构建 Java、Node.js、Go、Python 等项目制品。
- 构建并推送 Docker 镜像。
- 通过 Pipeline 实现标准化发布流程。
- 作为定时任务平台执行巡检、备份、同步等运维脚本。
- 对接 GitLab、GitHub、钉钉、企业微信、LDAP、SonarQube 等系统。

## 1.2 安装方式选择

Jenkins 常见安装方式如下：

| 方式 | 适用场景 | 说明 |
| --- | --- | --- |
| Linux 软件包安装 | 生产或长期运行环境 | 由 systemd 托管，目录清晰，便于运维 |
| Docker 安装 | 测试、演示、容器化环境 | 部署快，迁移方便，注意持久化数据 |
| WAR 包启动 | 临时验证或特殊环境 | 依赖本机 Java，通常不作为生产首选 |
| Kubernetes 部署 | 云原生环境 | 建议结合 Helm、Operator 或已有平台规范 |

生产环境建议优先选择 Linux 软件包或容器化部署，并固定数据目录、备份策略和插件版本。

## 1.3 安装前准备

### 1.3.1 系统要求

建议配置：

- 测试环境：`CPU 2C+`、内存 `2G+`、磁盘 `20G+`。
- 小团队生产环境：`CPU 4C+`、内存 `4G+`、磁盘 `50G+`。
- 构建任务较重时，建议 Jenkins Controller 只负责调度，实际构建放到 Agent 节点执行。

软件要求：

- Jenkins Controller 需要 Java 运行环境。
- 2026 年后的新版本 Jenkins LTS 推荐使用 `Java 21`，部分版本也支持 `Java 25`。
- 浏览器访问默认端口为 `8080`。
- 如需通过入站 Agent 连接，默认还会使用 `50000` 端口。

### 1.3.2 基础准备

安装前建议完成以下准备：

```bash
# 设置主机名
hostnamectl set-hostname jenkins.example.com

# 时间同步
timedatectl set-timezone Asia/Shanghai

# 查看系统版本
cat /etc/os-release

# 检查端口占用
ss -lntp | grep -E ':8080|:50000'
```

如启用防火墙，需要放行端口：

```bash
# RHEL / Rocky / AlmaLinux / CentOS
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --add-port=50000/tcp
firewall-cmd --reload
```

## 1.4 Linux 软件包安装

### 1.4.1 Ubuntu / Debian 安装 Jenkins LTS

安装 Java：

```bash
apt update
apt install -y fontconfig openjdk-21-jre
java -version
```

配置 Jenkins LTS 软件源并安装：

```bash
install -m 0755 -d /etc/apt/keyrings
wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

apt update
apt install -y jenkins
```

启动并设置开机自启：

```bash
systemctl daemon-reload
systemctl enable --now jenkins
systemctl status jenkins
```

### 1.4.2 RHEL / Rocky / AlmaLinux / CentOS 安装 Jenkins LTS

配置 Jenkins LTS 软件源：

```bash
wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/rpm-stable/jenkins.repo

rpm --import https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key
```

安装依赖和 Jenkins：

```bash
dnf install -y fontconfig java-21-openjdk
dnf install -y jenkins
```

启动并设置开机自启：

```bash
systemctl daemon-reload
systemctl enable --now jenkins
systemctl status jenkins
```

说明：

- Jenkins 官方提供 `stable` 与 `weekly` 两类软件源，生产环境建议使用 LTS stable 源。
- 若系统默认仓库没有 `java-21-openjdk`，可以改用发行版支持的 OpenJDK 21 包或 Eclipse Temurin 21。
- 老版本系统如果没有 `dnf`，可将上面的 `dnf` 替换为 `yum`。

## 1.5 Docker 安装

### 1.5.1 快速启动

适合测试环境或本地验证：

```bash
docker volume create jenkins_home

docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts-jdk21
```

查看日志：

```bash
docker logs -f jenkins
```

查看初始管理员密码：

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 1.5.2 目录挂载方式

如果希望直接在宿主机管理 Jenkins 数据，可以使用宿主机目录挂载：

```bash
mkdir -p /data/jenkins_home
chown -R 1000:1000 /data/jenkins_home

docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /data/jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts-jdk21
```

注意：

- 容器内 Jenkins 用户通常是 `uid 1000`，宿主机目录权限需要匹配。
- `/var/jenkins_home` 必须持久化，否则容器删除后任务、插件、凭据和配置都会丢失。

### 1.5.3 Docker Compose 示例

```yaml
services:
  jenkins:
    image: jenkins/jenkins:lts-jdk21
    container_name: jenkins
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - /data/jenkins_home:/var/jenkins_home
    environment:
      - TZ=Asia/Shanghai
```

启动：

```bash
docker compose up -d
docker compose logs -f jenkins
```

## 1.6 初始化 Jenkins

### 1.6.1 获取初始密码

Linux 软件包安装：

```bash
cat /var/lib/jenkins/secrets/initialAdminPassword
```

Docker 安装：

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

浏览器访问：

```text
http://服务器IP:8080
```

初始化步骤：

1. 输入初始管理员密码解锁 Jenkins。
2. 选择安装推荐插件，或按需选择插件。
3. 创建第一个管理员用户。
4. 确认 Jenkins URL，例如 `http://jenkins.example.com:8080/`。

### 1.6.2 国内插件源配置

如果插件下载较慢，可以在 Jenkins 页面中配置插件更新站点：

```text
Manage Jenkins -> Plugins -> Advanced settings -> Update Site
```

常见镜像地址：

```text
https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json
https://mirrors.huaweicloud.com/jenkins/updates/update-center.json
```

也可以在服务器上查看或修改配置文件：

```bash
# Linux 软件包安装
grep -n "url" /var/lib/jenkins/hudson.model.UpdateCenter.xml

# Docker 安装
docker exec jenkins grep -n "url" /var/jenkins_home/hudson.model.UpdateCenter.xml
```

修改后重启 Jenkins：

```bash
systemctl restart jenkins
```

Docker 环境：

```bash
docker restart jenkins
```

## 1.7 常用目录

Linux 软件包安装常用目录：

| 路径 | 说明 |
| --- | --- |
| `/var/lib/jenkins` | Jenkins Home，保存任务、插件、凭据、配置和构建记录 |
| `/etc/sysconfig/jenkins` | RHEL 系旧版本参数文件，部分新版本不再使用 |
| `/etc/default/jenkins` | Debian 系旧版本参数文件，部分新版本不再使用 |
| `/lib/systemd/system/jenkins.service` | systemd 服务文件 |
| `/var/log/jenkins` | Jenkins 日志目录，具体取决于安装包版本 |
| `/var/cache/jenkins` | 缓存目录 |

Docker 安装常用目录：

| 路径 | 说明 |
| --- | --- |
| `/var/jenkins_home` | 容器内 Jenkins Home |
| `/data/jenkins_home` | 示例中的宿主机持久化目录 |

重要文件：

| 文件 | 说明 |
| --- | --- |
| `config.xml` | Jenkins 全局配置 |
| `credentials.xml` | 凭据索引文件，敏感数据依赖密钥文件解密 |
| `secrets/` | Jenkins 加密密钥目录，必须备份 |
| `jobs/` | Freestyle 和 Pipeline Job 配置与构建记录 |
| `plugins/` | 插件目录 |
| `users/` | 用户配置目录 |

## 1.8 常用配置

### 1.8.1 修改 Jenkins 端口

Jenkins 软件包安装后默认监听 `8080`。如需改端口，建议使用 systemd override：

```bash
systemctl edit jenkins
```

写入：

```ini
[Service]
Environment="JENKINS_PORT=8081"
```

应用配置：

```bash
systemctl daemon-reload
systemctl restart jenkins
systemctl status jenkins
```

### 1.8.2 配置 Java 路径

查看 Jenkins 当前使用的 Java：

```bash
systemctl status jenkins
journalctl -u jenkins -n 100 --no-pager
```

如需显式指定 Java，可使用 systemd override：

```bash
systemctl edit jenkins
```

示例：

```ini
[Service]
Environment="JAVA_HOME=/usr/lib/jvm/java-21-openjdk"
```

### 1.8.3 配置反向代理

生产环境通常使用 Nginx 暴露域名和 HTTPS，Jenkins 仍监听本机 `8080`。

Nginx 示例：

```nginx
server {
    listen 80;
    server_name jenkins.example.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_request_buffering off;
        proxy_buffering off;
    }
}
```

如果 Jenkins 页面提示反向代理配置异常，需要检查：

- Jenkins 系统配置中的 Jenkins URL 是否与访问域名一致。
- Nginx 是否传递 `Host`、`X-Forwarded-*` 请求头。
- HTTPS 场景下 `X-Forwarded-Proto` 是否为 `https`。

## 1.9 常用运维命令

### 1.9.1 systemd 命令

```bash
systemctl status jenkins
systemctl start jenkins
systemctl stop jenkins
systemctl restart jenkins
systemctl enable jenkins
systemctl disable jenkins
journalctl -u jenkins -f
journalctl -u jenkins -n 200 --no-pager
```

### 1.9.2 Docker 命令

```bash
docker ps
docker logs -f jenkins
docker restart jenkins
docker exec -it jenkins bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 1.9.3 插件管理

进入 Jenkins 插件管理页面：

```text
Manage Jenkins -> Plugins
```

常用基础插件：

- `Git`：Git 仓库集成。
- `Pipeline`：流水线能力。
- `Docker Pipeline`：流水线中调用 Docker。
- `GitLab`：对接 GitLab Webhook 和构建状态。
- `Credentials Binding`：在流水线中安全注入凭据。
- `SSH Agent`：通过 SSH 凭据执行部署。
- `Role-based Authorization Strategy`：基于角色的权限控制。
- `Folders`：按目录组织任务。

## 1.10 备份与升级建议

### 1.10.1 备份

Jenkins 的核心数据位于 Jenkins Home，备份时需要重点关注：

- `config.xml`
- `jobs/`
- `plugins/`
- `users/`
- `secrets/`
- `credentials.xml`
- `nodes/`

Linux 软件包安装备份示例：

```bash
systemctl stop jenkins
tar czf /backup/jenkins_home_$(date +%F).tar.gz /var/lib/jenkins
systemctl start jenkins
```

Docker 安装备份示例：

```bash
docker stop jenkins
tar czf /backup/jenkins_home_$(date +%F).tar.gz /data/jenkins_home
docker start jenkins
```

说明：

- `secrets/` 目录必须和配置文件一起备份，否则凭据可能无法解密。
- 生产环境建议使用定时备份，并定期做恢复演练。

### 1.10.2 升级

升级前建议：

1. 先完整备份 Jenkins Home。
2. 查看当前 Jenkins 版本、Java 版本和插件更新状态。
3. 阅读目标版本升级说明。
4. 优先在测试环境验证插件兼容性。
5. 避免 Jenkins 主版本和大量插件同时无验证升级。

查看版本：

```bash
java -version
curl -s http://127.0.0.1:8080/login | grep -i "jenkins"
```

软件包安装升级：

```bash
# Ubuntu / Debian
apt update
apt install --only-upgrade jenkins

# RHEL / Rocky / AlmaLinux / CentOS
yum update jenkins
```

Docker 安装升级：

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

## 1.11 常见问题

### 1.11.1 Jenkins 启动失败

查看服务状态和日志：

```bash
systemctl status jenkins
journalctl -u jenkins -n 200 --no-pager
```

常见原因：

- Java 版本不兼容或未安装。
- `8080` 端口被占用。
- Jenkins Home 目录权限错误。
- 插件升级后不兼容。
- 磁盘空间不足。

### 1.11.2 端口被占用

```bash
ss -lntp | grep :8080
```

解决方式：

- 停止占用端口的服务。
- 或按 `1.8.1` 修改 Jenkins 监听端口。

### 1.11.3 忘记管理员密码

如果仍有服务器权限，可以临时关闭安全配置后重置。操作前必须备份 Jenkins Home。

```bash
systemctl stop jenkins
cp /var/lib/jenkins/config.xml /var/lib/jenkins/config.xml.bak
```

编辑 `/var/lib/jenkins/config.xml`，将：

```xml
<useSecurity>true</useSecurity>
```

改为：

```xml
<useSecurity>false</useSecurity>
```

启动 Jenkins：

```bash
systemctl start jenkins
```

登录后立即重新开启安全配置并重置管理员密码。

### 1.11.4 插件下载失败

处理思路：

- 检查服务器是否可以访问 Jenkins Update Center。
- 配置国内插件源。
- 检查系统时间是否正确。
- 检查代理、证书和 DNS。
- 查看 `Manage Jenkins -> System Log`。

## 1.12 参考资料

- [Jenkins Linux 安装文档](https://www.jenkins.io/doc/book/installing/linux/)
- [Jenkins Docker 安装文档](https://www.jenkins.io/doc/book/installing/docker/)
- [Jenkins Java 支持策略](https://www.jenkins.io/doc/book/platform-information/support-policy-java/)
