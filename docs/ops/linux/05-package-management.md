---
sidebar_position: 6
title: 包管理工具
---

# 05 包管理工具

包管理工具用于完成软件包的安装、升级、卸载、查询、依赖解析和软件源管理。虽然本章位于 Linux 目录下，但运维和开发场景里常见的是类 Unix 系统，因此这里一并整理主流 Unix / Linux 发行版的包管理工具。

## 先判断当前系统属于哪一类

常用识别方式：

```bash
cat /etc/os-release     # 大多数 Linux 发行版都提供该文件
uname -a                # 查看内核和系统信息
which apt dnf yum zypper apk pacman pkg brew
```

常见对应关系：

| 系统 / 发行版 | 高层包管理工具 | 底层包格式 / 工具 | 说明 |
| --- | --- | --- | --- |
| Debian / Ubuntu | `apt` | `dpkg` | 最常见的 Debian 系包管理方式 |
| RHEL / CentOS / Rocky / AlmaLinux / Fedora | `dnf` / `yum` | `rpm` | 新版本以 `dnf` 为主，老环境常见 `yum` |
| openSUSE / SLES | `zypper` | `rpm` | SUSE 系发行版标准工具 |
| Alpine Linux | `apk` | `apk` | 常见于容器镜像和轻量系统 |
| Arch Linux / Manjaro | `pacman` | `pacman` | 滚动更新发行版常见 |
| FreeBSD | `pkg` | `pkg` | BSD 系统里常见 |
| macOS | `brew` / `port` | 各自生态 | 常见的是 Homebrew，其次是 MacPorts |

说明：

- 高层包管理工具负责依赖解析、仓库索引和批量操作。
- 底层工具负责直接安装本地包、查询包数据库或查看包内容。
- 运维中优先使用高层工具，只有在排障或本地离线安装时才更多接触底层工具。

## Debian / Ubuntu: `apt` 和 `dpkg`

### 常用操作

```bash
sudo apt update                    # 刷新软件源索引
sudo apt install -y curl vim git   # 安装软件包
sudo apt upgrade -y                # 升级已安装软件包
sudo apt full-upgrade -y           # 允许处理依赖变更的完整升级
sudo apt remove <pkg>              # 卸载软件包，保留配置文件
sudo apt purge <pkg>               # 卸载软件包并删除配置文件
sudo apt autoremove -y             # 删除不再需要的依赖
sudo apt clean                     # 清理下载缓存
```

### 查询与排障

```bash
apt search <keyword>               # 搜索软件包
apt show <pkg>                     # 查看软件包详情
apt list --installed               # 列出已安装软件包
apt-cache policy <pkg>             # 查看候选版本和仓库来源
apt-cache madison <pkg>            # 列出仓库中的可用版本
dpkg -l | grep <pkg>               # 从本地包数据库检查安装状态
dpkg -L <pkg>                      # 查看软件包安装了哪些文件
dpkg -S /path/to/file              # 反查某个文件属于哪个包
```

### 版本控制

```bash
sudo apt install -y <pkg>=<version> # 安装指定版本
sudo apt-mark hold <pkg>            # 锁定版本，阻止自动升级
sudo apt-mark unhold <pkg>          # 取消锁定
```

### 软件源位置

- 主配置文件：`/etc/apt/sources.list`
- 附加源目录：`/etc/apt/sources.list.d/`
- 包数据库：`/var/lib/dpkg/`

## RHEL / CentOS / Rocky / AlmaLinux / Fedora: `dnf` / `yum` 和 `rpm`

`yum` 是旧版本 RHEL/CentOS 的主工具，新版本 Fedora、RHEL、Rocky、AlmaLinux 更常使用 `dnf`。很多系统里 `yum` 只是兼容入口，但命令习惯基本相近。

### `dnf` 常用操作

```bash
sudo dnf install -y curl vim git   # 安装软件包
sudo dnf upgrade -y                # 升级软件包
sudo dnf remove <pkg>              # 卸载软件包
sudo dnf autoremove -y             # 清理无用依赖
sudo dnf clean all                 # 清理元数据和缓存
sudo dnf makecache                 # 预生成缓存
```

