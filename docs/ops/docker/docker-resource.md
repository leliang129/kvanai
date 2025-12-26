---
title: Docker资源限制与管理
sidebar_position: 9
---

Docker 的资源限制本质上是对 Linux **cgroup**（Control Groups）的封装。合理的资源限制能显著降低"单个容器拖垮整机"的风险，同时让问题更容易定位和解决。

本文从运维实战角度介绍：CPU/内存/磁盘 IO/进程数等资源的限制方式、监控方法、排障思路，以及生产环境最佳实践。

> **核心理念**：资源限制不是"卡住应用"，而是"建立边界、及早发现问题、保护系统稳定性"。

## 1. 为什么需要资源限制

### 1.1 典型问题场景

**没有资源限制的风险**：

1. **内存泄漏拖垮整机**：单个容器内存泄漏导致宿主机 OOM，影响其他容器
2. **CPU 抢占**：某个容器 CPU 使用率 100%，其他服务响应变慢
3. **Fork 炸弹**：异常进程疯狂创建子进程，耗尽系统资源
4. **磁盘 IO 打满**：大批量写日志或数据，影响其他服务的磁盘读写
5. **文件句柄耗尽**：高并发服务打开大量连接，超过系统限制

### 1.2 资源限制的目标

- ✅ **故障隔离**：一个容器出问题，不影响其他容器和宿主机
- ✅ **容量规划**：明确单机能跑多少容器，避免 overcommit
- ✅ **问题定位**：有边界才能快速定位是资源不足还是业务问题
- ✅ **成本优化**：合理利用资源，避免浪费

## 2. 快速开始：最常用的资源限制

### 2.1 启动容器时指定资源限制

```bash
docker run -d \
  --name myapp \
  --cpus=2.0 \              # 限制 CPU 核心数
  --memory=1g \             # 限制内存上限
  --memory-reservation=512m \  # 内存软限制
  --pids-limit=200 \        # 限制最大进程数
  --restart=unless-stopped \
  myapp:latest
```

### 2.2 在 Docker Compose 中配置（推荐）

```yaml
services:
  app:
    image: myapp:latest
    # 资源限制（本地开发常用）
    mem_limit: 1g
    mem_reservation: 512m
    cpus: 2.0
    pids_limit: 200

    # ulimit 限制
    ulimits:
      nofile:
        soft: 65535
        hard: 65535
      nproc:
        soft: 4096
        hard: 4096

    restart: unless-stopped
```

### 2.3 查看当前资源限制

```bash
# 查看容器资源使用情况（实时）
docker stats myapp

# 查看容器资源限制配置
docker inspect myapp --format='{{json .HostConfig}}' | jq '.Memory, .NanoCpus, .PidsLimit'

# 查看容器是否被 OOM Kill
docker inspect myapp --format='OOMKilled: {{.State.OOMKilled}}, ExitCode: {{.State.ExitCode}}'
```

## 3. CPU 资源限制详解

### 3.1 限制 CPU 核心数：`--cpus`（推荐）

**最常用的方式**，简单直观：

```bash
# 限制容器最多使用 1.5 个 CPU 核心
docker run -d --name api --cpus=1.5 myapi:latest

# Compose 写法
services:
  api:
    cpus: 1.5
```

**含义**：容器可以使用最多 1.5 个 CPU 核心的计算时间。在多核系统上，可以跨核使用，但总使用量不超过 1.5 核。

**适用场景**：绝大多数场景，这是最简单有效的限制方式。

### 3.2 精确控制：`--cpu-quota` 和 `--cpu-period`

更底层的控制方式，适合需要精确控制 CPU 时间片的场景：

```bash
# 在每 100ms 内，容器最多使用 50ms 的 CPU 时间（相当于 0.5 核心）
docker run -d --name job \
  --cpu-period=100000 \
  --cpu-quota=50000 \
  myjob:latest
```

**换算关系**：
- `--cpus=1.0` ≈ `--cpu-quota=100000 --cpu-period=100000`
- `--cpus=0.5` ≈ `--cpu-quota=50000 --cpu-period=100000`

