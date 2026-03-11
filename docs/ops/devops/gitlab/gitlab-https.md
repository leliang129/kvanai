---
title: GitLab HTTPS 配置
sidebar_position: 6
---

# GitLab HTTPS 配置


## 3.9.1 为什么启用 HTTPS

如果 GitLab 部署在不安全网络中，建议启用 HTTPS，避免凭据和代码传输被中间人窃听。

注意：

- 生产环境建议使用权威 CA 证书。
- 若使用自签名证书，需要在客户端导入信任，否则后续 `git clone`/`git pull` 可能失败。

官方参考：

- [GitLab Omnibus HTTPS 配置](https://docs.gitlab.com/omnibus/settings/nginx.html#enable-https)

## 3.9.2 证书生成示例（自签名）

```bash
mkdir -p /etc/gitlab/ssl && cd /etc/gitlab/ssl
openssl genrsa -out gitlab.example.com.key 2048
openssl req -days 3650 -x509 -sha256 -nodes -newkey rsa:2048 \
  -subj "/C=CN/ST=beijing/L=beijing/O=example/CN=gitlab.example.com" \
  -keyout gitlab.example.com.key \
  -out gitlab.example.com.crt
```

说明：

- `CN` 必须与实际访问域名一致（如 `gitlab.example.com`）。

## 3.9.3 GitLab 配置示例

编辑配置文件：

```bash
vim /etc/gitlab/gitlab.rb
```

关键配置项（4 个必选项）：

```ruby
external_url "https://gitlab.example.com"                 # 必选
nginx['redirect_http_to_https'] = true                    # 必选
nginx['ssl_certificate'] = "/etc/gitlab/ssl/gitlab.example.com.crt"    # 必选
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/gitlab.example.com.key" # 必选
```

可选配置项：

```ruby
nginx['enable'] = true
nginx['client_max_body_size'] = '1000m'
nginx['redirect_http_to_https_port'] = 80
nginx['ssl_ciphers'] = "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
nginx['ssl_prefer_server_ciphers'] = "on"
nginx['ssl_protocols'] = "TLSv1.2"
nginx['ssl_session_cache'] = "shared:SSL:10m"
nginx['ssl_session_timeout'] = "1440m"
```

应用配置：

```bash
gitlab-ctl reconfigure
gitlab-ctl restart
gitlab-ctl status
```

效果：

- 访问原 `http://` 地址会自动跳转到 `https://`。

## 3.9.4 自签名证书信任（客户端）

若出现证书校验失败，可在 Git 客户端主机导入服务器证书。

```bash
# 从 GitLab 服务器复制证书
scp gitlab-server:/etc/gitlab/ssl/gitlab.example.com.crt .

# Ubuntu / Debian
cat gitlab.example.com.crt >> /etc/ssl/certs/ca-certificates.crt

# RHEL / Rocky / CentOS
cat gitlab.example.com.crt >> /etc/pki/tls/certs/ca-bundle.crt
```
