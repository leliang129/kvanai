---
sidebar_position: 3
title: 常用命令
---

# 02 常用命令

## 目录切换与定位（`pwd/cd`）

```bash
pwd                       # 查看当前所在目录
cd /etc                   # 切换到指定目录
cd ..                     # 返回上一级目录
cd -                      # 切换回上一次所在目录
ls                        # 查看当前目录内容
tree -L 2 /etc 2>/dev/null # 以树形结构查看目录，限制 2 层
```

建议：

- 执行删除、移动、覆盖命令前，先确认 `pwd` 输出。
- 目录层级较深时，`tree` 比多次 `ls` 更直观。

## 文件操作（`ls/cp/mv/rm`）

```bash
ls -alh                    # 列出目录详细信息
mkdir -p /tmp/demo/logs    # 递归创建目录
touch app.log              # 创建空文件或更新时间戳
cp -av src/ dst/           # 保留属性并显示复制过程
mv old.txt new.txt         # 重命名文件
rm -rf /tmp/demo           # 递归删除目录，高危操作
```

建议：

- 危险删除前先 `pwd`、`ls` 校验路径。
- 生产环境避免裸 `rm -rf`，建议先移动到回收目录。
- 跨机器或保留权限同步时，优先考虑 `rsync`。

## 文件属性与权限（`stat/chmod/chown`）

```bash
stat app.log                    # 查看文件大小、权限、时间戳等元数据
chmod 644 app.conf              # 设置普通配置文件权限
chmod +x deploy.sh              # 给脚本增加执行权限
sudo chown app:app /srv/myapp   # 修改文件属主和属组
ls -l /srv/myapp                # 查看目录中文件权限
```

建议：

- 配置文件通常用 `644`，脚本通常用 `755`，私钥通常用 `600`。
- 服务写入失败时，先查文件属主和父目录权限。

## 查找（`find/locate`）

`find` 实时扫描，精确但可能较慢：

```bash
find /var/log -type f -name "*.log" -mtime -1      # 最近 1 天修改过的日志
find . -type f -size +100M                         # 查找大文件
find /etc -type f -name "*.conf" | head           # 查找配置文件
find /tmp -type f -mtime +7 -delete               # 删除 7 天前的临时文件
```

`locate` 基于索引，速度快但可能不实时：

```bash
locate nginx.conf        # 从索引中查找文件
sudo updatedb            # 更新 locate 索引
```

补充技巧：

- 用 `-maxdepth` 限制搜索层级，避免全盘扫描太慢。
- 用 `-exec` 或 `xargs` 批量处理结果前，先确认样本输出。
- 带 `-delete` 的命令必须先去掉 `-delete` 试跑。

## 文本查看与统计（`cat/less/head/tail/wc`）

```bash
cat /etc/os-release      # 直接查看短文本文件
less /var/log/syslog     # 分页查看长文件
head -n 20 app.log       # 查看前 20 行
tail -n 100 app.log      # 查看最后 100 行
tail -f app.log          # 实时追踪文件新增内容
wc -l app.log            # 统计文件行数
wc -c app.log            # 统计文件字节数
```

排障常用组合：

```bash
tail -f app.log | grep -E "ERROR|WARN" # 实时过滤异常日志
```

建议：

- 查看大文件优先用 `less`、`tail`，不要先 `cat` 到终端。
- 处理编码异常时可先用 `file` 判断文本类型。

## 文本过滤与处理（`grep/sort/uniq/cut`）

```bash
grep "ERROR" app.log                           # 查找包含 ERROR 的行
grep -nE "ERROR|WARN" app.log                  # 显示行号并匹配多个模式
cut -d ':' -f 1 /etc/passwd                    # 提取每行第 1 列
sort access.log | uniq -c | sort -nr | head   # 统计重复行并倒序查看
awk '{print $1, $9}' access.log | head         # 提取指定列
sed -n '1,20p' app.log                         # 打印第 1 到 20 行
```

建议：

- 排障时优先把大文件缩小到时间段，再做 `grep` 和统计。
- 批量替换前先去掉 `-i` 验证结果。