**适用场景**：需要精确控制 CPU 配额的批处理任务、限速任务。

### 3.3 绑定 CPU 核心：`--cpuset-cpus`

将容器绑定到特定的 CPU 核心：

```bash
# 只允许容器使用 2 号和 3 号 CPU 核心
docker run -d --name pin --cpuset-cpus="2,3" mysvc:latest

# 使用范围表示
docker run -d --name pin --cpuset-cpus="0-3" mysvc:latest
```

**适用场景**：
- 对 CPU 缓存敏感的应用（数据库、缓存服务）
- 需要隔离 noisy neighbor 的场景
- NUMA 架构优化

**注意事项**：需要整体规划 CPU 分配，避免核心利用率不均。

### 3.4 CPU 使用权重：`--cpu-shares`（不推荐作为硬限制）

```bash
# 设置 CPU 使用权重为 512（默认 1024）
docker run -d --name lowpri --cpu-shares=512 myapp:latest
```

**特点**：
- 这是**相对权重**，不是硬限制
- 只有在 CPU 竞争时才生效
- 如果其他容器空闲，该容器可以使用更多 CPU

**建议**：生产环境优先使用 `--cpus` 作为硬限制，`--cpu-shares` 用于优先级控制。

## 4. 内存资源限制详解

### 4.1 内存硬限制：`--memory` / `-m`

**最重要的资源限制**：

```bash
# 限制容器最多使用 512MB 内存
docker run -d --name api -m 512m myapi:latest

# 也可以用 GB 单位
docker run -d --name api -m 1g myapi:latest
```

**行为**：
- 容器内存使用超过限制时，Linux OOM Killer 会终止容器内的进程
- 容器会被标记为 `OOMKilled: true`

### 4.2 内存软限制：`--memory-reservation`

**弹性内存管理**：

```bash
# 硬限制 1GB，软限制 512MB
docker run -d --name api \
  -m 1g \
  --memory-reservation 512m \
  myapi:latest
```

**工作原理**：
- 平时允许容器使用最多 1GB 内存
- 当宿主机内存紧张时，内核会优先回收该容器的内存到 512MB 左右
- 软限制必须小于硬限制

**适用场景**：
- 内存使用有波峰波谷的应用
- 允许短时间内存突发，但长期保持在合理水平

### 4.3 Swap 控制：`--memory-swap`

**Swap 策略**（容易踩坑）：

```bash
# 禁用 swap（推荐生产环境）
docker run -d --name api -m 1g --memory-swap 1g myapi:latest

# 允许使用 512MB swap
docker run -d --name api -m 1g --memory-swap 1.5g myapi:latest
```

**关键规则**：
- `--memory-swap` 表示 **内存 + swap 的总量**
- 如果 `-m 1g --memory-swap 1g`，则 swap = 0（禁用 swap）
- 如果 `-m 1g --memory-swap 1.5g`，则 swap = 512MB

**生产建议**：
- 对延迟敏感的服务（API、数据库）：禁用 swap
- 对内存容忍度高的批处理：可以适当使用 swap

### 4.4 OOM 排查（最常见问题）

**判断容器是否被 OOM Kill**：

```bash
# 检查 OOM 状态
docker inspect myapp --format='{{.State.OOMKilled}}'

# 查看退出码（137 通常表示 OOM）
docker inspect myapp --format='{{.State.ExitCode}}'

# 查看宿主机 OOM 日志
dmesg -T | grep -i "out of memory\|oom-killer\|killed process" | tail -20

# 查看 Docker 事件（查找 OOM 事件）
docker events --since 24h --filter 'event=oom'
```

**OOM 常见原因**：

1. **内存限制太小**：实际使用超过 `-m` 设置的值
2. **内存泄漏**：应用长时间运行内存持续增长
3. **内存峰值**：短时间内存暴涨（如批量处理、大文件加载）
4. **宿主机内存不足**：整体 overcommit，多个容器同时超限

