---
title: 自建 YUM 软件源
sidebar_position: 7
---

# 自建 YUM 软件源

> 适用于 CentOS 7、RHEL 7/8/9、Rocky Linux、AlmaLinux 等 RPM/YUM 生态。
>
> 常见自建方式有两类：
> - 同步阿里云等互联网镜像源，适合有外网出口、希望统一内网安装入口的场景
> - 基于本地 ISO 制作离线源，适合封闭网络、等保区或交付离线环境
>
> CentOS 7 已于 2024-06-30 结束生命周期。现在做 CentOS 7 自建源时，更适合基于 `vault` 归档源或固定版本 ISO，而不是按“持续更新的在线源”来设计。

## 方案选择

| 方案 | 适用场景 | 优点 | 注意点 |
| --- | --- | --- | --- |
| 同步互联网源 | 有外网机器，内网主机统一从内网安装 | 软件包更新及时，可定时增量同步 | 需要定期同步，注意版本一致性 |
| 挂载本地 ISO | 无外网、一次性交付、固定版本 | 简单直接，完全离线 | 内容通常固定，后续补丁需要额外导入 |

## 服务端公共准备

以下示例以 Rocky Linux 8/9 为主，CentOS 7 仅需把 `dnf` 替换为 `yum`，把 `dnf-plugins-core` 替换为 `yum-utils`。

安装仓库服务组件：

```bash
# Rocky / Alma / RHEL 8+
sudo dnf install -y nginx createrepo_c dnf-plugins-core rsync

# CentOS 7
sudo yum install -y nginx createrepo yum-utils rsync
```

准备仓库目录：

```bash
sudo mkdir -p /srv/repos
sudo chown -R root:root /srv/repos
```

使用 Nginx 发布仓库：

```nginx
server {
    listen 80;
    server_name _;

    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    location /repos/ {
        alias /srv/repos/;
    }
}
```

例如写入 `/etc/nginx/conf.d/repos.conf` 后启动：

```bash
sudo nginx -t
sudo systemctl enable --now nginx
```

如果启用了防火墙：

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

如果启用了 SELinux，建议同步修正目录标签：

```bash
sudo semanage fcontext -a -t httpd_sys_content_t "/srv/repos(/.*)?"
sudo restorecon -Rv /srv/repos
```

## 方式一：同步阿里云等互联网软件源

这类方案的核心思路是：

1. 在一台能访问公网镜像站的仓库服务器上配置上游源
2. 使用 `reposync` 拉取 RPM 包和元数据到本地目录
3. 通过 Nginx / HTTP 对内发布
4. 内网客户端只访问自建仓库地址

### 1. 配置上游镜像源

下面以 Rocky Linux 8 为例，同步阿里云的 `BaseOS`、`AppStream` 和 `EPEL`。

创建上游源文件 `/etc/yum.repos.d/upstream-aliyun.repo`：

```ini
[baseos]
name=Aliyun Rocky 8 BaseOS
baseurl=https://mirrors.aliyun.com/rockylinux/8/BaseOS/x86_64/os/
enabled=1
gpgcheck=0

[appstream]
name=Aliyun Rocky 8 AppStream
baseurl=https://mirrors.aliyun.com/rockylinux/8/AppStream/x86_64/os/
enabled=1
gpgcheck=0

[epel]
name=Aliyun EPEL 8
baseurl=https://mirrors.aliyun.com/epel/8/Everything/x86_64/
enabled=1
gpgcheck=0
```

说明：

- 如果你使用的是 AlmaLinux、CentOS、RHEL 兼容发行版，只需要替换对应 `baseurl`
- 如果不想用阿里云，也可以改成清华、华为云、官方镜像等其他上游地址
- 为了让 `reposync` 行为可控，建议直接写 `baseurl`，不要依赖 `mirrorlist`

### 2. 同步软件包和元数据

准备目录并执行同步：

