---
title: GitLab 安装与架构说明
sidebar_position: 3
---

# GitLab 安装与架构说明


## 3.1.1 GitLab 介绍

GitLab 是一个基于 Ruby on Rails 构建的开源仓库管理系统，使用 Git 作为代码管理工具，并提供 Web 界面来访问公开或私有项目。

GitLab 常见特性：

- 开源免费（社区版）。
- 可作为 Git 代码仓库使用。
- 提供易用的 Web 管理界面。
- 支持多租户管理模式。
- 功能丰富，覆盖代码托管、协作、CI/CD 等场景。
- 支持离线提交后再同步。
- 安全性高，可对不同用户设置不同权限，并限制用户仅访问特定代码范围（实现代码部分可见）。

## 3.1.2 GitLab 架构

GitLab 是由多个组件组成的复杂系统，常见服务构成如下：

- `Nginx`：静态 Web 服务器。
- `GitLab Shell`：处理基于 SSH 会话的 Git 命令与 `authorized_keys` 管理。
- `gitlab-workhorse`：轻量级反向代理，用于加速 GitLab 请求处理。
- `Unicorn`：Rack 应用 HTTP 服务（旧架构中用于托管 GitLab Rails）。
- `Puma (GitLab Rails)`：处理 Web 界面与 API 请求。
- `Gitaly`：统一处理 Git RPC 调用。
- `PostgreSQL`：主数据库。
- `Redis`：缓存数据库。
- `Sidekiq`：后台队列任务执行（异步任务）。
- `GitLab Exporter`：暴露 GitLab 指标。
- `Node Exporter`：暴露主机节点指标。
- `Prometheus / Alertmanager / Grafana / Sentry / Jaeger`：GitLab 自监控与可观测组件。
- `Inbound email (SMTP)`：接收用于更新 issue 的邮件。
- `Outbound email (SMTP)`：向用户发送通知邮件。
- `LDAP Authentication`：LDAP 认证集成。
- `MinIO`：对象存储服务。
- `Registry`：容器镜像仓库（支持镜像 `push` / `pull`）。
- `Runner`：执行 GitLab CI/CD 作业。

### Omnibus GitLab

由于 GitLab 组件较多、逐一管理复杂，官方提供了 Omnibus GitLab 方案，用于统一编排和管理各组件。

