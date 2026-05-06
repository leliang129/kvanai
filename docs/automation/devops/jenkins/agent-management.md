---
title: Jenkins Agent 节点管理
sidebar_position: 12
---

# Jenkins Agent 节点管理


## 12.1 Agent 介绍

Jenkins 架构中通常把节点分为：

| 节点 | 说明 |
| --- | --- |
| Controller | Jenkins 主节点，负责 Web、调度、配置、插件、任务编排 |
| Agent | 构建节点，负责执行具体构建任务 |

生产环境建议：

- Controller 尽量不执行业务构建。
- 构建任务放到 Agent。
- 不同技术栈使用不同 Agent。
- 生产部署 Agent 和普通构建 Agent 分开。
- 使用标签控制任务调度。

## 12.2 Agent 类型

常见 Agent 类型：

| 类型 | 说明 | 适用场景 |
| --- | --- | --- |
| SSH Agent | Jenkins 通过 SSH 启动 Agent | 固定 Linux 构建机 |
| Inbound Agent | Agent 主动连接 Jenkins | NAT、内网隔离场景 |
| Docker Agent | 使用 Docker 容器作为构建环境 | 本机 Docker 构建 |
| Kubernetes Agent | 每次构建动态创建 Pod | 云原生、弹性构建 |
| Windows Agent | Windows 构建、打包 | .NET、桌面应用 |

## 12.3 SSH Agent 配置

### 12.3.1 Agent 主机准备

在 Agent 主机创建 Jenkins 用户：

```bash
useradd -m -s /bin/bash jenkins
passwd jenkins
```

安装 Java：

```bash
# Ubuntu / Debian
apt update
apt install -y openjdk-21-jre git

# RHEL / Rocky / AlmaLinux
dnf install -y java-21-openjdk git
```

创建工作目录：

```bash
mkdir -p /data/jenkins-agent
chown -R jenkins:jenkins /data/jenkins-agent
```

### 12.3.2 SSH Key 凭据

在 Jenkins Controller 上生成专用 SSH Key：

```bash
ssh-keygen -t ed25519 -f jenkins-agent-ed25519 -C "jenkins-agent"
```

把公钥加入 Agent：

```bash
mkdir -p /home/jenkins/.ssh
cat jenkins-agent-ed25519.pub >> /home/jenkins/.ssh/authorized_keys
chown -R jenkins:jenkins /home/jenkins/.ssh
chmod 700 /home/jenkins/.ssh
chmod 600 /home/jenkins/.ssh/authorized_keys
```

Jenkins 凭据：

```text
Type: SSH Username with private key
ID: jenkins-agent-ssh-key
Username: jenkins
Private Key: jenkins-agent-ed25519
```

### 12.3.3 Jenkins 添加节点

入口：

```text
Manage Jenkins -> Nodes -> New Node
```

配置项：

| 配置项 | 示例 |
| --- | --- |
| `Node name` | `builder-01` |
| `Type` | `Permanent Agent` |
| `Remote root directory` | `/data/jenkins-agent` |
| `Labels` | `linux docker maven` |
| `Usage` | `Only build jobs with label expressions matching this node` |
| `Launch method` | `Launch agents via SSH` |
| `Host` | `10.0.0.11` |
| `Credentials` | `jenkins-agent-ssh-key` |
| `Host Key Verification Strategy` | 建议使用 known_hosts |

## 12.4 标签设计

标签用于控制任务调度。

常见标签：

| 标签 | 说明 |
| --- | --- |
| `linux` | Linux Agent |
| `windows` | Windows Agent |
| `docker` | 可执行 Docker 构建 |
| `maven` | 已安装 Maven |
| `nodejs` | 已安装 Node.js |
| `kubectl` | 已安装 kubectl |
| `prod-deploy` | 生产发布节点 |

Jenkinsfile 示例：

```groovy
pipeline {
    agent {
        label 'linux && docker'
    }

    stages {
        stage('Build') {
            steps {
                sh 'docker version'
            }
        }
    }
}
```

建议：

- 标签表达真实能力，不要随意复用。
- 生产发布节点使用独立标签。
- 不要让普通构建 Job 调度到生产发布节点。

## 12.5 执行器数量

执行器数量决定同一节点可以并发执行多少构建。

建议：

| Agent 类型 | 建议执行器 |
| --- | --- |
| 普通构建机 | CPU 核数或略低 |
| Docker 构建机 | 根据磁盘 IO 和内存控制，通常 1-4 |
| 生产发布节点 | 通常 1 |
| Controller | 生产建议 0 |

Controller 设置执行器：

```text
Manage Jenkins -> Nodes -> Built-In Node -> Configure -> Number of executors
```

