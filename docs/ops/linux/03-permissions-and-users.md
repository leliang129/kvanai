---
sidebar_position: 4
title: 权限与用户
---

# 03 权限与用户

## 权限模型（rwx）

Linux 权限分为三组：属主（u）、属组（g）、其他用户（o）。

- `r`：读（4）
- `w`：写（2）
- `x`：执行（1）

示例：`-rwxr-x---` 对应 `750`。

查看权限：

```bash
ls -l /etc/passwd       # 查看文件权限
namei -l /etc/ssh/sshd_config # 逐级查看路径权限
stat /opt/myapp/run.sh  # 查看更完整的文件元数据
```

理解重点：

- 文件可执行不等于目录可进入，目录的 `x` 表示可遍历。
- 目录的 `w` 表示可在目录下创建、删除、重命名文件。
- 生产排障中，“权限不够”很多时候是父目录权限导致的。

## `chmod` / `chown`

修改权限：

```bash
chmod 644 app.conf         # 普通配置文件常见权限
chmod -R 750 /opt/myapp    # 递归设置目录权限
chmod u+x deploy.sh        # 给属主增加执行权限
chmod g-w secrets.txt      # 移除属组写权限
```

修改所有者：

```bash
sudo chown root:root /etc/my.cnf  # 修改属主和属组
sudo chown -R app:app /srv/myapp  # 递归修改目录属主
sudo chgrp www-data /srv/www      # 只修改所属组
```

建议：

- 配置文件通常用 `644`，私钥通常用 `600`。
- 服务目录所有权要与运行用户一致，否则容易出现写入失败。
- 递归改权限前先确认路径，避免误改系统目录。

## 用户与用户组

常用命令：

```bash
id                         # 查看当前用户 UID、GID 和所属组
getent passwd app          # 查看用户信息
getent group sudo          # 查看用户组信息
sudo useradd -m -s /bin/bash app # 创建用户并生成家目录
sudo passwd app            # 设置用户密码
sudo usermod -aG sudo app  # 把用户加入 sudo 组
sudo userdel -r testuser   # 删除用户及家目录
```

用户管理原则：

- 服务使用专用低权限用户运行。
- 权限按组授予，减少散落到个人账号。
- 账号生命周期要可管理，离职或停用账号及时锁定或删除。

## sudo 机制

`sudo` 用于临时提升权限执行命令，并记录审计日志。

查看 sudo 规则：

```bash
sudo -l                    # 查看当前用户可执行的 sudo 命令
sudo visudo                # 安全编辑 sudoers
sudo visudo -f /etc/sudoers.d/deploy # 编辑独立授权文件
```

最小权限示例（放到 `/etc/sudoers.d/deploy`）：

```text
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp
```

安全建议：

- 不要随意给 `NOPASSWD:ALL`。
- 尽量细化到命令级别授权。
- 关键主机要开启操作审计并定期复核授权。

## 特殊权限位与 `umask`

常见特殊权限位：

- SUID：进程以文件属主身份运行。
- SGID：进程以文件属组身份运行，目录上还可继承组。
- Sticky Bit：目录下只有文件属主或 root 才能删除文件，常见于 `/tmp`。

查看与设置：

```bash
find / -xdev -type f -perm -4000 2>/dev/null # 查找 SUID 文件
find / -xdev -type d -perm -1000 2>/dev/null # 查找 Sticky Bit 目录
chmod 2775 /srv/shared                        # 给目录设置 SGID
umask                                         # 查看当前默认权限掩码
umask 027                                     # 设置当前 shell 默认权限掩码
```

建议：

- 共享目录可结合 SGID 控制组继承。
- 不明来源的 SUID 文件要重点核查。
- 安全要求较高的环境，应使用更严格的 `umask`，例如 `027`。
