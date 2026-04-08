---
sidebar_position: 10
title: 网络
---

# 09 网络

## 网络基础（TCP/IP）

基础概念：

- IP：主机地址。
- TCP/UDP：传输层协议。
- 端口：进程通信端点。
- 路由：数据包转发路径。
- DNS：域名到 IP 的解析系统。

常用查看命令：

```bash
ip addr                     # 查看网卡和 IP 地址
ip route                    # 查看路由表
ping -c 4 8.8.8.8           # 测试网络连通性
hostname -I                 # 查看本机 IP
arp -n                      # 查看 ARP 缓存
```

判断思路：

- `ping` 不通时，先区分是本机网络、网关、DNS 还是目标主机问题。
- 先确认本机 IP 和路由，再测试目标连通性。

## `curl` / `wget`

```bash
curl -I https://example.com                                 # 只查看响应头
curl -sS https://example.com/health                         # 静默请求，但出错时仍显示错误
curl -o file.tar.gz https://example.com/file.tar.gz         # 下载并保存为指定文件名
wget https://example.com/file.tar.gz                        # 直接下载文件
curl -v https://example.com                                 # 打印详细请求过程
curl -w "\ncode=%{http_code} time=%{time_total}\n" -o /dev/null -s https://example.com # 输出状态码和耗时
```

排障建议：

- `curl -I` 适合快速确认状态码、重定向、响应头。
- `curl -v` 适合看 TLS 握手、代理、重定向和连接细节。
- 下载失败时先确认 DNS、证书、代理和防火墙。

## 端口与连接（`netstat/ss`）

`ss` 是新系统推荐工具：

```bash
ss -lntp                    # 查看监听中的 TCP 端口
ss -antp                    # 查看全部 TCP 连接
ss -s                       # 查看 socket 汇总统计
ss -lunp                    # 查看监听中的 UDP 端口
sudo lsof -i :8080          # 查看某端口被哪个进程占用
```

旧工具：

```bash
netstat -lntp               # 老系统常见的监听端口查看方式
```

排查思路：

- 服务启动失败先看端口是否被占用。
- 端口开放但请求失败时，再查防火墙、绑定地址和应用日志。

## DNS

```bash
dig example.com +short      # 查询域名解析结果
dig @8.8.8.8 example.com    # 指定 DNS 服务器查询
nslookup example.com        # 传统 DNS 查询工具
cat /etc/resolv.conf        # 查看系统 DNS 配置
resolvectl status           # systemd-resolved 环境查看 DNS 状态
```

常见问题：

- DNS 解析慢导致应用超时。
- 本地缓存与权威记录不一致。
- `/etc/resolv.conf` 被 DHCP 或 NetworkManager 覆盖。

排查顺序：

1. 先查本机 DNS 配置。
2. 再对比不同 DNS 服务器的解析结果。
3. 最后判断是本地网络、递归 DNS 还是权威解析问题。

## 连通性测试（`nc/traceroute/tcpdump`）

```bash
nc -zv 10.0.0.8 443         # 测试目标主机端口是否可达
traceroute example.com      # 查看路由路径
sudo tcpdump -i any port 53 # 抓取 DNS 流量
sudo tcpdump -i any host 10.0.0.8 # 抓取与指定主机相关的流量
```

适用场景：

- `nc` 适合确认某个端口是不是能打通。
- `traceroute` 适合定位链路中断的大致位置。
- `tcpdump` 适合确认数据包到底有没有发出、有没有回来。

## 防火墙（`iptables/ufw`）

Ubuntu 常用 `ufw`：

```bash
sudo ufw status verbose     # 查看规则和默认策略
sudo ufw allow 22/tcp       # 放行 SSH
sudo ufw allow 80,443/tcp   # 放行 Web 端口
sudo ufw delete allow 80/tcp # 删除规则
sudo ufw enable             # 启用防火墙
```

`iptables` 基础查看：

```bash
sudo iptables -L -n -v      # 查看过滤表规则
sudo iptables -t nat -L -n -v # 查看 NAT 表规则
```

安全原则：

- 默认拒绝入站，按需开放端口。
- 变更规则前先确认回滚路径，避免把自己锁在机器外。
- 远程操作时优先保留 SSH 通道并验证新规则后再退出。