## 压缩（`tar/gzip`）

```bash
tar -czf logs-$(date +%F).tar.gz /var/log/myapp   # 打包并 gzip 压缩
tar -xzf logs-2026-03-25.tar.gz -C /tmp/restore   # 解压到指定目录
tar -tf logs-2026-03-25.tar.gz                    # 查看压缩包内容
gzip app.log                                      # 直接压缩单个文件
gunzip app.log.gz                                 # 解压 gzip 文件
```

参数速记：

- `c`：创建归档。
- `x`：解压归档。
- `z`：通过 gzip 压缩。
- `f`：指定归档文件名。
- `t`：只查看归档内容，不解压。

## 磁盘（`df/du`）

```bash
df -h                    # 查看分区容量
df -i                    # 查看 inode 使用率
du -sh /var/log/*        # 统计目录占用
du -xh / | sort -h | tail # 粗略查看大目录
```

快速定位大文件：

```bash
find /var -type f -size +500M -exec ls -lh {} \; # 查找大于 500M 的文件
```

常见坑：

- 日志已删除但进程仍持有句柄，空间不会立刻释放。
- 可以用 `lsof | grep deleted` 定位后重启对应进程。
- `du` 看目录占用，`df` 看文件系统总占用，两者不一致时通常要查已删除未释放文件。

## 进程与系统状态（`ps/top/free/uptime`）

```bash
ps -ef                                  # 查看全部进程
ps aux | grep nginx                     # 查找指定进程
top                                     # 实时查看进程和资源使用
free -h                                 # 查看内存使用
uptime                                  # 查看系统运行时长和负载
kill <pid>                              # 发送终止信号给进程
```

建议：

- CPU 高先看 `top` 和热点进程。
- 内存异常先看 `free -h`，再结合进程 RSS 分析。
- 杀进程优先 `kill`，确认无响应再考虑更强制的信号。

## 网络与连通性（`ip/ping/curl/ss`）

```bash
ip addr                                 # 查看本机网卡和 IP
ip route                                # 查看路由表
ping -c 4 8.8.8.8                       # 测试网络连通性
curl -I https://example.com             # 查看 HTTP 响应头
curl -v https://example.com             # 查看详细请求过程
ss -lntp                                # 查看监听中的 TCP 端口
sudo lsof -i :8080                      # 查看端口被哪个进程占用
```

建议：

- 服务不通先分清是 DNS、网络、端口还是应用本身问题。
- 本机端口监听正常但外部仍不通时，再查防火墙和安全组。

## 系统信息（`uname/hostnamectl/date`）

```bash
uname -a                                # 查看内核和系统架构信息
hostnamectl                             # 查看主机名和系统版本
cat /etc/os-release                     # 查看发行版信息
date                                    # 查看当前时间
timedatectl                             # 查看时区和时间同步状态
whoami                                  # 查看当前登录用户
```

建议：

- 登录新机器先确认系统版本、主机名、时间和当前用户。
- 排障时记录 `date` 输出，便于和日志时间线对齐。

## 环境变量与历史命令（`env/export/history`）

```bash
env | sort                              # 查看当前环境变量
export APP_ENV=prod                     # 设置当前 shell 环境变量
echo "$APP_ENV"                         # 查看变量值
history | tail -n 20                    # 查看最近执行的命令
clear                                   # 清空当前终端显示
```

建议：

- 临时环境变量只在当前 shell 生效，新开终端后会失效。
- 复盘问题时，`history` 往往能帮助还原操作过程。

## 传输与同步（`scp/rsync`）

```bash
scp app.conf user@10.0.0.8:/tmp/   # 复制文件到远程主机
scp -r ./dist user@10.0.0.8:/srv/  # 递归复制目录
rsync -avz ./dist/ user@10.0.0.8:/srv/app/ # 增量同步目录
rsync -avz --delete ./dist/ /srv/app/      # 目标目录与源目录保持一致
```

建议：

- 批量同步优先使用 `rsync`，速度和可控性更好。
- `--delete` 会删除目标端多余文件，正式执行前先加 `--dry-run`。
