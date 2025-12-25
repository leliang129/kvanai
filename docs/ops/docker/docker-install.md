---
title: Docker 安装部署
sidebar_position: 2
---

本文聚焦 Docker Engine 在常见 Linux 发行版上的安装方式，包括官方一键脚本与基于阿里云镜像源的手动步骤，便于在国内网络快速部署。

> ⚠️ 建议先卸载旧版本 (`sudo apt-get remove docker docker-engine docker.io containerd runc`)，并确保服务器可访问镜像源。

## 0. 一键安装脚本

```bash
curl -fsSL https://get.docker.com | bash -s docker
# 可指定镜像: curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
sudo systemctl enable --now docker
sudo docker run --rm hello-world
```

适合测试或临时环境，生产仍建议使用企业镜像源/离线包以控制版本。

## 1. Ubuntu / Debian（阿里云源）

### step 1：安装基础依赖

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
```

### step 2：信任 Docker GPG 公钥

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### step 3：写入软件源信息

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### step 4：安装 Docker

```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

### 安装指定版本

```bash
apt-cache madison docker-ce
sudo apt-get install -y docker-ce=<VERSION>
```

## 2. CentOS / RHEL（阿里云源）

### step 1：安装工具

```bash
sudo yum install -y yum-utils
```

### step 2：添加软件源

```bash
sudo yum-config-manager --add-repo \
  https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

### step 3：安装 Docker

```bash
sudo yum install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

### step 4：启动服务

```bash
sudo systemctl enable --now docker
```

> 可编辑 `/etc/yum.repos.d/docker-ce.repo`，将 `[docker-ce-test]` 中 `enabled=0` 改为 `1` 以启用测试源。

### 安装指定版本

```bash
yum list docker-ce.x86_64 --showduplicates | sort -r
sudo yum install -y docker-ce-<VERSION>
```

安装完成后使用 `docker version`、`docker run --rm hello-world` 验证，并根据需要将用户加入 docker 组 (`sudo usermod -aG docker $USER && newgrp docker`)。
