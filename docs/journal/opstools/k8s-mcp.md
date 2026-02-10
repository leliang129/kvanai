---
title: kubernetes mcp server服务介绍&搭建
sidebar_position: 6
---

# 简要介绍

Kubernetes MCP Server 是一个基于 **MCP（Model Context Protocol）** 的 Kubernetes/OpenShift 服务端，实现为 **Go 原生二进制**，直接调用 Kubernetes API（不是封装 `kubectl`）。它提供通用资源 CRUD、Pod/日志/exec、Helm 等工具集，支持多集群、只读/禁写模式，并且可作为本地二进制或容器运行。

# 部署准备（可选但推荐）

- 准备可用的 `kubeconfig`（推荐创建只读 ServiceAccount，并生成独立 kubeconfig）。
- 官方示例可参考仓库文档：`docs/GETTING_STARTED_KUBERNETES.md`。

# 二进制部署（本地运行）

## 1) 下载最新版本二进制
到 releases 页面下载与你系统匹配的文件，名称类似：
- `kubernetes-mcp-server-linux-amd64`
- `kubernetes-mcp-server-darwin-arm64`
- `kubernetes-mcp-server-windows-amd64.exe`

示例（Linux/macOS）：
```bash
VERSION="v0.0.57"  # 替换为 releases 最新版本
OS="linux"         # linux / darwin
ARCH="amd64"       # amd64 / arm64

curl -L -o kubernetes-mcp-server \
  "https://github.com/containers/kubernetes-mcp-server/releases/download/${VERSION}/kubernetes-mcp-server-${OS}-${ARCH}"

chmod +x kubernetes-mcp-server
```

### 自动获取最新版本（推荐）
```bash
OS="linux"   # linux / darwin
ARCH="amd64" # amd64 / arm64

VERSION="$(curl -s https://api.github.com/repos/containers/kubernetes-mcp-server/releases/latest \
  | sed -n 's/.*"tag_name": "\(v[^"]*\)".*/\1/p')"

curl -L -o kubernetes-mcp-server \
  "https://github.com/containers/kubernetes-mcp-server/releases/download/${VERSION}/kubernetes-mcp-server-${OS}-${ARCH}"

chmod +x kubernetes-mcp-server
```

## 2) 运行
- **标准 MCP（stdio）模式**：
```bash
./kubernetes-mcp-server --kubeconfig "$HOME/.kube/mcp-viewer.kubeconfig"
```

- **HTTP/SSE 模式**（对外提供 `/mcp` 与 `/sse`）：
```bash
./kubernetes-mcp-server --port 8080 \
  --kubeconfig "$HOME/.kube/mcp-viewer.kubeconfig" \
  --read-only
```

> 常用参数：`--kubeconfig`、`--read-only`、`--disable-destructive`、`--stateless`、`--port`。

# Docker 部署

## 1) 使用官方镜像
官方镜像来自 Quay（chart 默认值）：
- `quay.io/containers/kubernetes_mcp_server:latest`

## 2) 运行容器
容器默认入口已带 `--port 8080`（HTTP/SSE 模式）。挂载 kubeconfig 后直接运行：
```bash
docker run --rm -p 8080:8080 \
  -v $HOME/.kube/mcp-viewer.kubeconfig:/tmp/kubeconfig:ro \
  quay.io/containers/kubernetes_mcp_server:latest \
  --kubeconfig /tmp/kubeconfig \
  --read-only
```

## 3) 验证
```bash
curl http://localhost:8080/healthz
```

> 若需要在 K8s 内长期运行，可考虑使用官方 Helm Chart：
> `oci://ghcr.io/containers/charts/kubernetes-mcp-server`（见 chart README）。

# MCP 客户端配置示例

## Claude Desktop
编辑 `claude_desktop_config.json`：
```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "./kubernetes-mcp-server",
      "args": ["--kubeconfig", "/path/to/mcp-viewer.kubeconfig", "--read-only"]
    }
  }
}
```

## VS Code / VS Code Insiders
```bash
# VS Code
code --add-mcp '{"name":"kubernetes","command":"./kubernetes-mcp-server","args":["--kubeconfig","/path/to/mcp-viewer.kubeconfig","--read-only"]}'

# VS Code Insiders
code-insiders --add-mcp '{"name":"kubernetes","command":"./kubernetes-mcp-server","args":["--kubeconfig","/path/to/mcp-viewer.kubeconfig","--read-only"]}'
```

## Cursor
编辑 `mcp.json`：
```json
{
  "mcpServers": {
    "kubernetes-mcp-server": {
      "command": "./kubernetes-mcp-server",
      "args": ["--kubeconfig", "/path/to/mcp-viewer.kubeconfig", "--read-only"]
    }
  }
}
```