```bash
sudo mkdir -p /srv/repos/rocky/8
sudo dnf clean all
sudo dnf makecache

sudo dnf reposync \
  --repoid=baseos \
  --repoid=appstream \
  --repoid=epel \
  --download-metadata \
  --delete \
  -p /srv/repos/rocky/8
```

同步完成后，目录结构通常类似：

```text
/srv/repos/rocky/8/
├── appstream/
├── baseos/
└── epel/
```

说明：

- `--download-metadata` 会把上游 `repodata` 一并同步下来，客户端可直接使用
- `--delete` 会清理上游已经删除的旧包，便于保持一致
- 如果只想保留最新版本，可根据需求增加精简参数，但生产仓库通常更建议完整同步

### 3. 可选：重新生成元数据

如果你只是纯同步上游，不改目录内容，通常不需要重建元数据。

如果你做了这些动作，则要重新执行 `createrepo_c`：

- 手工新增了某些 RPM 包
- 删除了部分 RPM 包
- 合并了多个目录
- 自己做了二次整理

命令示例：

```bash
sudo createrepo_c --update /srv/repos/rocky/8/baseos
sudo createrepo_c --update /srv/repos/rocky/8/appstream
sudo createrepo_c --update /srv/repos/rocky/8/epel
```

### 4. 客户端配置自建仓库

客户端配置 `/etc/yum.repos.d/local.repo`：

```ini
[local-baseos]
name=Local Rocky 8 BaseOS
baseurl=http://repo.example.com/repos/rocky/8/baseos/
enabled=1
gpgcheck=0

[local-appstream]
name=Local Rocky 8 AppStream
baseurl=http://repo.example.com/repos/rocky/8/appstream/
enabled=1
gpgcheck=0

[local-epel]
name=Local Rocky 8 EPEL
baseurl=http://repo.example.com/repos/rocky/8/epel/
enabled=1
gpgcheck=0
```

刷新客户端缓存：

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf repolist
```

### 5. 定时同步示例

如果要长期维护内网源，建议做周期同步。

示例脚本 `/usr/local/bin/sync-yum-repo.sh`：

```bash
#!/bin/bash
set -euo pipefail

BASE_DIR=/srv/repos/rocky/8

dnf clean all
dnf makecache

dnf reposync \
  --repoid=baseos \
  --repoid=appstream \
  --repoid=epel \
  --download-metadata \
  --delete \
  -p "${BASE_DIR}"
```

授权并加入定时任务：

```bash
sudo chmod +x /usr/local/bin/sync-yum-repo.sh
sudo crontab -e
```

例如每天凌晨 2 点同步：

```cron
0 2 * * * /usr/local/bin/sync-yum-repo.sh >> /var/log/sync-yum-repo.log 2>&1
```

### 6. CentOS 7 同步阿里云归档源示例

CentOS 7 和 Rocky 8 最大的差异在于：

- CentOS 7 没有 `BaseOS` / `AppStream` 拆分
- 更常见的是 `os`、`updates`、`extras`
- 由于 CentOS 7 已结束维护，建议直接同步固定版本 `7.9.2009` 的 `vault` 归档源

创建上游源文件 `/etc/yum.repos.d/upstream-centos7-vault.repo`：

```ini
[centos7-os]
name=Aliyun CentOS 7.9.2009 os
baseurl=https://mirrors.aliyun.com/centos-vault/centos/7.9.2009/os/x86_64/
enabled=1
gpgcheck=0

[centos7-updates]
name=Aliyun CentOS 7.9.2009 updates
baseurl=https://mirrors.aliyun.com/centos-vault/centos/7.9.2009/updates/x86_64/
enabled=1
gpgcheck=0

[centos7-extras]
name=Aliyun CentOS 7.9.2009 extras
baseurl=https://mirrors.aliyun.com/centos-vault/centos/7.9.2009/extras/x86_64/
enabled=1
gpgcheck=0

