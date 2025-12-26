---
title: Dockerfile镜像构建
sidebar_position: 6
---

本文聚焦 Dockerfile 的镜像构建实践：构建原理、缓存命中、镜像瘦身、多阶段构建、BuildKit/Buildx、高质量标签与可追溯性、安全基线，以及 CI/CD 中的常见用法与排障思路。

## 1. 构建原理速览：层（layer）与缓存（cache）

- Dockerfile 大多数指令（`RUN/COPY/ADD` 等）会生成镜像层。
- **缓存命中关键**：上一层完全一致（指令 + 上下文文件内容）才会复用。
- **构建上下文（context）**：`docker build .` 会把当前目录作为上下文打包发送给 daemon；上下文越大越慢。

快速观察镜像层：

```bash
docker history <image:tag>
docker image inspect <image:tag> --format '{{.RootFS.Layers}}'
```

## 2. docker build 常用参数

```bash
# 基本构建
docker build -t demo:1.0 .

# 指定 Dockerfile / 构建目录
docker build -f Dockerfile.prod -t demo:prod ./app

# 关闭缓存 / 输出更详细日志
docker build --no-cache --progress=plain -t demo:debug .

# 传入构建参数（ARG）
docker build --build-arg APP_VERSION=1.0.3 -t demo:1.0.3 .
```

建议默认开启 BuildKit（现代 Docker 通常已默认开启）：

```bash
DOCKER_BUILDKIT=1 docker build -t demo:latest .
```

## 3. `.dockerignore`：把“无关文件”挡在上下文之外

构建慢、缓存不稳定，80% 的原因是上下文太大/变动太频繁。

示例（按语言增删）：

```gitignore
.git
.DS_Store
node_modules
dist
build
target
__pycache__/
.pytest_cache/
.venv/
.idea/
.vscode/
*.log
```

## 4. Dockerfile 结构建议：先“稳定”，后“变化”

核心原则：**把变化频率低的步骤放前面**，提高缓存命中。

以 Node 为例：

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app

# 先复制依赖清单（变动相对少）
COPY package.json package-lock.json ./
RUN npm ci

# 再复制业务代码（变动频繁）
COPY . .
RUN npm run build
```

以 Python 为例（建议配合 `requirements.txt` 或 lockfile）：

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

## 5. 多阶段构建（multi-stage）：瘦身与安全的最佳实践

多阶段把“编译环境”和“运行环境”拆开：运行镜像只保留可执行产物与最小依赖。

Go 示例（静态编译 + distroless）：

```dockerfile
# syntax=docker/dockerfile:1.7
FROM golang:1.22 AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o app ./cmd/server

FROM gcr.io/distroless/static-debian12
WORKDIR /app
COPY --from=builder /src/app /app/app
USER nonroot
ENTRYPOINT ["/app/app"]
```

选择运行时镜像的小建议：

| 运行时镜像 | 优点 | 注意点 |
| --- | --- | --- |
| `alpine` | 体积小 | `musl` 兼容性（某些依赖/二进制需要 `glibc`） |
| `slim` | 兼容性好 | 体积比 alpine 大 |
| `distroless` | 攻击面小 | 默认无 shell，排障方式不同（建议额外挂载 debug 镜像/sidecar） |
| `scratch` | 极致最小 | 仅适合静态二进制 + 需要自己带证书/时区等 |

## 6. BuildKit 高级用法：缓存挂载与 secret（避免泄露）

### 6.1 `--mount=type=cache`：提速构建

以 apt 缓存为例（减少重复下载）：

```dockerfile
# syntax=docker/dockerfile:1.7
FROM ubuntu:22.04
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y curl ca-certificates && rm -rf /var/lib/apt/lists/*
```

以 Go module 缓存为例：

```dockerfile
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o app ./cmd/server
```

### 6.2 `--mount=type=secret`：构建期使用凭证但不写进镜像

不要在 Dockerfile 里写 token（也不要用 `ARG TOKEN=...` 这种方式“假装安全”）。

```dockerfile
# syntax=docker/dockerfile:1.7
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci
```

构建命令：

```bash
docker build --secret id=npmrc,src=$HOME/.npmrc -t demo:latest .
```

## 7. ENTRYPOINT vs CMD：启动方式要可读、可覆盖

- `ENTRYPOINT`：固定主程序（更像“这个镜像就是干这个”）。
- `CMD`：默认参数（运行时可被覆盖）。

推荐写法：

```dockerfile
ENTRYPOINT ["./app"]
CMD ["--help"]
```

## 8. 镜像可追溯：标签（tag）与 LABEL（元信息）

### 8.1 Tag 策略（建议）

- 不使用 `latest` 作为生产部署依据。
- 推荐：`<app>:<semver>-<gitsha>` 或 `<date>-<gitsha>`。

```bash
docker tag app:build harbor.example.com/ops/app:1.2.3-3a9c2d1
docker push harbor.example.com/ops/app:1.2.3-3a9c2d1
```

### 8.2 LABEL（写进镜像，便于审计）

```dockerfile
ARG VCS_REF
ARG BUILD_DATE
LABEL org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.source="https://git.example.com/ops/app"
```

构建时注入：

```bash
docker build \
  --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -t app:build .
```

## 9. 多架构构建与推送：Buildx

适合同时支持 `amd64/arm64`（如 Mac M 系列开发、ARM 服务器）：

```bash
docker buildx create --use --name opsbuilder || true
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t harbor.example.com/ops/app:1.2.3 \
  --push .
```

常见坑：

- `--load` 只能加载单架构到本地；多架构通常用 `--push`。
- 依赖二进制（如 `wkhtmltopdf`）要确认目标架构是否存在对应包。

## 10. 安全基线：减少攻击面 + 早扫描

建议在 Dockerfile 里落地的最小安全基线：

- 非 root：`USER nonroot`（或创建专用用户）
- 尽量只读：运行时配合 `--read-only` + `tmpfs`
- 最小能力：运行时 `--cap-drop ALL`，按需加回
- 不把密钥写入镜像：用 secret mount 或运行时注入（K8s Secret/Vault）

镜像扫描建议集成到 CI：

```bash
# 例：trivy（按公司标准调整严重级别）
trivy image --severity HIGH,CRITICAL --exit-code 1 harbor.example.com/ops/app:1.2.3
```

## 11. 常见构建问题排查

| 现象 | 常见原因 | 处理建议 |
| --- | --- | --- |
| `Unexpected EOF` / 下载慢 | 网络不稳定 / 源慢 | 走企业代理/镜像源；开启缓存；使用更稳定的 base image |
| 缓存总不命中 | `.dockerignore` 缺失；`COPY . .` 太早 | 先复制依赖清单，再复制业务代码；精简上下文 |
| 镜像很大 | 单阶段把编译工具带进运行镜像 | 多阶段；清理 apt 缓存；选择更小运行时 |
| 容器启动报权限 | `USER` 后没有写目录权限 | 创建/授权工作目录；把可写目录挂载 volume 或 tmpfs |
| 需要看构建细节 | 输出被折叠 | `docker build --progress=plain ...` |

## 12. 延伸阅读

- 镜像/容器生命周期与常用命令：[Docker 容器与镜像管理](./docker-image)
- 数据目录与日志治理：[Docker 数据目录管理](./docker-data)
- 网络管理与排障：[Docker 网络管理](./docker-network)
