---
sidebar_position: 12
title: 安全
---

# 11 安全

## 用户安全

基础策略：

- 禁止共享账号。
- 普通工作使用普通用户，必要时再通过 `sudo` 提权。
- 长期不用账号及时锁定或删除。

常用命令：

```bash
sudo passwd -l testuser      # 锁定用户
sudo userdel -r testuser     # 删除用户及家目录
chage -l app                 # 查看密码策略
sudo faillog -a              # 查看登录失败记录
id app                       # 查看用户 UID、GID 和所属组
```

建议：

- 服务进程使用专用账号运行。
- 高权限账号数量要可控并定期复核。

## SSH 安全

`/etc/ssh/sshd_config` 建议：

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
AllowUsers ops deploy
```

密钥与权限：

```bash
ssh-keygen -t ed25519 -C "ops@example.com" # 生成 SSH 密钥
chmod 700 ~/.ssh                           # SSH 目录建议权限
chmod 600 ~/.ssh/id_rsa                    # 私钥权限必须严格限制
chmod 600 ~/.ssh/authorized_keys           # 授权公钥文件权限
sudo systemctl reload sshd                 # 重载 SSH 配置
```

最佳实践：

- 优先使用密钥登录，禁用弱密码。
- 限制来源 IP，配合跳板机或防火墙。
- 关键主机开启 MFA 或堡垒机审计。
- 改 SSH 配置前保留一个已登录会话，避免把自己锁在门外。

## 防火墙策略

原则：最小开放。

```bash
sudo ufw default deny incoming   # 默认拒绝入站
sudo ufw default allow outgoing  # 默认允许出站
sudo ufw allow 22/tcp            # 放行 SSH
sudo ufw allow 443/tcp           # 放行 HTTPS
sudo ufw status verbose          # 查看当前规则
```

变更建议：

- 先放通管理口，再收紧策略。
- 远程操作时准备回滚任务，例如 `at` 定时恢复规则。
- 有云防火墙或安全组时，要同时核对系统内外两层策略。

## 文件权限安全

重点目录：

- SSH 私钥：`~/.ssh/id_rsa` 必须 `600`。
- SSH 目录：`~/.ssh` 建议 `700`。
- 配置文件避免世界可写，即避免 `o+w`。

检查高风险文件：

```bash
find / -xdev -type f -perm -0002 2>/dev/null # 查找全局可写文件
find / -xdev -type f -perm -4000 2>/dev/null # 查找 SUID 文件
find / -xdev -type d -perm -1000 2>/dev/null # 查找 Sticky Bit 目录
stat ~/.ssh/id_rsa                            # 检查私钥文件权限
```

安全建议：

- 定期巡检高风险权限文件。
- 应用配置文件按最小权限开放，避免给组外或其他用户写权限。

## 系统更新与漏洞修复

基础原则：

- 安全更新要有节奏地推进，不要长期拖延。
- 高危漏洞要先评估暴露面，再安排修复窗口。

常用命令：

```bash
sudo apt update && sudo apt list --upgradable # 查看可升级包
sudo apt upgrade -y                           # 执行升级
sudo dnf check-update                         # 查看 dnf 可升级包
sudo dnf update -y                            # 执行升级
uname -r                                      # 确认当前内核版本
```

建议：

- 补丁前先备份或快照。
- 关键业务主机先在测试环境验证。
- 升级后确认服务状态、端口、日志、监控是否正常。

## Fail2ban（进阶）

Fail2ban 通过日志识别恶意尝试并自动封禁 IP。

安装与启动（Ubuntu）：

```bash
sudo apt install -y fail2ban      # 安装 fail2ban
sudo systemctl enable --now fail2ban # 设置开机启动并立即启动
sudo fail2ban-client status       # 查看整体状态
sudo fail2ban-client status sshd  # 查看 sshd jail 状态
```

简单配置示例：`/etc/fail2ban/jail.local`

```ini
[sshd]
enabled = true
maxretry = 5
bantime = 1h
findtime = 10m
```

建议：

- 与 SSH 密钥策略结合使用。
- 白名单办公出口 IP，避免误封。
- 改规则后要验证不会影响正常运维入口。