[epel7]
name=Aliyun EPEL 7
baseurl=https://mirrors.aliyun.com/epel/7/x86_64/
enabled=1
gpgcheck=0
```

执行同步：

```bash
sudo mkdir -p /srv/repos/centos/7.9.2009
sudo yum clean all
sudo yum makecache

sudo reposync \
  -r centos7-os \
  -r centos7-updates \
  -r centos7-extras \
  -r epel7 \
  --download-metadata \
  --delete \
  -p /srv/repos/centos/7.9.2009
```

同步后的目录通常类似：

```text
/srv/repos/centos/7.9.2009/
├── centos7-os/
├── centos7-updates/
├── centos7-extras/
└── epel7/
```

客户端仓库配置示例 `/etc/yum.repos.d/local-centos7.repo`：

```ini
[local-centos7-os]
name=Local CentOS 7 os
baseurl=http://repo.example.com/repos/centos/7.9.2009/centos7-os/
enabled=1
gpgcheck=0

[local-centos7-updates]
name=Local CentOS 7 updates
baseurl=http://repo.example.com/repos/centos/7.9.2009/centos7-updates/
enabled=1
gpgcheck=0

[local-centos7-extras]
name=Local CentOS 7 extras
baseurl=http://repo.example.com/repos/centos/7.9.2009/centos7-extras/
enabled=1
gpgcheck=0

[local-epel7]
name=Local EPEL 7
baseurl=http://repo.example.com/repos/centos/7.9.2009/epel7/
enabled=1
gpgcheck=0
```

说明：

- 这里建议目录和仓库名都显式带上 `7.9.2009`
- 如果你只需要系统基础包，可以只同步 `os`、`updates`、`extras`
- 如果业务还依赖额外组件，再补 `epel7`、`sclo` 或其他专项仓库

## 方式二：使用本地 ISO 软件源

这种方式适合离线环境，尤其是交付一套固定版本的系统时。

核心思路是把 ISO 中的 `Packages` / `repodata` 或 `BaseOS` / `AppStream` 内容挂载出来，再通过 HTTP 对内发布。

### 1. 挂载 ISO

```bash
sudo mkdir -p /mnt/iso
sudo mount -o loop /data/iso/Rocky-8.10-x86_64-dvd1.iso /mnt/iso
```

检查 ISO 内容：

```bash
ls /mnt/iso
```

说明：

- Rocky / Alma / RHEL 8/9 的 DVD ISO 通常包含 `BaseOS` 和 `AppStream`
- CentOS 7 的 DVD ISO 常见结构是根目录直接包含 `Packages` 和 `repodata`

### 2. 复制 ISO 内容到仓库目录

以 Rocky 8/9 为例：

```bash
sudo mkdir -p /srv/repos/rocky/8-iso
sudo rsync -av /mnt/iso/BaseOS/ /srv/repos/rocky/8-iso/BaseOS/
sudo rsync -av /mnt/iso/AppStream/ /srv/repos/rocky/8-iso/AppStream/
```

如果是 CentOS 7 这类单一目录结构，也可以直接复制整个挂载目录：

```bash
sudo mkdir -p /srv/repos/centos/7/os
sudo rsync -av /mnt/iso/ /srv/repos/centos/7/os/
```

复制完成后可卸载 ISO：

```bash
sudo umount /mnt/iso
```

### 3. 是否需要重新生成元数据

分两种情况：

- 完整复制 ISO 原始目录且保留 `repodata`：通常不需要重新生成
- 你额外追加了自定义 RPM，或者改动了目录结构：需要重新生成

例如：

```bash
sudo createrepo_c --update /srv/repos/rocky/8-iso/BaseOS
sudo createrepo_c --update /srv/repos/rocky/8-iso/AppStream
```

### 4. 客户端配置 ISO 仓库

Rocky / Alma / RHEL 8/9 客户端示例：

```ini
[iso-baseos]
name=ISO BaseOS
baseurl=http://repo.example.com/repos/rocky/8-iso/BaseOS/
enabled=1
gpgcheck=0

