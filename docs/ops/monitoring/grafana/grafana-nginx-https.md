---
title: Grafana Nginx 与 HTTPS
sidebar_position: 8
---

# Grafana Nginx 与 HTTPS


## 8.1 适用场景

Grafana 在生产环境里通常不会直接裸露 `3000` 端口，而是通过 Nginx 暴露域名并接入 HTTPS。

典型目标：

- 使用域名访问 Grafana
- 接入 HTTPS
- 统一走 Nginx 反向代理
- 支持根路径或子路径访问

## 8.2 基础访问模式

最常见两种：

1. 根路径访问

```text
https://grafana.example.com/
```

2. 子路径访问

```text
https://example.com/grafana/
```

根路径更简单，子路径配置更容易出错。

## 8.3 Grafana 关键配置项

Grafana 反向代理场景最关键的是 `domain` 和 `root_url`。

根路径示例：

```ini title="/etc/grafana/grafana.ini"
[server]
protocol = http
http_addr = 127.0.0.1
http_port = 3000
domain = grafana.example.com
root_url = https://grafana.example.com/
```

说明：

- `http_addr = 127.0.0.1`：只允许本机访问 Grafana 服务端口。
- `http_port = 3000`：Grafana 本地监听端口。
- `domain`：对外访问域名。
- `root_url`：浏览器访问 Grafana 的最终地址。

子路径示例：

```ini title="/etc/grafana/grafana.ini"
[server]
protocol = http
http_addr = 127.0.0.1
http_port = 3000
domain = example.com
root_url = https://example.com/grafana/
serve_from_sub_path = true
```

说明：

- `root_url` 必须带上 `/grafana/`
- `serve_from_sub_path = true` 必须开启

修改后重启：

```bash
systemctl restart grafana-server  # 重启 Grafana 服务使配置生效
systemctl status grafana-server  # 查看 Grafana 服务状态
```

## 8.4 Nginx 根路径代理

Nginx 配置示例：

```nginx title="/etc/nginx/conf.d/grafana.conf"
server {
    listen 80;  # 监听 HTTP 端口
    server_name grafana.example.com;  # Grafana 域名
    return 301 https://$host$request_uri;  # 强制跳转到 HTTPS
}

server {
    listen 443 ssl http2;  # 监听 HTTPS 端口并启用 HTTP/2
    server_name grafana.example.com;  # Grafana 域名

    ssl_certificate /etc/nginx/ssl/grafana.crt;  # 证书文件
    ssl_certificate_key /etc/nginx/ssl/grafana.key;  # 证书私钥

    location / {
        proxy_pass http://127.0.0.1:3000;  # 反向代理到本机 Grafana
        proxy_set_header Host $host;  # 传递原始 Host 头
        proxy_set_header X-Real-IP $remote_addr;  # 传递客户端真实 IP
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  # 追加代理链路 IP
        proxy_set_header X-Forwarded-Proto https;  # 告诉 Grafana 外层协议是 HTTPS
        proxy_http_version 1.1;  # 使用 HTTP/1.1 代理
        proxy_set_header Upgrade $http_upgrade;  # 支持 WebSocket 升级
        proxy_set_header Connection $connection_upgrade;  # 支持 WebSocket 连接头
    }
}
```

如果你的 Nginx 配置里没有 `connection_upgrade` 变量，可以直接改成：

```nginx
proxy_set_header Connection "upgrade";
```

## 8.5 Nginx 子路径代理

Grafana 子路径部署需要同时改 Grafana 和 Nginx。

Nginx 配置示例：

```nginx title="/etc/nginx/conf.d/grafana.conf"
server {
    listen 80;  # 监听 HTTP 端口
    server_name example.com;  # 主站域名
    return 301 https://$host$request_uri;  # 强制跳转到 HTTPS
}

server {
    listen 443 ssl http2;  # 监听 HTTPS 端口并启用 HTTP/2
    server_name example.com;  # 主站域名

    ssl_certificate /etc/nginx/ssl/example.crt;  # 证书文件
    ssl_certificate_key /etc/nginx/ssl/example.key;  # 证书私钥

    location /grafana/ {
        proxy_pass http://127.0.0.1:3000/;  # 反向代理到 Grafana，并保留子路径映射
        proxy_set_header Host $host;  # 传递原始 Host 头
        proxy_set_header X-Real-IP $remote_addr;  # 传递客户端真实 IP
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  # 追加代理链路 IP
        proxy_set_header X-Forwarded-Proto https;  # 告诉 Grafana 外层协议是 HTTPS
        proxy_http_version 1.1;  # 使用 HTTP/1.1 代理
        proxy_set_header Upgrade $http_upgrade;  # 支持 WebSocket 升级
        proxy_set_header Connection "upgrade";  # 支持 WebSocket 连接头
    }
}
```

## 8.6 Nginx 配置检查

验证：

```bash
nginx -t  # 校验 Nginx 配置
systemctl reload nginx  # 重新加载 Nginx 配置
curl -I http://grafana.example.com  # 检查 HTTP 是否跳转
curl -k -I https://grafana.example.com  # 检查 HTTPS 响应头
```

## 8.7 HTTPS 证书建议

证书来源常见有两类：

- 内网自签或企业 CA
- 公网 Let’s Encrypt

建议：

- 生产环境证书定期轮换。
- 证书私钥只允许 Nginx 账户访问。
- 如果 Grafana 只在内网使用，也建议统一启用 HTTPS。

## 8.8 常见问题

### 8.8.1 登录后跳转到错误地址

常见原因：

- `domain` 写错。
- `root_url` 写错。
- 反向代理没有传 `X-Forwarded-Proto`。

### 8.8.2 页面样式丢失或静态资源 404

常见原因：

- 子路径部署时 `root_url` 没带 `/grafana/`
- `serve_from_sub_path = true` 未开启
- Nginx `location` 配置错误

### 8.8.3 浏览器提示重定向循环

常见原因：

- Grafana 认为自己是 HTTP，但外部是 HTTPS
- `X-Forwarded-Proto` 没传
- `root_url` 协议写成了 `http`

### 8.8.4 直接访问 3000 端口仍然可用

建议：

- 把 `http_addr` 绑定到 `127.0.0.1`
- 或通过防火墙限制 `3000` 端口只允许本机访问

## 8.9 参考资料

- [Grafana Reverse Proxy](https://grafana.com/tutorials/run-grafana-behind-a-proxy/)
- [Grafana Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
- [Nginx Reverse Proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