生产建议：

```text
Number of executors: 0
```

## 12.6 Agent 工具环境

Agent 常见工具：

- JDK。
- Maven / Gradle。
- Node.js / pnpm / yarn。
- Docker CLI。
- kubectl / helm。
- Git。
- Trivy / Sonar Scanner。

检查脚本：

```bash
java -version
git --version
mvn -v
node -v
docker version
kubectl version --client
helm version
```

建议：

- 固定 Agent 用配置管理工具维护环境。
- 动态 Agent 用镜像固化工具版本。
- Jenkins `tools` 适合简单工具安装，但容器化 Agent 更推荐镜像内置工具。

## 12.7 工作目录与清理

Agent 工作目录会保存 workspace、临时文件和构建缓存。

常见路径：

```text
/data/jenkins-agent/workspace
/home/jenkins/agent/workspace
```

清理方式：

```groovy
post {
    always {
        cleanWs()
    }
}
```

节点磁盘巡检：

```bash
df -h
du -sh /data/jenkins-agent/workspace/*
docker system df
```

建议：

- Job 内使用 `cleanWs()` 清理工作区。
- Docker 构建节点定时清理旧镜像和缓存。
- 大制品上传制品库，不长期保存在 workspace。

## 12.8 Inbound Agent

Inbound Agent 适合 Agent 主动连接 Jenkins 的场景，例如 Agent 在 NAT 后面。

Jenkins 添加节点时选择：

```text
Launch method -> Launch agent by connecting it to the controller
```

Agent 启动命令通常类似：

```bash
java -jar agent.jar \
  -url https://jenkins.example.com/ \
  -secret <secret> \
  -name builder-01 \
  -webSocket \
  -workDir /data/jenkins-agent
```

建议：

- 优先使用 WebSocket，减少对固定 JNLP 端口的依赖。
- Agent secret 不要泄露。
- 使用 systemd 托管 Agent 进程。

systemd 示例：

```ini title="/etc/systemd/system/jenkins-agent.service"
[Unit]
Description=Jenkins Inbound Agent
After=network.target

[Service]
User=jenkins
WorkingDirectory=/data/jenkins-agent
ExecStart=/usr/bin/java -jar /data/jenkins-agent/agent.jar -url https://jenkins.example.com/ -secret CHANGE_ME -name builder-01 -webSocket -workDir /data/jenkins-agent
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启动：

```bash
systemctl daemon-reload
systemctl enable --now jenkins-agent
```

## 12.9 节点隔离建议

按用途隔离：

| 节点组 | 用途 |
| --- | --- |
| `ci-build` | 普通编译测试 |
| `docker-build` | 镜像构建 |
| `k8s-deploy-test` | 测试环境部署 |
| `k8s-deploy-prod` | 生产部署 |
| `security-scan` | 安全扫描 |

按风险隔离：

- 不可信 MR 构建使用低权限 Agent。
- 生产部署使用独立 Agent 和独立凭据。
- Docker socket 节点不要运行不可信代码。
- 多租户 Jenkins 要隔离 workspace、凭据和节点。

## 12.10 常见问题

### 12.10.1 Agent 离线

排查：

```bash
systemctl status sshd
java -version
df -h
free -m
```

检查 Jenkins 节点日志：

```text
Node -> Log
```

常见原因：

- SSH 无法连接。
- Java 版本不兼容。
- 工作目录权限错误。
- Agent 主机磁盘满。
- Controller 到 Agent 网络不通。

### 12.10.2 Host key verification failed

处理方式：

- 在 Jenkins Controller 用户的 `known_hosts` 中加入 Agent 主机指纹。
- 或在节点配置中选择合适的 Host Key Verification Strategy。

建议生产环境不要直接跳过主机校验。

### 12.10.3 构建一直排队

排查方向：

- Job 的 `agent label` 是否存在可用节点。
- 节点是否在线。
- 节点执行器是否已满。
- Job 是否设置了禁止并发。
- 队列中是否有更早的任务占用资源。

### 12.10.4 Docker 权限错误

排查：

```bash
id jenkins
ls -l /var/run/docker.sock
docker version
```

常见处理：

```bash
usermod -aG docker jenkins
systemctl restart docker
```

注意用户组变更后，需要重新登录或重启 Agent 进程。

## 12.11 参考资料

- [Jenkins Distributed Builds](https://www.jenkins.io/doc/book/using/using-agents/)
- [Jenkins SSH Build Agents Plugin](https://plugins.jenkins.io/ssh-slaves/)
- [Jenkins Inbound Agents](https://www.jenkins.io/doc/book/using/using-agents/#launching-agent)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
