---
title: NVM 安装与使用
tags: [linux, macos, windows, nodejs, nvm]
sidebar_position: 1
---

本篇记录如何在 Linux、macOS、Windows 安装并使用 NVM（Node Version Manager）。

这次采用的方式不是手动写死某个 `nvm` 版本，而是：**先在执行时动态获取 `nvm-sh/nvm` 当前最新 release tag，再用这个 tag 下载对应的安装脚本**。

> 官方仓库：`https://github.com/nvm-sh/nvm`

## 1. Linux / macOS 安装 nvm（动态获取最新版本）

如果你希望每次执行安装命令时，都自动取当前最新版本，可以这样写。

### 1.1 使用 curl 动态获取最新版本并安装

```bash
export version="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | awk -F '"' '/tag_name/ {print $4; exit}')"
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${version}/install.sh" | bash
```

### 1.2 一行写法

```bash
export version="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | awk -F '"' '/tag_name/ {print $4; exit}')" && curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${version}/install.sh" | bash
```

### 1.3 如果你喜欢和你示例接近的写法

```bash
export version="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | awk -F '"' '/tag_name/ {print $4; exit}')"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${version}/install.sh | bash
```

这几种写法的核心区别不大，重点是前面这句：

```bash
export version="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | awk -F '"' '/tag_name/ {print $4; exit}')"
```

它会在执行当下请求 GitHub API，并提取当前最新 release 的 `tag_name`，例如：

- `v0.40.4`
- `v0.40.5`
- 未来更新后的新版本号

你可以先单独验证一下：

```bash
export version="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | awk -F '"' '/tag_name/ {print $4; exit}')"
echo "$version"
```

如果成功输出类似 `v0.40.4`，再执行安装命令即可。

---

## 2. 如果安装后当前终端还不能直接用 nvm

安装脚本通常会自动把初始化逻辑写入你的 shell 配置文件，但当前终端会话不一定立刻生效。

手动加载：

```bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

或者重新加载 shell 配置：

```bash
source ~/.bashrc 2>/dev/null || true
source ~/.bash_profile 2>/dev/null || true
source ~/.zshrc 2>/dev/null || true
source ~/.profile 2>/dev/null || true
```

---

## 3. 验证安装

```bash
nvm --version
command -v nvm
```

如果能正常输出版本号，并且 `command -v nvm` 有结果，说明安装成功。

---

## 4. 安装并使用 Node.js

### 4.1 安装最新稳定版 Node.js

```bash
nvm install node
```

### 4.2 安装最新 LTS 版本

```bash
nvm install --lts
```

### 4.3 切换版本

```bash
nvm use node
```

或：

```bash
nvm use --lts
```

### 4.4 查看当前版本

```bash
nvm current
node -v
npm -v
```

---

## 5. 设置默认 Node.js 版本

### 5.1 默认使用最新稳定版

```bash
nvm alias default node
```

### 5.2 默认使用最新 LTS 版本

```bash
nvm alias default lts/*
```

查看别名：

```bash
nvm alias
```

---

## 6. 常用命令速查

### 6.1 查看本地已安装版本

```bash
nvm ls
```

### 6.2 查看远程可安装版本

```bash
nvm ls-remote
```

查看 LTS：

```bash
nvm ls-remote --lts
```

### 6.3 安装指定版本

```bash
nvm install 22.22.1
```

### 6.4 使用指定版本

```bash
nvm use 22.22.1
```

### 6.5 卸载某个版本

```bash
nvm uninstall 22.22.1
```

---

## 7. 项目级版本管理（推荐）

如果项目根目录里有 `.nvmrc` 文件，团队成员进入项目后就能统一 Node.js 版本。

### 7.1 写入版本

```bash
echo "22.22.1" > .nvmrc
```

### 7.2 按项目版本安装 / 切换

```bash
nvm install
nvm use
```

---

## 8. 国内网络场景建议

如果下载 Node.js 较慢，可以切换镜像：

```bash
export NVM_NODEJS_ORG_MIRROR="https://npmmirror.com/mirrors/node"
```

如果希望长期生效，可以写入：

- `~/.bashrc`
- `~/.zshrc`

然后重新加载：

```bash
source ~/.bashrc 2>/dev/null || true
source ~/.zshrc 2>/dev/null || true
```

---

## 9. Windows 怎么办？

Windows 原生环境通常使用的是 **`nvm-windows`**，它和 `nvm-sh/nvm` 不是同一个实现。

如果你是：

- **WSL / Linux 子系统**：直接用本文方式安装 `nvm`
- **Windows PowerShell / CMD 原生环境**：建议使用 `nvm-windows`

仓库地址：

- `https://github.com/coreybutler/nvm-windows`

安装后常见命令类似：

```powershell
nvm install 22.22.1
nvm use 22.22.1
node -v
npm -v
```

---

## 10. 常见问题

### 10.1 `nvm: command not found`

通常是 shell 配置还没有生效，执行：

```bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

然后再执行：

```bash
nvm --version
```

### 10.2 动态获取最新版本失败

先单独检查：

```bash
curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest
```

如果这里失败，通常是：

- 网络访问 GitHub 有问题
- 公司网络/代理限制
- GitHub API 临时不可用

你也可以只检查提取后的版本值：

```bash
export version="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | awk -F '"' '/tag_name/ {print $4; exit}')"
echo "$version"
```

如果为空，说明没成功拿到 tag。

### 10.3 GitHub API 有速率限制吗？

有。未认证访问 GitHub API 会有匿名请求频率限制。

不过对于“偶尔手工安装一次 nvm”这种场景，通常完全够用。只有在频繁自动化批量调用时，才需要考虑认证或缓存。

### 10.4 切换版本后 `node -v` 没变化

检查当前 `node` 是否来自 `~/.nvm`：

```bash
which node
which npm
```

如果不是，说明系统里可能还有其他 Node.js 安装（例如 Homebrew / apt / yum / 官方安装包），PATH 优先级更高。

---

## 11. 推荐使用方式

### 11.1 开发机初始化

```bash
export version="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | awk -F '"' '/tag_name/ {print $4; exit}')"
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${version}/install.sh" | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default lts/*
```

### 11.2 进入项目后

```bash
nvm install
nvm use
```

### 11.3 查看当前环境

```bash
nvm current
node -v
npm -v
```

---

## 12. 总结

如果你的目标是：

- 安装 `nvm` 时不手动维护版本号
- 每次执行安装命令都尽量拿到当前最新 release
- 后续仍然用 `nvm install --lts` / `.nvmrc` 管理 Node 版本

那么“**先动态获取 release tag，再下载 install.sh**”就是一个比较符合你习惯的写法。

你现在偏好的写法，本质上可以固定为：

```bash
export version="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | awk -F '"' '/tag_name/ {print $4; exit}')"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${version}/install.sh | bash
```

这样每次运行时，`${version}` 都会先去取“当前时刻 GitHub 上的最新 nvm release tag”，不需要你手工维护版本号。
