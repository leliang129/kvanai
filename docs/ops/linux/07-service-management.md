---
sidebar_position: 8
title: 服务管理
---

# 07 服务管理

## `systemctl`

`systemd` 是主流 Linux 发行版的服务管理器。

```bash
systemctl status nginx               # 查看服务状态
systemctl start nginx                # 启动服务
systemctl stop nginx                 # 停止服务
systemctl restart nginx              # 重启服务
systemctl reload nginx               # 重载配置，不完全重启
systemctl daemon-reload              # 重新加载 unit 文件
```

常见查询：

```bash
systemctl list-units --type=service  # 查看当前已加载服务
systemctl is-active nginx            # 判断服务是否运行中
systemctl is-enabled nginx           # 判断是否设置为开机启动
systemctl list-dependencies nginx    # 查看服务依赖关系
```

建议：

- 修改 unit 文件后必须执行 `daemon-reload`。
- 能 `reload` 的服务尽量少做 `restart`，降低中断风险。

## service 管理

在部分系统仍可用：

```bash
service nginx status                 # 查看服务状态
service nginx restart                # 重启服务
chkconfig --list                     # 老系统查看开机启动项
```

说明：

- `service` 往往是对 `systemd` 或 SysV init 的兼容封装。
- 新系统优先使用 `systemctl`，功能更完整。

## 开机启动

```bash
sudo systemctl enable nginx          # 设置开机启动
sudo systemctl disable nginx         # 取消开机启动
sudo systemctl mask nginx            # 禁止服务被手动或依赖启动
sudo systemctl unmask nginx          # 取消 mask
systemctl get-default                # 查看默认启动目标
```

补充说明：

- `enable` 只是设置开机启动，不代表当前马上启动。
- `mask` 比 `disable` 更强，适合禁止误启动。

## 自定义 service

示例：`/etc/systemd/system/myapp.service`

```ini
[Unit]
Description=My App Service
After=network.target

[Service]
Type=simple
User=app
WorkingDirectory=/opt/myapp
EnvironmentFile=-/etc/default/myapp
ExecStart=/opt/myapp/bin/start.sh
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

关键字段说明：

- `User`：服务运行用户。
- `WorkingDirectory`：服务工作目录。
- `EnvironmentFile`：额外环境变量文件。
- `ExecStart`：启动命令。
- `ExecReload`：重载命令。
- `Restart`：异常退出后的重启策略。

生效步骤：

```bash
sudo systemctl daemon-reload         # 重新加载 unit 文件
sudo systemctl enable --now myapp    # 设置开机启动并立刻启动
sudo systemctl status myapp          # 查看运行状态
```

## 服务日志与排障

排障常用：

```bash
journalctl -u myapp -n 100 --no-pager # 查看最近 100 行日志
journalctl -fu myapp                  # 实时追踪服务日志
systemctl show myapp | grep Exec      # 查看 unit 生效后的执行参数
```

排障顺序建议：

1. 先看 `systemctl status`，确认失败状态和退出码。
2. 再看 `journalctl -u <service>`，定位具体报错。
3. 最后检查配置文件、权限、端口、依赖路径和环境变量。