**解决方案**：

```bash
# 1. 增加内存限制（先验证是否确实需要）
docker update --memory 2g myapp

# 2. 查看内存使用趋势
docker stats --no-stream myapp

# 3. 进入容器查看内存使用
docker exec myapp ps aux --sort=-%mem | head -n 10

# 4. 分析应用日志，查找内存泄漏
docker logs --tail 500 myapp | grep -i "memory\|heap\|gc"
```

## 5. 其他资源限制

### 5.1 进程数限制：`--pids-limit`

**防止 Fork 炸弹**：

```bash
# 限制容器最多创建 200 个进程
docker run -d --name api --pids-limit=200 myapi:latest
```

**适用场景**：
- 防止异常 fork 导致系统资源耗尽
- 限制多线程应用的线程数

**注意事项**：
- 太小会导致正常业务无法创建线程/子进程
- 建议根据应用实际需求设置（通常 100-1000）

### 5.2 文件句柄限制：`--ulimit nofile`

**高并发服务必备**：

```bash
# 设置文件句柄限制为 65535
docker run -d --name api \
  --ulimit nofile=65535:65535 \
  myapi:latest
```

**Compose 写法**：

```yaml
services:
  api:
    ulimits:
      nofile:
        soft: 65535
        hard: 65535
      nproc:
        soft: 4096
        hard: 4096
```

**验证配置**：

```bash
# 进入容器查看当前限制
docker exec api sh -c 'ulimit -n'  # 文件句柄
docker exec api sh -c 'ulimit -u'  # 进程数
```

**常见问题**：
- **错误提示**：`Too many open files`
- **原因**：文件句柄不足（连接数、日志文件、临时文件等）
- **解决**：增加 `nofile` 限制

### 5.3 磁盘 IO 限制：`--device-*-bps`

**防止 IO 打满**：

```bash
# 限制对 /dev/sda 的读写速率
docker run -d --name iotest \
  --device-read-bps /dev/sda:20mb \
  --device-write-bps /dev/sda:20mb \
  myapp:latest
```

**适用场景**：
- 单机跑多个 IO 密集型服务
- 防止日志/备份任务影响业务
- 测试环境模拟慢速磁盘

**监控 IO**：

```bash
# 查看磁盘 IO 使用情况
iostat -x 1

# 查看进程 IO 使用
pidstat -d 1

# Docker 容器 IO 统计
docker stats --format "table {{.Container}}\t{{.BlockIO}}"
```

## 6. Docker Compose 完整配置示例

### 6.1 生产级资源配置模板

```yaml
services:
  # API 服务：CPU 和内存敏感
  api:
    image: myapp/api:1.2.3
    mem_limit: 2g              # 内存硬限制
    mem_reservation: 1g        # 内存软限制
    cpus: 2.0                  # CPU 核心数限制
    pids_limit: 500            # 进程数限制

    ulimits:
      nofile:
        soft: 65535
        hard: 65535
      nproc:
        soft: 4096
        hard: 4096

    restart: unless-stopped

    # 健康检查
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "3"

  # 数据库：内存和 IO 敏感
  db:
    image: postgres:16-alpine
    mem_limit: 4g
    mem_reservation: 2g
    cpus: 4.0
    pids_limit: 1000

    # 绑定到特定 CPU 核心（可选，NUMA 优化）
    cpuset_cpus: "0-3"

    volumes:
      - db_data:/var/lib/postgresql/data

    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}

    restart: unless-stopped

    logging:
      driver: json-file
      options:
        max-size: "200m"
        max-file: "5"

  # Redis：内存限制严格
  redis:
    image: redis:7-alpine
    mem_limit: 512m
    cpus: 1.0

    command: [
      "redis-server",
      "--maxmemory", "400mb",      # Redis 自身的内存限制
      "--maxmemory-policy", "allkeys-lru"
    ]

    restart: unless-stopped

  # 批处理任务：IO 和 CPU 限制
  worker:
    image: myapp/worker:1.2.3
    mem_limit: 1g
    cpus: 1.0
    pids_limit: 200

    # 限制磁盘 IO（需要指定具体设备）
    # device_read_bps:
    #   - /dev/sda:20mb
    # device_write_bps:
    #   - /dev/sda:20mb

    restart: unless-stopped

volumes:
  db_data:
    driver: local
```