- Omnibus GitLab 基于 Chef 的 cookbook/recipe 自动化编排能力，减少手工配置复杂度。
- 项目地址：[Omnibus GitLab](https://gitlab.com/gitlab-org/omnibus-gitlab)
- 架构文档：[Omnibus Architecture](https://docs.gitlab.com/omnibus/architecture/)

常用统一管理命令：

```bash
gitlab-ctl reconfigure
gitlab-ctl restart
```

除 `gitlab-ctl` 外，还提供组件专用命令，例如：

- `gitlab-backup`
- `gitlab-psql`
- `gitlab-rails`
- `gitlab-rake`

GitLab 通过统一模板配置文件为各组件提供参数（常见配置入口为 `/etc/gitlab/gitlab.rb`）。

## 3.2 GitLab 安装

### 3.2.2 安装 GitLab 要求

GitLab 对硬件资源要求相对较高，建议如下：

- 测试环境：内存 `4G+`，新版本（如 `gitlab-ce_17.3.1`）建议 `8G+`。
- 生产环境：建议 `CPU 2C+`、内存 `8G+`、磁盘 `10G+`（实际与用户规模相关）。
- 注意：内存过低可能导致部分 GitLab 服务无法启动。

数据库要求：

- 从 GitLab `12.1` 开始，Linux 包安装不再支持 MySQL，仅支持 PostgreSQL。

参考：

- [GitLab 安装要求](https://docs.gitlab.com/ce/install/requirements.html)

### 3.2.3 安装前准备

安装前建议先完成系统基础准备：

- Ubuntu：配置国内镜像源（如阿里云、清华）以加速下载。
- RHEL/CentOS/Rocky：建议基于最小化系统安装，并做基础系统调整。

RHEL 系常见预处理命令示例：

```bash
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
systemctl disable firewalld
sed -i '/SELINUX/s/enforcing/disabled/' /etc/sysconfig/selinux
hostnamectl set-hostname gitlab.example.com
reboot
```

参考：

- [GitLab 安装总览](https://docs.gitlab.com/install/)
- [GitLab CE 安装文档](https://docs.gitlab.com/install/)

### 3.2.4 GitLab 安装

GitLab 有多种安装方式，本节以官方包安装为主，并附 Docker/Kubernetes 方式。

#### 3.2.4.1 安装包与镜像源

- GitLab 安装文档：[Package Installation](https://docs.gitlab.com/install/package/ubuntu/)
- GitLab CE 清华镜像：[TUNA GitLab CE Mirror](https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/)
- 官方包仓库：[GitLab CE Packages](https://packages.gitlab.com/gitlab/gitlab-ce)

#### 3.2.4.2 Ubuntu 下载与安装示例

```bash
# 下载（按系统版本选择）
wget https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/ubuntu/pool/jammy/main/g/gitlab-ce/gitlab-ce_17.3.1-ce.0_amd64.deb

# 方式1
dpkg -i gitlab-ce_17.3.1-ce.0_amd64.deb

# 方式2
apt install ./gitlab-ce_17.3.1-ce.0_amd64.deb
```

#### 3.2.4.3 修改 GitLab 配置

常用目录：

- `/etc/gitlab`：配置目录（重点）
- `/var/opt/gitlab`：数据目录（重点）
- `/var/log/gitlab`：日志目录
- `/run/gitlab`：运行目录
- `/opt/gitlab`：安装目录

编辑配置文件：

```bash
vim /etc/gitlab/gitlab.rb
```

关键配置项示例：

```ruby
external_url 'http://gitlab.example.com'

# 新版本可直接指定 root 初始密码（必须满足复杂度要求，至少 8 位）
gitlab_rails['initial_root_password'] = "YourStrongPassword"

# 可选：SMTP
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.qq.com"
gitlab_rails['smtp_port'] = 465
gitlab_rails['smtp_user_name'] = "your@qq.com"
gitlab_rails['smtp_password'] = "授权码"
gitlab_rails['smtp_domain'] = "qq.com"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['smtp_tls'] = true
gitlab_rails['gitlab_email_from'] = "your@qq.com"

# 可选：端口
nginx['listen_port'] = 8080
gitlab_sshd['enable'] = true
gitlab_sshd['listen_address'] = '0.0.0.0:2222'
```

资源较小场景可关闭部分监控组件（按需）：

```ruby
prometheus['enable'] = false
alertmanager['enable'] = false
node_exporter['enable'] = false
redis_exporter['enable'] = false
postgres_exporter['enable'] = false
gitlab_exporter['enable'] = false
prometheus_monitoring['enable'] = false
grafana['enable'] = false
```

#### 3.2.4.4 初始化与启动验证

每次修改配置后执行：

```bash
gitlab-ctl reconfigure
gitlab-ctl status
```

端口占用检查（典型为 80 端口）：

```bash
lsof -i :80
```

#### 3.2.4.5 GitLab 常用命令

```bash
gitlab-ctl check-config
gitlab-ctl show-config
gitlab-ctl reconfigure
gitlab-ctl stop
gitlab-ctl start
gitlab-ctl restart
gitlab-ctl status
gitlab-ctl tail
gitlab-ctl tail nginx
gitlab-ctl service-list
```

组件命令：

- `gitlab-rails`：控制台及高级运维（如改密、`dbconsole`）。
- `gitlab-psql`：PostgreSQL 命令行。
- `gitlab-rake`：备份恢复等数据操作。

#### 3.2.4.6 一键安装脚本

原文提供了自动化安装脚本示例（`install_gitlab.sh`），核心逻辑包括：

- 按系统下载并安装对应包（`dpkg`/`yum`）。
- 自动写入 `external_url`、SMTP、初始 root 密码等配置。
- 执行 `gitlab-ctl reconfigure` 并输出访问地址。

实际使用时建议根据你的系统版本、域名和安全策略二次改造。

#### 3.2.4.7 基于 Docker 安装 GitLab

官方参考：

- [GitLab Docker 安装](https://docs.gitlab.com/ee/install/docker.html)
- [Docker 预配置说明](https://docs.gitlab.com/ee/install/docker/configuration.html#pre-configure-docker-container)
- [Docker Hub: gitlab/gitlab-ce](https://hub.docker.com/r/gitlab/gitlab-ce)

示例：

```bash
export GITLAB_HOME=/srv/gitlab
docker pull gitlab/gitlab-ce:17.0.1-ce.0
docker run --detach \
  --hostname gitlab.example.com \
  --publish 443:443 --publish 80:80 --publish 22:22 \
  --name gitlab \
  --restart always \
  --volume $GITLAB_HOME/config:/etc/gitlab \
  --volume $GITLAB_HOME/logs:/var/log/gitlab \
  --volume $GITLAB_HOME/data:/var/opt/gitlab \
  --shm-size 256m \
  gitlab/gitlab-ce:17.0.1-ce.0
```

#### 3.2.4.8 基于 Kubernetes 安装 GitLab

官方参考：

- [GitLab Operator 安装文档](https://docs.gitlab.com/operator/installation.html)

示例流程（GitLab Operator）：

```bash
kubectl create namespace gitlab-system

# 方式1：清单安装 operator
GL_OPERATOR_VERSION=0.8.1
PLATFORM=kubernetes
kubectl apply -f https://gitlab.com/api/v4/projects/18899486/packages/generic/gitlab-operator/${GL_OPERATOR_VERSION}/gitlab-operator-${PLATFORM}-${GL_OPERATOR_VERSION}.yaml

# 方式2：Helm 安装 operator
helm repo add gitlab-operator https://gitlab.com/api/v4/projects/18899486/packages/helm/stable
helm repo update
```

说明：

- 需提前准备 `cert-manager` 等依赖组件。
- 部分镜像拉取可能受网络环境影响，必要时配置镜像加速或代理。
