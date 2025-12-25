---
title: NVM 安装与使用
tags: [linux, macos, windows, nodejs, nvm]
sidebar_position: 2
---

本篇记录如何在 Linux、macOS、Windows 安装并使用 NVM（Node Version Manager），并统一用 `version` 变量来切换 Node.js 版本（避免在命令里到处手改版本号）。

> 说明：Linux/macOS 用 `nvm`；Windows 推荐使用 `nvm-windows`（命令同名但实现不同）。

## 统一版本变量（推荐）

后文示例默认你先设置两个变量：

### Linux / macOS（bash/zsh）

```bash
export version="0.39.7"         # nvm 安装脚本版本（用于下面的 curl/wget URL）
export node_version="20.11.1"   # Node.js 版本（用于 nvm install/use）
```

> 只在当前终端会话生效；想要每次打开终端自动带上这个变量，可以写入 `~/.bashrc` / `~/.zshrc`。

### Windows（PowerShell）

```powershell
$env:node_version = "20.11.1"
```

> 只在当前 PowerShell 会话生效；想长期生效可以写到 PowerShell Profile（`$PROFILE`）里。

### Windows（CMD）

```bat
set node_version=20.11.1
```

## Linux / macOS：安装 nvm（官方脚本）

### 1) 安装

```bash
curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${version}/install.sh" | bash
```

> 如果你没有 `curl`，可以用 `wget`：
>
> ```bash
> wget -qO- "https://raw.githubusercontent.com/nvm-sh/nvm/v${version}/install.sh" | bash
> ```

### 2) 加载 nvm（让当前 shell 生效）

安装脚本会提示你把下面片段加入 shell 配置（通常会自动写入）。如果你遇到 `nvm: command not found`，手动加一下：

#### bash（`~/.bashrc`）

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

#### zsh（`~/.zshrc`）

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

然后让配置生效（不想重开终端就执行一次）：

```bash
source ~/.bashrc 2>/dev/null || true
source ~/.zshrc 2>/dev/null || true
```

### 3) 验证

```bash
nvm --version
command -v nvm
```

### 4) 使用 `version` 安装/切换 Node.js

```bash
nvm install "$node_version"
nvm use "$node_version"
nvm current
node -v
npm -v
```

### 5) 设置默认版本

```bash
nvm alias default "$node_version"
nvm alias
```

### 6)（可选）加速下载（国内镜像）

如果下载很慢，可以设置 Node.js 镜像源（对 `nvm install` 生效）：

```bash
export NVM_NODEJS_ORG_MIRROR="https://npmmirror.com/mirrors/node"
```

> 也可以把这行写到 `~/.bashrc` / `~/.zshrc` 里长期生效。

## Windows：安装 nvm-windows

### 1) 安装

推荐用 `nvm-windows`（Corey Butler 维护）的安装包方式：

1. 打开仓库 Releases：`https://github.com/coreybutler/nvm-windows/releases`
2. 下载 `nvm-setup.exe` 并安装
3. 重新打开终端（PowerShell / Windows Terminal）

### 2) 验证

```powershell
nvm version
nvm list
```

### 3) 使用 `version` 安装/切换 Node.js

#### PowerShell

```powershell
$env:node_version = "20.11.1"
nvm install $env:node_version
nvm use $env:node_version
node -v
npm -v
```

#### CMD

```bat
set node_version=20.11.1
nvm install %node_version%
nvm use %node_version%
node -v
npm -v
```

### 4)（可选）配置国内镜像

```powershell
nvm node_mirror https://npmmirror.com/mirrors/node/
nvm npm_mirror https://npmmirror.com/mirrors/npm/
```

> 注意：镜像 URL 末尾的 `/` 很关键（尤其是 `node_mirror`）。

## 常用操作速查

### 查看已安装版本

```bash
nvm ls
```

Windows：

```powershell
nvm list
```

### 安装 LTS / 最新

```bash
nvm install --lts
nvm install node
nvm ls-remote --lts
```

### 卸载某版本

```bash
nvm uninstall "$node_version"
```

Windows：

```powershell
nvm uninstall $env:node_version
```

### 项目级版本（.nvmrc）

在项目根目录写入：

```bash
echo "$node_version" > .nvmrc
```

进入项目后：

```bash
nvm install
nvm use
```

## 常见问题

### 1) Linux/macOS：`nvm: command not found`

- 确认 `~/.bashrc` / `~/.zshrc` 里有 `NVM_DIR` 与 `nvm.sh` 加载片段
- 重新 `source ~/.bashrc` 或重开终端
- 如果你用的是 `zsh`（macOS 默认），不要只改 `~/.bashrc`

### 2) Windows：`nvm use` 失败 / 权限问题

- 尝试用管理员权限打开终端再执行
- 检查是否有其他 Node 安装（例如 MSI）占用 PATH，建议卸载冲突版本

### 3) Windows：不知道有哪些可装版本

```powershell
nvm list available
```