### 6.2 使用 deploy 语法（Swarm/K8s 兼容）

```yaml
services:
  api:
    image: myapp/api:1.2.3
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
      restart_policy:
        condition: on-failure
        max_attempts: 3
```

**注意**：在本地 `docker compose` 中使用 `deploy` 需要添加 `--compatibility` 标志：

```bash
docker compose --compatibility up -d
```

## 7. 资源监控与告警

### 7.1 实时监控资源使用

```bash
# 持续监控所有容器
docker stats

# 只显示特定容器
docker stats api db redis

# 格式化输出（只显示关键指标）
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# 一次性输出（不持续刷新）
docker stats --no-stream
```

### 7.2 查找资源使用 TOP N

```bash
# CPU 使用率最高的 5 个容器
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}" | sort -k2 -rh | head -6

# 内存使用最高的 5 个容器
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | sort -k2 -rh | head -6
```

### 7.3 检查容器重启和 OOM

```bash
# 查看所有容器的重启次数
for container in $(docker ps -q); do
  name=$(docker inspect --format='{{.Name}}' $container | sed 's|/||')
  restarts=$(docker inspect --format='{{.RestartCount}}' $container)
  oom=$(docker inspect --format='{{.State.OOMKilled}}' $container)
  echo "$name: restarts=$restarts, OOMKilled=$oom"
done | sort -t= -k2 -rn

# 查看最近 24 小时的 OOM 事件
docker events --since 24h --filter 'event=oom' --format '{{.Time}}: {{.Actor.Attributes.name}}'
```

### 7.4 集成 Prometheus 监控（推荐）

配合 [Docker容器监控](./docker-monitor.md) 文档，使用 Prometheus + Grafana：

- **cAdvisor**：采集容器资源指标
- **Prometheus**：存储和查询
- **Grafana**：可视化仪表板
- **Alertmanager**：资源超限告警

**关键告警规则**：

```yaml
# CPU 使用率超过 80%
- alert: ContainerHighCPU
  expr: rate(container_cpu_usage_seconds_total[5m]) * 100 > 80
  for: 5m

# 内存使用率超过 90%
- alert: ContainerHighMemory
  expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 90
  for: 5m

# 容器 OOM Kill
- alert: ContainerOOMKilled
  expr: container_oom_events_total > 0
```

完整监控配置请参考：[Docker容器监控与可观测性](./docker-monitor.md)

## 8. 常见问题排查

### 8.1 容器频繁重启

**现象**：容器不断重启，`docker ps` 显示 `Restarting` 状态

**排查步骤**：

```bash
# 1. 查看容器日志
docker logs --tail 200 myapp

# 2. 检查退出码
docker inspect myapp --format='{{.State.ExitCode}}'
# 退出码含义：
# 137 = 被 SIGKILL 终止（可能是 OOM）
# 139 = 段错误（应用崩溃）
# 1   = 一般错误

# 3. 检查是否 OOM Kill
docker inspect myapp --format='{{.State.OOMKilled}}'

# 4. 查看资源使用历史
docker stats --no-stream myapp

# 5. 检查重启次数
docker inspect myapp --format='{{.RestartCount}}'
```

**常见原因**：
- ✅ 内存不足被 OOM Kill → 增加内存限制或优化应用
- ✅ 应用崩溃 → 查看应用日志，修复 bug
- ✅ 健康检查失败 → 检查健康检查配置是否合理
- ✅ 依赖服务未就绪 → 使用 `depends_on` + `healthcheck`

### 8.2 容器性能下降

**现象**：容器响应变慢、吞吐量下降

