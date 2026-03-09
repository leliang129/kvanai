---
title: OpenClaw 命令手册
sidebar_position: 2
---

# OpenClaw 命令手册

> OpenClaw v2026.3.2 命令行工具完全指南

---

## 目录

- [快速开始](#快速开始)
- [Gateway 管理](#gateway-管理)
- [消息发送](#消息发送)
- [频道管理](#频道管理)
- [定时任务](#定时任务)
- [模型管理](#模型管理)
- [配置管理](#配置管理)
- [浏览器控制](#浏览器控制)
- [节点管理](#节点管理)
- [健康检查](#健康检查)
- [其他命令](#其他命令)

---

## 快速开始

```bash
# 查看版本
openclaw --version

# 查看帮助
openclaw --help

# 交互式配置向导
openclaw configure

# 启动控制台 UI
openclaw dashboard

# 健康检查
openclaw doctor
```

---

## Gateway 管理

```bash
# 查看 Gateway 状态
openclaw gateway status

# 启动 Gateway 服务
openclaw gateway start

# 停止 Gateway 服务
openclaw gateway stop

# 重启 Gateway 服务
openclaw gateway restart

# 前台运行 Gateway
openclaw gateway run

# 强制启动（杀掉占用端口的进程）
openclaw gateway start --force

# 查看 Gateway 健康状态
openclaw gateway health

# 卸载 Gateway 服务
openclaw gateway uninstall

# 安装 Gateway 服务
openclaw gateway install

# 端口检查
openclaw gateway probe
```

---

## 消息发送

```bash
# 发送消息
openclaw message send --target <目标> --message <内容>

# 通过 Telegram 发送
openclaw message send --channel telegram --target @用户名 --message "Hello"

# 通过 Discord 发送
openclaw message send --channel discord --target channel:123 --message "Hello"

# 发送带媒体的消息
openclaw message send --target +15555550123 --message "Hi" --media photo.jpg

# 发送投票
openclaw message poll --channel discord --target channel:123 --poll-question "Choose:" --poll-option A --poll-option B

# 发送 Emoji 反应
openclaw message react --channel discord --target 123 --message-id 456 --emoji "✅"

# 读取最近消息
openclaw message read --channel telegram --limit 10

# 搜索消息
openclaw message search --channel discord --query "关键词"

# 置顶消息
openclaw message pin --channel discord --target 123 --message-id 456
```

---

## 频道管理

```bash
# 查看已配置的频道
openclaw channels list

# 查看频道状态
openclaw channels status

# 添加频道账号
openclaw channels add --channel telegram --token <token>

# 登录频道（扫码）
openclaw channels login --channel whatsapp

# 登出频道
openclaw channels logout --channel whatsapp

# 查看频道能力
openclaw channels capabilities

# 查看频道日志
openclaw channels logs
```

---

## 定时任务

```bash
# 查看定时任务列表
openclaw cron list

# 查看定时任务状态
openclaw cron status

# 添加定时任务
openclaw cron add --name <名称> --cron <表达式> --channel <频道> --message <内容>

# 示例：每天早上 9 点发送消息
openclaw cron add --name "每日提醒" --cron "0 9 * * *" --channel telegram --message "早上好！"

# 示例：每 30 分钟执行一次
openclaw cron add --name "健康检查" --every "30m" --channel telegram --announce --message "检查系统状态"

# 运行定时任务（调试）
openclaw cron run <jobId>

# 查看执行历史
openclaw cron runs

# 禁用定时任务
openclaw cron disable <jobId>

# 启用定时任务
openclaw cron enable <jobId>

# 删除定时任务
openclaw cron rm <jobId>
```

**Cron 表达式格式**：`秒 分 时 日 月 周`

| 表达式         | 说明        |
| -------------- | ----------- |
| `0 9 * * *`    | 每天 9:00   |
| `0 */30 * * *` | 每 30 分钟  |
| `0 9 * * 1-5`  | 工作日 9:00 |
| `0 0 * * *`    | 每天午夜    |

---

## 模型管理

```bash
# 查看当前模型状态
openclaw models status

# 列出可用模型
openclaw models list

# 设置默认模型
openclaw models set <model-name>

# 设置图片模型
openclaw models set-image <model-name>

# 扫描免费模型
openclaw models scan

# 管理模型别名
openclaw models aliases

# 管理模型认证
openclaw models auth
```

---

## 配置管理

```bash
# 查看配置文件路径
openclaw config file

# 获取配置值
openclaw config get <key>

# 设置配置值
openclaw config set <key> <value>

# 删除配置
openclaw config unset <key>

# 验证配置
openclaw config validate
```

---

## 浏览器控制

```bash
# 启动专用浏览器
openclaw browser start

# 停止浏览器
openclaw browser stop

# 查看浏览器状态
openclaw browser status

# 打开网页
openclaw browser open --url <网址>
```

---

## 节点管理

```bash
# 查看配对的节点
openclaw nodes list

# 查看节点状态
openclaw nodes status

# 配对新节点
openclaw nodes pair

# 发送命令到节点
openclaw nodes run --node <node-id> --command <命令>
```

---

## 健康检查

```bash
# 运行健康检查
openclaw doctor

# 修复问题
openclaw doctor --repair
```

---

## 其他命令

```bash
# 交互式 onboarding
openclaw onboard

# TUI 终端界面
openclaw tui

# 查看会话列表
openclaw sessions list

# 查看技能列表
openclaw skills list

# 生成 Shell 补全脚本
openclaw completion

# 生成配对 QR 码
openclaw qr

# 更新 OpenClaw
openclaw update

# 查看更新状态
openclaw update status

# 卸载
openclaw uninstall

# 重置配置
openclaw reset

# 搜索文档
openclaw docs <关键词>

# 查看日志
openclaw logs

# 查看状态
openclaw status
```

---

## 常用示例

### 通过 Telegram 发送消息

```bash
openclaw message send --channel telegram --target @username --message "Hello from OpenClaw!"
```

### 通过 WhatsApp 发送消息

```bash
openclaw message send --channel whatsapp --target +15555550123 --message "Hello!"
```

### 设置定时任务每天早上检查服务

```bash
openclaw cron add \
  --name "每日服务检查" \
  --cron "0 8 * * *" \
  --channel telegram \
  --announce \
  --message "检查所有服务状态"
```

### 启动开发模式 Gateway

```bash
openclaw --dev gateway
```

### 查看帮助

```bash
# 查看所有命令
openclaw --help

# 查看特定命令帮助
openclaw <command> --help

# 例如
openclaw message --help
openclaw gateway --help
```

---

## 配置示例

### 基本配置结构

```json
{
  "meta": {
    "name": "OpenClaw"
  },
  "gateway": {
    "port": 18789,
    "mode": "local"
  },
  "models": {
    "default": "openai/gpt-5.2-codex"
  },
  "channels": {
    "telegram": {
      "enabled": true
    }
  }
}
```

---

> 📖 完整文档：https://docs.openclaw.ai