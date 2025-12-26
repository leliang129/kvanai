---
title: Docker Compose容器编排
sidebar_position: 8
---

Docker Compose 用来在**单机/开发/测试/小规模生产**场景下，以声明式方式编排多容器应用（服务、网络、存储、环境变量、依赖关系）。它非常适合：

- 本地快速拉起「应用 + 依赖」（DB/Redis/MQ）进行联调
- CI 中跑集成测试（临时环境、用完即删）
- 单机交付（配合 systemd/监控/备份）

> 说明：现代 Docker 推荐使用 v2 插件命令 `docker compose`（中间有空格），旧版独立二进制是 `docker-compose`。

## 1. 快速开始（最小可用）

新建 `compose.yaml`（推荐文件名，等价于 `docker-compose.yml`）：

```yaml
services:
  nginx:
    image: nginx:1.25-alpine
    ports:
      - "8080:80"
```

启动与停止：

```bash
docker compose up -d
docker compose ps
docker compose logs -f
docker compose down
```

## 2. 常用命令速查（运维视角）

```bash
# 查看当前目录下的 compose 项目
docker compose ls

# 启动服务（前台/后台）
docker compose up          # 前台运行，查看日志
docker compose up -d       # 后台运行（detached）
docker compose up -d --build  # 强制重新构建镜像后启动

# 查看状态、查看日志、进入容器
docker compose ps          # 查看服务状态
docker compose ps -a       # 查看所有容器（包括已停止的）
docker compose logs -f --tail=200 <service>  # 实时查看服务日志
docker compose exec <service> sh             # 进入运行中的容器

# 拉取/构建/推送（适合配合 Harbor）
docker compose pull        # 拉取最新镜像
docker compose build       # 构建镜像
docker compose build --no-cache  # 清除缓存重新构建
docker compose push        # 推送镜像到仓库

# 停止和删除
docker compose stop        # 停止服务（不删除容器）
docker compose down        # 停止并删除容器、网络（保留卷）
docker compose down -v     # 停止并删除容器、网络、卷

# 重启服务
docker compose restart <service>  # 重启特定服务
docker compose restart            # 重启所有服务

# 打印最终生效配置（排障神器）
docker compose config      # 查看合并后的完整配置
docker compose config --services  # 列出所有服务名称
```

## 3. 文件组织与优先级（多环境必备）

### 3.1 默认文件

- `compose.yaml`：主配置（建议提交到仓库）
- `compose.override.yaml`：本地覆盖（默认会自动合并，适合 dev 环境）
- `.env`：变量文件（会自动读取，用于变量替换）

### 3.2 多文件合并（dev/staging/prod）

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

建议：

- `compose.yaml` 放通用定义
- `compose.prod.yaml` 覆盖端口暴露、日志、资源、存储、镜像 tag
- 避免把密码写死在 YAML，使用 `.env`/`--env-file` 或 Secret（见下文）

## 4. 变量与配置注入：`.env` / `environment` / `env_file`

> **核心区别**：`.env` 是给 Compose 做变量替换的；`environment` 和 `env_file` 是给容器注入环境变量的。

### 4.1 `.env`（用于 Compose 变量替换）

`.env` 示例：

```bash
APP_IMAGE=harbor.example.com/ops/app
APP_TAG=1.2.3-3a9c2d1
APP_PORT=8080
```

`compose.yaml` 使用：

```yaml
services:
  app:
    image: ${APP_IMAGE}:${APP_TAG}
    ports:
      - "${APP_PORT}:8080"
```

### 4.2 `environment`（写进容器环境变量）

```yaml
services:
  app:
    environment:
      TZ: Asia/Shanghai
      LOG_LEVEL: info
```

### 4.3 `env_file`（把文件内容注入容器环境变量）

```yaml
services:
  app:
    env_file:
      - ./env/app.env
```

> 注意：`.env` 是给 Compose 做变量替换；`env_file` 是给容器注入环境变量，两者用途不同。

## 5. 网络：服务发现、端口暴露、排障点

默认情况下 Compose 会创建一个项目级 network，服务之间可以用**服务名**互相访问：

```yaml
services:
  api:
    image: example/api:1.0
  db:
    image: postgres:16-alpine
```

在 `api` 容器里可通过 `db:5432` 访问数据库（无需手写 IP）。

关键点：

- `ports`：把容器端口映射到宿主机（对外暴露）
- `expose`：只在容器网络内暴露（不映射到宿主机）
- 遇到端口冲突：`bind: address already in use`，改宿主机端口或停掉占用进程

更多网络细节可参考：[Docker网络管理](./docker-network.md)

## 6. 存储：volume vs bind mount

两类常用方式：