**排查步骤**：

```bash
# 1. 检查 CPU 使用是否到达限制
docker stats myapp
# 如果 CPU% 接近限制值（如设置 2 核，使用率接近 200%），说明 CPU 不足

# 2. 检查内存使用
docker stats myapp
# 内存使用接近限制时，可能触发频繁 GC 或 swap

# 3. 检查磁盘 IO
docker stats --format "table {{.Container}}\t{{.BlockIO}}"
iostat -x 1

# 4. 进入容器查看进程状态
docker exec myapp top -b -n 1
docker exec myapp ps aux --sort=-%cpu | head -10

# 5. 查看容器内网络连接
docker exec myapp netstat -an | grep ESTABLISHED | wc -l
```

**常见原因**：
- ✅ CPU 限制太低 → 增加 `--cpus` 值
- ✅ 内存不足 → 增加 `-m` 值或优化应用内存使用
- ✅ 磁盘 IO 瓶颈 → 优化 IO 策略或增加 IO 限制
- ✅ 网络瓶颈 → 检查网络配置和带宽

### 8.3 容器内存使用异常增长

**现象**：内存使用持续增长，最终触发 OOM

**排查步骤**：

```bash
# 1. 持续监控内存使用趋势
watch -n 5 'docker stats --no-stream myapp'

# 2. 查看容器内存详细信息
docker exec myapp cat /proc/meminfo

# 3. 查看进程内存使用排行
docker exec myapp ps aux --sort=-%mem | head -10

# 4. 分析应用日志（查找内存相关问题）
docker logs myapp | grep -i "memory\|heap\|gc\|oom"

# 5. 使用 docker top 查看进程树
docker top myapp
```

**解决方案**：
1. **应用层**：修复内存泄漏、优化数据结构、调整 GC 参数
2. **容器层**：增加内存限制（临时方案）
3. **监控层**：设置内存增长告警，及早发现问题

### 8.4 无法启动更多容器

**现象**：启动新容器失败，提示资源不足

**排查步骤**：

```bash
# 1. 查看宿主机资源使用
free -h
df -h
top

# 2. 查看所有容器资源使用总和
docker stats --no-stream

# 3. 查看 Docker 系统信息
docker system df
docker system df -v

# 4. 检查是否有僵尸容器
docker ps -a --filter "status=exited"
docker ps -a --filter "status=dead"

# 5. 清理无用资源
docker system prune -a
docker volume prune
```

**解决方案**：
- 清理无用容器和镜像
- 调整现有容器资源限制
- 增加宿主机资源
- 使用多机部署（Docker Swarm / K8s）

## 9. 生产环境最佳实践

### 9.1 资源限制设置策略

**第一步：收集基线数据**

```bash
# 运行应用 1-2 周，收集资源使用数据
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" >> /var/log/docker-stats.log
```

使用监控系统（Prometheus + Grafana）记录：
- P50、P95、P99 CPU 使用率
- 平均内存、峰值内存
- 线程数、文件句柄数
- 磁盘 IO 使用情况

**第二步：设置合理限制**

| 资源类型 | 推荐设置 | 说明 |
|---------|---------|------|
| **CPU** | P95 使用量 × 1.2 - 1.5 | 留出 20-50% 余量 |
| **内存** | 峰值使用量 × 1.3 - 1.5 | 留出 30-50% 余量，防止突发 |
| **进程数** | 实际使用 × 2 | 留足够余量，避免正常业务受限 |
| **文件句柄** | 高并发服务：65535 | 数据库、网关、API 等 |
| **磁盘 IO** | 根据业务需求 | 防止单容器影响其他服务 |

**第三步：分级设置**

```yaml
# 核心服务：资源充足
services:
  api:
    mem_limit: 2g
    mem_reservation: 1g
    cpus: 2.0

# 非核心服务：资源适中
  worker:
    mem_limit: 1g
    mem_reservation: 512m
    cpus: 1.0

# 辅助服务：资源受限
  cron:
    mem_limit: 256m
    cpus: 0.5
```

