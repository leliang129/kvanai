---
title: GitLab 配置 Let’s Encrypt 证书
sidebar_position: 5
---

本文介绍两种在 GitLab Omnibus 环境中启用 HTTPS 的方式，并以 GitLab 内置的 Let’s Encrypt 集成为推荐方案，另提供 Certbot 作为可选替代。

## 前置条件

- 已通过 DNS 将 `gitlab.example.com` 指向 GitLab 服务器公网 IP。
- 服务器已开放 80 与 443 端口，防火墙策略允许外部访问。
- 使用 Omnibus 版本 GitLab，拥有 `root` 或 `sudo` 权限。
- 若部署在反向代理或负载均衡之后，需保证 ACME 验证请求能透传至 GitLab。

## 方案一：GitLab 内置 Let’s Encrypt（推荐）

内置方案由 GitLab 负责 ACME 验证、证书下发与续期管理，配置简洁且与官方支持流程一致。

### 配置 `gitlab.rb`

```ruby
external_url "https://gitlab.example.com"

letsencrypt['enable'] = true
letsencrypt['auto_renew'] = true
letsencrypt['contact_emails'] = ["admin@example.com"]

# 可选：调整续期时间窗口（默认每日随机）
letsencrypt['auto_renew_hour'] = 2
letsencrypt['auto_renew_minute'] = 30

# 可选：调试时启用测试环境（上线前记得关闭）
# letsencrypt['staging'] = true

# 需要 DNS 验证时可配置提供商
# letsencrypt['acme_challenge'] = {
#   'provider' => 'cloudflare',
#   'cloudflare_api_token' => 'xxxxxxxx'
# }
```

### 执行与验证

```bash
sudo gitlab-ctl reconfigure
sudo gitlab-ctl status
```

- `gitlab-ctl reconfigure` 会触发证书申请或续期，并将证书存放在 `/etc/gitlab/ssl/`。
- 若申请失败，可查看 `sudo gitlab-ctl tail letsencrypt` 获取详细日志。
- 浏览器访问 `https://gitlab.example.com`，确认 HTTPS 成功启用。

### 续期策略

- GitLab 会在证书接近过期时自动执行 ACME 续期。
- `letsencrypt['auto_renew'] = true` 时，续期任务由 `gitlab-ctl reconfigure` 配置的定时器自动触发。
- 无需手动重载 NGINX，GitLab 会在续期完成后自动使用新证书。

## 方案二：使用 Certbot 管理证书（自定义场景）

若需要自定义证书存放位置、整合其他站点或使用外部自动化，可选择 Certbot 方案。在启用前请关闭 GitLab 内置 Let’s Encrypt。

### 安装与签发证书

1. 安装 Certbot（示例：`sudo apt install certbot python3-certbot-nginx`）。
2. 使用 GitLab NGINX 的 `webroot` 目录进行 HTTP 验证：
   ```bash
   sudo certbot certonly \
     --webroot -w /var/opt/gitlab/nginx/www \
     -d gitlab.example.com
   ```
3. 证书默认位于 `/etc/letsencrypt/live/gitlab.example.com/`。

### 配置 `gitlab.rb`

```ruby
external_url "https://gitlab.example.com"

nginx['enable'] = true
nginx['redirect_http_to_https'] = true
nginx['redirect_http_to_https_port'] = 80

nginx['ssl_certificate']     = "/etc/letsencrypt/live/gitlab.example.com/fullchain.pem"
nginx['ssl_certificate_key'] = "/etc/letsencrypt/live/gitlab.example.com/privkey.pem"

# 可选：限制 TLS 版本与加密套件
nginx['ssl_protocols'] = "TLSv1.2 TLSv1.3"
nginx['ssl_ciphers']   = "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"

# 关闭 GitLab 内置 Let’s Encrypt，避免冲突
letsencrypt['enable'] = false
```

保存后执行：

```bash
sudo gitlab-ctl reconfigure
sudo gitlab-ctl hup nginx
```

若使用外部负载均衡或自定义端口，请同步调整 `external_url` 以及 `nginx['listen_port']`、`nginx['listen_https']`。

### 续期与自动化

- Certbot 默认安装 `systemd` 定时任务，可通过 `sudo certbot renew --dry-run` 进行测试。
- 续期后需重载 GitLab NGINX，可在 `/etc/letsencrypt/renewal-hooks/post/` 创建脚本：
  ```bash
  #!/bin/bash
  /opt/gitlab/bin/gitlab-ctl hup nginx
  ```
- 赋予执行权限：`sudo chmod +x /etc/letsencrypt/renewal-hooks/post/gitlab-reload.sh`。

## 配置验证

- `sudo gitlab-ctl status`：确认 GitLab 服务健康。
- `curl -I https://gitlab.example.com`：检查状态码与证书链是否正确。
- 浏览器访问 GitLab，确保地址栏显示受信任的 HTTPS。

## 常见问题

- **80 端口被占用**：无论使用哪种方案，HTTP 验证均依赖 80 端口；若被占用可考虑临时停用服务或改用 DNS 验证。
- **反向代理阻断验证**：确保 ACME 验证请求（`/.well-known/acme-challenge/`）能够透传到 GitLab。
- **证书路径权限不足**：自定义证书目录时需保证 `gitlab-www` 用户可读；使用内置方案时 GitLab 会自动处理权限。
- **签发失败或未生效**：确认执行 `gitlab-ctl reconfigure`，必要时查看 `gitlab-ctl tail nginx` 与 `gitlab-ctl tail letsencrypt` 日志进行排查。

## 相关阅读

- [Git 使用指南](./git-guide.md)：汇总 Git 常用命令、冲突处理与推送失败排查方法。