### `dnf` 查询与版本管理

```bash
dnf search <keyword>               # 搜索软件包
dnf info <pkg>                     # 查看软件包详情
dnf list installed                 # 查看已安装软件包
dnf provides */<file>              # 反查某个文件由哪个包提供
dnf repoquery <pkg>                # 查询包来源和依赖信息
dnf --showduplicates list <pkg>    # 查看仓库中可用的全部版本
sudo dnf versionlock add <pkg>     # 锁定版本
sudo dnf versionlock delete <pkg>  # 取消版本锁定
```

### `yum` 常见等价命令

```bash
sudo yum install -y curl vim git
sudo yum update -y
sudo yum remove <pkg>
yum info <pkg>
yum list installed
yum list --showduplicates <pkg>
```

### `rpm` 底层操作

```bash
rpm -qa | grep <pkg>               # 查询已安装包
rpm -qi <pkg>                      # 查看包信息
rpm -ql <pkg>                      # 查看包内容
rpm -qf /path/to/file              # 反查文件归属
sudo rpm -ivh package.rpm          # 安装本地 rpm 包
sudo rpm -Uvh package.rpm          # 升级本地 rpm 包
```

### 软件源位置

- 仓库目录：`/etc/yum.repos.d/`
- RPM 数据库：`/var/lib/rpm/`

## openSUSE / SLES: `zypper`

SUSE 系发行版底层同样是 `rpm`，但高层管理工具是 `zypper`。

### 常用操作

```bash
sudo zypper refresh                # 刷新仓库元数据
sudo zypper install curl vim git   # 安装软件包
sudo zypper update                 # 升级已安装软件包
sudo zypper remove <pkg>           # 卸载软件包
sudo zypper search <keyword>       # 搜索软件包
sudo zypper info <pkg>             # 查看软件包信息
sudo zypper packages --installed-only # 查看已安装软件包
```

### 仓库管理

```bash
sudo zypper repos                  # 查看仓库列表
sudo zypper addrepo <url> <name>   # 新增仓库
sudo zypper removerepo <name>      # 删除仓库
```

### 版本锁定

```bash
sudo zypper addlock <pkg>          # 锁定软件包
sudo zypper removelock <pkg>       # 取消锁定
sudo zypper locks                  # 查看锁定列表
```

## Alpine Linux: `apk`

Alpine 常见于容器和极简环境，包管理器为 `apk`。

### 常用操作

```bash
sudo apk update                    # 刷新索引
sudo apk add curl vim git          # 安装软件包
sudo apk upgrade                   # 升级软件包
sudo apk del <pkg>                 # 删除软件包
apk search <keyword>               # 搜索软件包
apk info                           # 列出已安装软件包
apk info <pkg>                     # 查看软件包信息
apk info -W /path/to/file          # 反查文件属于哪个包
```

### 仓库位置

- 仓库配置：`/etc/apk/repositories`
- 缓存目录：`/var/cache/apk/`

## Arch Linux / Manjaro: `pacman`

Arch 系强调滚动更新，`pacman` 的命令简洁但需要谨慎执行全量升级。

### 常用操作

```bash
sudo pacman -Sy                    # 刷新软件包数据库
sudo pacman -S curl vim git        # 安装软件包
sudo pacman -Syu                   # 刷新并升级整个系统
sudo pacman -R <pkg>               # 卸载软件包
sudo pacman -Rs <pkg>              # 卸载软件包及其无用依赖
sudo pacman -Scc                   # 清理缓存
```

### 查询

```bash
pacman -Ss <keyword>               # 搜索仓库包
pacman -Qi <pkg>                   # 查看已安装包详情
pacman -Qs <keyword>               # 在已安装包中搜索
pacman -Ql <pkg>                   # 查看包内容
pacman -Qo /path/to/file           # 反查文件归属
```

### 软件源位置

- 主配置文件：`/etc/pacman.conf`
- 缓存目录：`/var/cache/pacman/pkg/`

## FreeBSD: `pkg`