### 9.2 运维 SOP（标准操作流程）

**资源限制变更流程**：

1. **评估阶段**
   - 查看监控数据，分析资源使用趋势
   - 判断是资源不足还是应用问题
   - 制定变更方案（增加/减少限制）

2. **测试阶段**
   - 在测试环境验证新配置
   - 进行压力测试，确认资源够用
   - 验证监控告警是否正常触发

3. **实施阶段**
   - 选择业务低峰期变更
   - 灰度发布（先更新部分容器）
   - 实时监控资源使用和业务指标

4. **验证阶段**
   - 确认容器正常运行
   - 检查错误日志和告警
   - 观察 1-2 天，确保稳定

5. **回滚预案**
   - 保留旧配置文件
   - 出现问题立即回滚
   - 记录变更和问题日志

### 9.3 容量规划

**单机容器数量估算**：

```
可运行容器数 = min(
  宿主机 CPU 核心数 / 单容器 CPU 限制,
  宿主机可用内存 / 单容器内存限制
)
```

**预留资源**：
- 宿主机预留 10-20% CPU 给系统进程
- 宿主机预留 10-20% 内存给系统和缓存
- 考虑峰值场景，避免 overcommit

**示例计算**：

```
宿主机：16 核 64GB 内存
单容器：2 核 4GB 内存

理论容量：
  按 CPU：16 / 2 = 8 个容器
  按内存：64 / 4 = 16 个容器

实际容量（预留 20%）：
  按 CPU：16 * 0.8 / 2 = 6.4 → 6 个容器
  按内存：64 * 0.8 / 4 = 12.8 → 12 个容器

最终：min(6, 12) = 6 个容器
```

### 9.4 监控告警策略

**资源告警阈值**：

| 指标 | 警告 | 严重 | 持续时间 |
|------|------|------|---------|
| CPU 使用率 | > 70% | > 85% | 5 分钟 |
| 内存使用率 | > 80% | > 90% | 5 分钟 |
| OOM 次数 | > 0 | - | 立即 |
| 容器重启 | > 3 次/小时 | > 10 次/小时 | - |
| 磁盘使用 | > 80% | > 90% | 5 分钟 |

完整监控配置请参考：[Docker容器监控与可观测性](./docker-monitor.md)

## 10. 与 Kubernetes 的对应关系

从 Docker 迁移到 Kubernetes 时，资源限制的映射关系：

| Docker | Kubernetes | 说明 |
|--------|-----------|------|
| `--cpus` | `resources.limits.cpu` | CPU 硬限制 |
| - | `resources.requests.cpu` | CPU 调度保障 |
| `-m/--memory` | `resources.limits.memory` | 内存硬限制 |
| `--memory-reservation` | `resources.requests.memory` | 内存调度保障 |
| `--pids-limit` | `PodPidsLimit` (kubelet) | 进程数限制 |

**Kubernetes 示例**：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: app
    image: myapp:latest
    resources:
      requests:
        memory: "1Gi"      # 相当于 --memory-reservation
        cpu: "1000m"       # 1 核心
      limits:
        memory: "2Gi"      # 相当于 --memory
        cpu: "2000m"       # 2 核心
```

**关键差异**：

1. **Kubernetes 的 requests**：影响调度决策，保证最小资源
2. **Docker 没有 requests 概念**：所有限制都是 limits
3. **迁移建议**：在 Docker 阶段就按 requests/limits 思路设计，迁移更平滑

---

## 相关文档

- [Docker Compose容器编排](./docker-compose.md) - 在 Compose 中配置资源限制
- [Docker容器监控](./docker-monitor.md) - 监控资源使用和设置告警
- [Docker数据目录管理](./docker-data.md) - 磁盘空间和日志管理
- [Docker镜像构建](./docker-build-image.md) - 优化镜像大小，减少资源占用

**核心原则**：先监控、再限制、持续优化。资源限制不是一次性配置，而是随着业务发展持续调整的过程。