[iso-appstream]
name=ISO AppStream
baseurl=http://repo.example.com/repos/rocky/8-iso/AppStream/
enabled=1
gpgcheck=0
```

CentOS 7 客户端示例：

```ini
[iso-os]
name=ISO OS
baseurl=http://repo.example.com/repos/centos/7/os/
enabled=1
gpgcheck=0
```

刷新缓存：

```bash
sudo yum clean all
sudo yum makecache
sudo yum repolist
```

### 5. CentOS 7 基于 ISO 的离线源示例

CentOS 7 更适合直接用固定版本 DVD ISO 建立离线仓库，例如 `CentOS-7-x86_64-DVD-2009.iso`。

挂载 ISO：

```bash
sudo mkdir -p /mnt/iso
sudo mount -o loop /data/iso/CentOS-7-x86_64-DVD-2009.iso /mnt/iso
```

复制到发布目录：

```bash
sudo mkdir -p /srv/repos/centos/7.9.2009-iso/os
sudo rsync -av /mnt/iso/ /srv/repos/centos/7.9.2009-iso/os/
sudo umount /mnt/iso
```

如果你只是完整复制 ISO 原始内容，通常不需要额外执行 `createrepo`。如果后面补充了自定义 RPM，再执行：

```bash
sudo createrepo --update /srv/repos/centos/7.9.2009-iso/os
```

客户端配置 `/etc/yum.repos.d/local-centos7-iso.repo`：

```ini
[local-centos7-iso]
name=Local CentOS 7 ISO
baseurl=http://repo.example.com/repos/centos/7.9.2009-iso/os/
enabled=1
gpgcheck=0
```

验证：

```bash
sudo yum clean all
sudo yum makecache
sudo yum repolist
sudo yum install -y vim
```

这种方式最适合：

- 封闭网络的一次性交付
- 只要求提供系统安装基线包
- 不计划继续跟进 CentOS 7 后续补丁变更的场景

## 验证方式

服务端先确认 HTTP 可访问：

```bash
curl -I http://repo.example.com/repos/
curl http://repo.example.com/repos/rocky/8/baseos/repodata/repomd.xml
```

客户端确认仓库正常：

```bash
sudo dnf repolist
sudo dnf install -y vim
```

## 常见问题

### 1. 客户端报 404

优先检查：

- `baseurl` 是否和目录实际路径一致
- Nginx `alias /srv/repos/;` 是否以 `/` 结尾
- 仓库目录下是否真的存在 `repodata/repomd.xml`

### 2. 客户端提示 metadata 读取失败

通常是以下原因：

- 目录同步不完整
- 手工改过 RPM，但没有重新执行 `createrepo_c`
- 客户端缓存未清理

处理方式：

```bash
sudo dnf clean all
sudo dnf makecache
```

必要时在服务端重建元数据：

```bash
sudo createrepo_c --update /srv/repos/rocky/8/baseos
```

### 3. AppStream 模块包装不上

这类问题通常出现在：

- 只同步了 `BaseOS`，没有同步 `AppStream`
- 系统版本和仓库版本不一致

建议：

- EL8/EL9 场景下，`BaseOS` 和 `AppStream` 一起维护
- 同一个客户端尽量只使用同版本同来源的一组仓库

### 4. SELinux 导致 Nginx 无法读取仓库目录

常见处理：

```bash
sudo semanage fcontext -a -t httpd_sys_content_t "/srv/repos(/.*)?"
sudo restorecon -Rv /srv/repos
```

## 运维建议

- 生产环境建议区分“同步机”和“发布机”，先同步再发布
- 同步互联网仓库时，尽量固定上游版本和目录结构，不要混用多个不同代际仓库
- 离线 ISO 仓库适合安装基线，不适合长期补丁更新
- 如果需要更严格的签名校验，可以保留 `gpgcheck=1` 并同步官方 GPG key
- 如果内网客户端很多，建议在仓库服务前加 Nginx 缓存、负载均衡或对象存储分发
