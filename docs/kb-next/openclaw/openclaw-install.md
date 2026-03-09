---
title: OpenClaw 安装与初始化
tags: [openclaw, ai-agent, cli, gateway]
sidebar_position: 1
---

本篇记录 OpenClaw CLI 在本机的安装、初始化和基础验证流程，适合第一次接触 OpenClaw 的同学快速完成从 0 到可用。

> 本文命令基于 `openclaw 2026.3.2`。  
> 官方文档入口：`https://docs.openclaw.ai/cli`

## 1. 安装前准备

### 1.1 系统要求

- macOS / Linux / Windows（有 Node.js 环境）
- Node.js `>= 20.0`（当前项目要求）
- npm 可用（用于全局安装 `openclaw`）

### 1.2 检查 Node.js / npm

```bash
node -v
npm -v
```

如果未安装 Node.js，建议先参考内部文档完成环境准备：  
[NVM 安装与使用](/docs/journal/opstools/nvm)

---

## 2. 安装 OpenClaw CLI

```bash
npm install -g openclaw
```

检查是否安装成功：

```bash
which openclaw
openclaw --version
openclaw --help
```

如果你看到类似 `OpenClaw 2026.3.2` 的输出，说明 CLI 已可用。

---

## 3. 初始化配置（首次必做）

OpenClaw 提供两种常见初始化方式：

- `openclaw setup`：轻量初始化（配置文件 + workspace）
- `openclaw onboard`：完整向导（gateway、workspace、skills、channels）

### 3.1 轻量初始化（推荐先跑通）

```bash
openclaw setup --wizard
```

常用参数（可选）：

```bash
openclaw setup --mode local --workspace ~/.openclaw/workspace
```

### 3.2 完整初始化（一步到位）

```bash
openclaw onboard
```

如果你想一次性配置模型、网关和技能，优先使用 `onboard`。

---

## 4. 启动 Gateway

初始化完成后，启动网关服务：

```bash
openclaw gateway start
```

查看状态和健康检查：

```bash
openclaw gateway status
openclaw gateway health
openclaw doctor
```

### 4.1 端口被占用时

```bash
openclaw gateway start --force
```

### 4.2 前台运行（调试模式）

```bash
openclaw gateway run
```

---

## 5. 安装后自检清单

建议按下面顺序快速验证：

```bash
# 1) 版本与帮助
openclaw --version
openclaw --help

# 2) 配置文件路径
openclaw config file

# 3) 网关健康
openclaw gateway status
openclaw gateway health

# 4) 全局状态
openclaw status
```

---

## 6. 常用安装后命令

```bash
# 重新进入配置向导
openclaw configure

# 打开控制台 UI
openclaw dashboard

# 查看模型状态
openclaw models status

# 查看技能列表
openclaw skills list
```

更多命令可参考：  
[OpenClaw 命令手册](./openclaw-command.md)

---

## 7. 升级与卸载

### 7.1 升级 OpenClaw

```bash
openclaw update
openclaw update status
```

### 7.2 卸载网关与本地状态

```bash
openclaw uninstall
```

### 7.3 卸载 CLI（npm 全局包）

```bash
npm uninstall -g openclaw
```

---

## 8. 常见问题（FAQ）

### Q1: `openclaw: command not found`

- 确认是否执行了 `npm install -g openclaw`
- 检查 npm 全局 bin 是否在 `PATH` 中
- 新开一个终端再执行 `openclaw --version`

### Q2: Gateway 启动失败或端口冲突

先看状态：

```bash
openclaw gateway status
openclaw gateway probe
```

再尝试强制启动：

```bash
openclaw gateway start --force
```

### Q3: 配置混乱，想重置后重来

```bash
openclaw reset
openclaw setup --wizard
```

---

## 9. 最小可用流程（复制即用）

```bash
# 1) 安装
npm install -g openclaw

# 2) 初始化
openclaw setup --wizard

# 3) 启动网关
openclaw gateway start

# 4) 检查状态
openclaw gateway status
openclaw doctor
```

完成以上 4 步后，OpenClaw 就已经进入可用状态，可以继续做频道接入、模型配置和自动化任务编排。

---

## 10. 飞书接入参考

- OpenClaw 接入飞书（参考）：[腾讯云开发者文章](https://cloud.tencent.com/developer/article/2626151)