虽然不是 Linux，但在类 Unix 运维环境中也很常见。FreeBSD 的二进制包工具是 `pkg`。

### 常用操作

```bash
sudo pkg update                    # 更新仓库目录
sudo pkg install -y curl vim git   # 安装软件包
sudo pkg upgrade -y                # 升级软件包
sudo pkg remove -y <pkg>           # 删除软件包
pkg search <keyword>               # 搜索软件包
pkg info                           # 查看已安装包
pkg info <pkg>                     # 查看软件包详情
pkg which /path/to/file            # 反查文件归属
```

## macOS: `Homebrew` 和 `MacPorts`

macOS 默认不以内建系统包管理器安装开发工具，最常见的第三方方案是 Homebrew，部分环境也会用 MacPorts。

### Homebrew 常用操作

```bash
brew update                        # 更新仓库元数据
brew install wget git              # 安装软件包
brew upgrade                       # 升级软件包
brew uninstall <pkg>               # 卸载软件包
brew search <keyword>              # 搜索软件包
brew info <pkg>                    # 查看软件包详情
brew list                          # 查看已安装软件包
brew cleanup                       # 清理旧版本缓存
```

### MacPorts 常用操作

```bash
sudo port selfupdate               # 更新 ports 树
sudo port install wget git         # 安装软件包
sudo port upgrade outdated         # 升级已过期软件包
sudo port uninstall <pkg>          # 卸载软件包
port search <keyword>              # 搜索软件包
port installed                     # 查看已安装软件包
```

## 包管理工具的通用运维动作

不管使用哪一种包管理器，运维里通常都会做这几类动作：

### 1. 安装前先刷新索引

```bash
sudo apt update
sudo dnf makecache
sudo zypper refresh
sudo apk update
```

如果直接安装而不刷新元数据，容易遇到版本过旧、仓库索引失效、依赖无法解析等问题。

### 2. 升级前先确认影响范围

常见检查动作：

```bash
apt list --upgradable
dnf check-update
zypper list-updates
apk version -l '<'
```

生产环境里，尽量避免在不了解变更内容的情况下直接执行全量升级。

### 3. 关键组件尽量锁版本

这些组件常需要锁定版本：

- 数据库客户端和服务端
- 容器运行时
- Kubernetes 相关组件
- 与业务强耦合的编译器或语言运行时

### 4. 区分“卸载软件”和“删除配置”

例如：

- `apt remove` 和 `apt purge`
- `pacman -R` 和 `pacman -Rs`

排障时不要因为误删配置导致回滚成本升高。

### 5. 谨慎引入第三方软件源

新增第三方仓库前至少确认：

- 来源可信，最好有官方签名
- 仓库优先级不会覆盖系统核心包
- 团队文档里记录了仓库地址、用途和清理方式

## 常见排障思路

### 包找不到

- 先确认仓库元数据已经刷新
- 再确认包名是否正确
- 检查是否缺少额外仓库或发行版版本不匹配

### 依赖冲突

- 先查看被锁定的软件包
- 再检查第三方仓库是否覆盖了基础仓库
- 不要直接混装不同发行版的软件包

### 文件被哪个包安装

优先使用文件反查命令：

```bash
dpkg -S /path/to/file
rpm -qf /path/to/file
apk info -W /path/to/file
pacman -Qo /path/to/file
pkg which /path/to/file
```

### 本地包安装失败

- Debian 系优先用 `apt install ./package.deb`，它会处理依赖
- RPM 系优先用 `dnf install ./package.rpm`，比直接 `rpm -ivh` 更稳妥

## 选型建议

- 通用服务器场景：优先熟悉 `apt` 和 `dnf`
- 容器与极简镜像场景：补充掌握 `apk`
- 开发机或个人环境：了解 `brew`
- 多平台运维团队：至少建立一份“发行版 -> 包管理器 -> 仓库配置位置”的对照表

如果只需要先掌握最常见的两类生态，可以从下面这一组开始：

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y curl vim git

# RHEL / Rocky / AlmaLinux / Fedora
sudo dnf install -y curl vim git
```