- **Named Volume**：由 Docker 管理（推荐用于 DB 数据）
- **Bind Mount**：绑定宿主机目录（适合配置文件/日志目录/代码挂载）

示例：

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
  nginx:
    image: nginx:1.25-alpine
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro

volumes:
  pgdata: {}
```

卷数据目录、迁移与日志治理可参考：[Docker数据目录管理](./docker-data.md)

## 7. 健康检查与依赖顺序（让启动更“可控”）

### 7.1 healthcheck

```yaml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 20
```

### 7.2 depends_on（注意：不等于"服务已就绪"）

`depends_on` 只控制**启动顺序**，不保证服务已就绪。有三种方式配合使用：

**方式一：结合 healthcheck**（推荐）

```yaml
services:
  api:
    image: example/api:1.0
    depends_on:
      db:
        condition: service_healthy
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 20
```

**��式二：应用层重试**

让应用自身具备连接重试能力（数据库连接池、指数退避等）。

**方式三：使用 wait-for 脚本**

在容器启动命令中加入等待逻辑（如 `wait-for-it.sh`）。

## 8. 重启策略、日志与资源限制（生产落地三件套）

### 8.1 restart（重启策略）

```yaml
services:
  api:
    restart: unless-stopped  # 推荐生产环境使用
```

常用选项：
- `no`：默认值，不自动重启
- `always`：总是重启（即使手动停止）
- `unless-stopped`：除非手动停止，否则总是重启（**推荐生产环境**）
- `on-failure[:max-retries]`：仅在容器异常退出时重启

### 8.2 日志（建议配合 Docker 日志滚动）

```yaml
services:
  api:
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "5"
```

> 也可以在 daemon 级别统一配置（见 [Docker数据目录管理](./docker-data.md) 的日志治理部分）。

### 8.3 资源限制（本地开发 vs 生产环境）

**本地开发推荐**（简单直接）：

```yaml
services:
  api:
    mem_limit: 512m      # 内存硬限制
    mem_reservation: 256m # 内存软限制（保证最小分配）
    cpus: 1.0            # CPU 核心数限制
```

**生产环境推荐**（Swarm/K8s 兼容）：

```yaml
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

> **注意**：`deploy:` 在本地 `docker compose` 中需要添加 `--compatibility` 标志才能生效。本地开发直接使用 `mem_limit` 和 `cpus` 更简单。

## 9. profiles：可选组件（观测/调试/本地依赖）

把“只在某些环境启用”的服务放到 profile 里：

```yaml
services:
  prometheus:
    image: prom/prometheus:v2.54.1
    profiles: ["obs"]
```

启用：

```bash
docker compose --profile obs up -d
```

## 10. 一个更贴近运维的示例（app + db + redis）

`compose.yaml` 示例（包含常见运维配置）：

```yaml
services:
  app:
    image: ${APP_IMAGE:-harbor.example.com/ops/app}:${APP_TAG:-dev}
    ports:
      - "${APP_PORT:-8080}:8080"
    environment:
      TZ: Asia/Shanghai
      DATABASE_URL: postgres://postgres:${PG_PASSWORD:-postgres}@db:5432/app?sslmode=disable
      REDIS_ADDR: redis:6379
    depends_on:
      db:
        condition: service_healthy  # 等待 DB 健康检查通过
      redis:
        condition: service_started
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "3"
    mem_limit: 1g
    cpus: 2.0

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: ${PG_PASSWORD:-postgres}
      POSTGRES_DB: app
      POSTGRES_INITDB_ARGS: "-E UTF8 --locale=C"  # 性能优化
    volumes:
      - pgdata:/var/lib/postgresql/data
      # 可选：挂载初始化脚本
      # - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 20
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"

  redis:
    image: redis:7-alpine
    command: [
      "redis-server",
      "--appendonly", "yes",        # 启用 AOF 持久化
      "--maxmemory", "256mb",       # 内存限制
      "--maxmemory-policy", "allkeys-lru"  # 内存满时的淘汰策略
    ]
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"

volumes:
  pgdata:
    driver: local
  redisdata:
    driver: local
```

**配套的 `.env` 文件**：

```bash
# 镜像配置
APP_IMAGE=harbor.example.com/ops/app
APP_TAG=1.2.3
APP_PORT=8080

# 数据库配置
PG_PASSWORD=your_secure_password_here

# 注意：生产环境应使用 Docker secrets 或外部密钥管理系统
```

## 11. 与 Harbor/CI 联动（推送与拉取）

- 本地构建与镜像优化：[`docker-build-image.md`](./docker-build-image.md)
- 私有仓库与权限/Robot/TLS：[`docker-harbor.md`](./docker-harbor.md)

常见 CI 流程（简化版）：

