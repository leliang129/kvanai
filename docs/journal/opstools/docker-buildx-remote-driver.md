---
title: docker buildx 远程驱动器安装
sidebar_position: 7
---

# Docker Buildx 远程驱动器安装（Remote Driver）

本文提供一套 **可直接 curl 执行** 的通用脚本流程，完成：
1) 生成 TLS 证书（官方 buildkit create-certs bake）  
2) 启动远端 buildkitd 容器  
3) 在本机创建 / 追加 buildx 远程节点  

> 脚本将发布在 `docs.kvanai.com`，本文直接用 `curl | bash` 调用，无需下载。

## 前置条件

- 远端机器已安装 Docker（运行 buildkitd）
- 本机已安装 Docker & buildx（创建 builder）
- 远端 1234 端口可访问（或按需放行）

---

## 1. 远端生成 TLS 证书（在 buildkitd 机器执行）

> SAN 请包含 **远端 IP**（例如 192.168.0.130）和可用的 DNS/主机名。

```bash
SAN_LIST="192.168.0.130 buildkitd localhost 127.0.0.1" BASE_DIR=/root/.certs \
  curl -fsSL https://docs.kvanai.com/static/scripts/gen-buildkit-certs.sh | bash
```

生成后目录结构：
```
/root/.certs/
├── daemon/   # 服务器证书 (ca.pem/cert.pem/key.pem)
└── client/   # 客户端证书 (ca.pem/cert.pem/key.pem)
```

---

## 2. 远端启动 buildkitd（在 buildkitd 机器执行）

> 依赖 `/root/.certs/daemon` 中的证书。

```bash
CERT_DIR=/root/.certs/daemon \
  curl -fsSL https://docs.kvanai.com/static/scripts/install-buildkitd.sh | bash
```

默认监听 `tcp://0.0.0.0:1234`。

---

## 3. 拷贝 client 证书到本机

在本机执行（示例）：
```bash
scp -r root@192.168.0.130:/root/.certs/client ./client
```

---

## 4. 本机创建 buildx 远程 builder

```bash
CLIENT_CERT_DIR=./client SERVER_NAME=192.168.0.130 \
  curl -fsSL https://docs.kvanai.com/static/scripts/builder-append-node.sh | bash -s -- \
  create multi-remote tcp://192.168.0.130:1234
```

若要追加节点（多机构建）：
```bash
CLIENT_CERT_DIR=./client SERVER_NAME=192.168.0.130 \
  curl -fsSL https://docs.kvanai.com/static/scripts/builder-append-node.sh | bash -s -- \
  append multi-remote tcp://192.168.0.130:1234
```

---

## 常见问题

### 1) `context deadline exceeded`
通常是 TLS 校验失败（SAN 不包含远端 IP / servername 不匹配），或端口不可达。

**检查要点：**
- `SAN_LIST` 中必须包含远端 IP
- `SERVER_NAME` 必须与证书 CN/SAN 匹配
- 端口 1234 是否可达

### 2) buildkitd 容器未正常启动
查看日志：
```bash
docker logs buildkitd --tail 200
```

---

## 脚本列表（线上地址）

- 生成证书：`https://docs.kvanai.com/static/scripts/gen-buildkit-certs.sh`
- 启动 buildkitd：`https://docs.kvanai.com/static/scripts/install-buildkitd.sh`
- 创建 / 追加 builder：`https://docs.kvanai.com/static/scripts/builder-append-node.sh`