1. 构建镜像 → 打 tag（带 gitsha） → push 到 Harbor
2. 目标环境 `docker compose pull` → `docker compose up -d`

## 12. 常见问题排查（Compose 现场速查）

### 12.1 配置不符合预期

**问题**：不确定最终生效的配置是什么（尤其是多文件合并时）

```bash
# 查看合并后的最终配置（排障神器）
docker compose config

# 检查特定服务的配置
docker compose config --services
docker compose config app
```

### 12.2 "同名容器/网络/卷"残留

**问题**：`Error: Conflict. The container name "/xxx" is already in use`

```bash
# 停止并删除所有容器、网络（保留卷）
docker compose down

# 停止并删除所有容器、网络和卷
docker compose down -v

# 删除孤立容器（不在当前 compose.yaml 中定义的）
docker compose down --remove-orphans

# 手动清理特定项目的资源
docker ps -a | grep <project_name>
docker network ls | grep <project_name>
docker volume ls | grep <project_name>
```

### 12.3 容器启动后立刻退出

**问题**：容器状态显示 `Exited (1)` 或 `Restarting`

```bash
# 查看容器状态和退出码
docker compose ps

# 查看容器日志（最近 200 行并实时跟踪）
docker compose logs -f --tail=200 <service>

# 查看容器详细信息（包括退出原因）
docker compose ps -a
docker inspect <container_name>

# 常见原因：
# 1. 启动命令错误
# 2. 依赖服务未就绪（需要 healthcheck + depends_on）
# 3. 环境变量缺失或配置错误
# 4. 权限问题（文件挂载、端口绑定）
```

### 12.4 端口映射冲突

**问题**：`Error: bind: address already in use`

```bash
# macOS/Linux：查看端口占用
lsof -iTCP -sTCP:LISTEN -nP | grep ":8080"
netstat -tunlp | grep 8080

# 解决方案：
# 1. 改变宿主机端口映射
# 2. 停止占用进程
# 3. 使用不同的项目名称隔离
```

### 12.5 网络连接问题

**问题**：服务之间无法通信

```bash
# 检查网络配置
docker compose config | grep -A 10 networks
docker network ls
docker network inspect <network_name>

# 进入容器测试连通性
docker compose exec app sh
# 在容器内：
ping db
nc -zv db 5432
curl http://api:8080/health

# 常见原因：
# 1. 服务名拼写错误
# 2. 服务在不同网络中
# 3. 端口号错误（容器内端口 vs 宿主机端口）
```

### 12.6 卷挂载权限问题

**问题**：`Permission denied` 错误

```bash
# 检查卷挂载配置
docker compose config | grep -A 5 volumes

# 检查卷的实际位置和权限
docker volume inspect <volume_name>
ls -la /path/to/bind/mount

# 解决方案：
# 1. 调整宿主机文件权限
# 2. 在 Dockerfile 中设置正确的 USER
# 3. 使用 :ro （只读）避免写入权限问题
# 4. Named volume 通常比 bind mount 权限问题少
```

### 12.7 环境变量未生效

**问题**：容器内环境变量与预期不符

```bash
# 检查最终的环境变量配置
docker compose config | grep -A 20 environment

# 进入容器查看实际环境变量
docker compose exec app env | grep -i db

# 注意事项：
# 1. .env 文件只用于变量替换，不会自动注入容器
# 2. 使用 env_file 或 environment 注入容器环境变量
# 3. 环境变量优先级：shell > .env > compose.yaml
```

---

## 13. 生产环境使用建议

如果你准备把 Compose 用在生产单机交付，需要注意以下几点：

### 运维能力建设

1. **进程管理**：配置 systemd 管理 Docker Compose 服务
2. **日志采集**：集成 ELK/Loki 等日志系统
3. **监控告警**：接入 Prometheus + Grafana
4. **备份策略**：定期备份 Named Volumes 和配置文件
5. **升级回滚**：建立完整的 SOP 文档

### 安全加固

1. **密钥管理**：使用 Docker Secrets 或外部密钥管理系统（Vault）
2. **网络隔离**：合理使用自定义网络分隔服务
3. **资源限制**：为所有服务设置合理的 CPU 和内存限制
4. **镜像安全**：定期扫描镜像漏洞，使用私有镜像仓库

### 迁移路径

Docker Compose 是学习容器编排的绝佳起点，也适合中小规模应用。当业务增长需要：

- **多机编排**：考虑迁移到 Docker Swarm（配置相似）
- **云原生**：迁移到 Kubernetes + Helm（学习曲线陡峭，但生态丰富）
- **托管服务**：使用云厂商的容器服务（AWS ECS、阿里云 ACK 等）

**关键原则**：不要把"能跑"误当成"可运维"。完整的运维体系建设比工具选择更重要。  
