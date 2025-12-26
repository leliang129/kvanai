---
title: Docker容器监控与可观测性
sidebar_position: 10
---

Docker 容器监控是保障容器化应用稳定运行的关键。本文从运维视角介绍如何构建完整的 Docker 监控体系，涵盖：

- 原生监控工具（快速排查）
- 指标采集与可视化（Prometheus + Grafana）
- 日志管理（收集、存储、分析）
- 告警策略（主动发现问题）
- 生产级监控方案实战

> **核心理念**：监控的目标不是"看到数据"，而是"及时发现问题、快速定位原因、指导决策优化"。

## 1. 监控指标体系（四大黄金指标）

### 1.1 容器资源指标

| 指标类型 | 关键指标 | 告警阈值参考 |
|---------|---------|------------|
| **CPU** | 使用率、负载、限流次数 | CPU > 80% 持续 5min |
| **内存** | 使用量、使用率、OOM 次数 | 内存 > 90%，OOM > 0 |
| **磁盘** | 使用量、IO 吞吐、IOPS | 磁盘 > 85%，IO 等待 > 50% |
| **网络** | 流量、连接数、错误率 | 丢包率 > 1%，连接数异常增长 |

### 1.2 应用层指标

- **健康状态**：容器启动/重启次数、健康检查失败次数
- **业务指标**：QPS、响应时间、错误率（需应用层暴露）
- **依赖服务**：数据库连接池、缓存命中率、消息队列堆积

### 1.3 日志与事件

- **容器生命周期事件**：启动、停止、重启、OOM Kill
- **错误日志**：应用异常、慢查询、认证失败
- **审计日志**：镜像拉取、配置变更、权限操作

## 2. 原生监控工具（快速诊断）

### 2.1 docker stats（实时资源监控）

查看所有容器的实时资源使用：

```bash
# 实时显示所有容器资源使用（默认每秒刷新）
docker stats

# 只显示一次（不持续刷新）
docker stats --no-stream

# 查看特定容器
docker stats <container_name>

# 自定义输出格式（仅显示关键指标）
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
```

**输出示例**：

```
CONTAINER ID   NAME      CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O
a1b2c3d4e5f6   app       2.34%     256.5MiB / 1GiB       25.05%    1.2MB / 890KB     12.3MB / 0B
```

**关键字段解读**：
- `CPU %`：CPU 使用百分比（多核系统可能超过 100%）
- `MEM USAGE / LIMIT`：当前内存使用 / 容器内存限制
- `MEM %`：内存使用百分比
- `NET I/O`：网络接收 / 发送流量
- `BLOCK I/O`：磁盘读 / 写流量

### 2.2 docker inspect（详细信息诊断）

查看容器的完整配置和状态：

```bash
# 查看容器完整信息（JSON 格式）
docker inspect <container_name>

# 使用 Go 模板提取特定字段
docker inspect --format='{{.State.Status}}' <container_name>
docker inspect --format='{{.State.ExitCode}}' <container_name>
docker inspect --format='{{.RestartCount}}' <container_name>
docker inspect --format='{{.HostConfig.Memory}}' <container_name>
docker inspect --format='{{.NetworkSettings.IPAddress}}' <container_name>
```

**常用诊断场景**：

```bash
# 检查容器重启次数（高重启次数通常表示问题）
docker inspect --format='{{.RestartCount}}' app

# 检查容器退出码（0 正常，非 0 异常）
docker inspect --format='{{.State.ExitCode}}' app

# 检查 OOM Kill 状态
docker inspect --format='{{.State.OOMKilled}}' app

# 查看容器资源限制
docker inspect --format='Memory: {{.HostConfig.Memory}} CPUs: {{.HostConfig.NanoCpus}}' app
```

### 2.3 docker events（实时事件监控）

监控 Docker 守护进程的所有事件：

```bash
# 实时监控所有事件
docker events

# 过滤特定类型的事件
docker events --filter 'type=container'
docker events --filter 'event=start'
docker events --filter 'event=die'
docker events --filter 'event=oom'

# 过滤特定容器
docker events --filter 'container=app'

# 查看历史事件（最近 1 小时）
docker events --since '1h'
docker events --since '2024-01-01T00:00:00' --until '2024-01-01T23:59:59'

# 格式化输出
docker events --format '{{json .}}' | jq
```

**实战用法**：

```bash
# 监控容器 OOM 事件
docker events --filter 'event=oom' --format 'Container {{.Actor.Attributes.name}} was OOM killed at {{.time}}'

# 监控容器重启
docker events --filter 'event=restart' --format '{{.time}}: {{.Actor.Attributes.name}} restarted'
```

### 2.4 docker logs（日志查看）

```bash
# 查看容器日志（最近 100 行）
docker logs --tail=100 <container_name>

# 实时��踪日志
docker logs -f <container_name>

# 查看带时间戳的日志
docker logs -t <container_name>

# 查看指定时间范围的日志
docker logs --since '1h' <container_name>
docker logs --since '2024-01-01T00:00:00' --until '2024-01-01T23:59:59' <container_name>

# 组合使用
docker logs -f --tail=200 -t <container_name>
```

## 3. 容器资源限制与监控配置

在 Compose 中配置资源限制和健康检查：

```yaml
services:
  app:
    image: myapp:latest
    # 资源限制
    mem_limit: 1g              # 内存硬限制
    mem_reservation: 512m      # 内存软限制（保证最小分配）
    cpus: 2.0                  # CPU 核心数限制
    pids_limit: 200            # 最大进程数限制

    # 健康检查
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s            # 检查间隔
      timeout: 10s             # 超时时间
      retries: 3               # 失败重试次数
      start_period: 40s        # 启动宽限期

    # 重启策略
    restart: unless-stopped

    # 日志配置
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "5"
        labels: "app,env"
        tag: "{{.Name}}/{{.ID}}"
```

## 4. Prometheus + Grafana 监控方案（生产推荐）

### 4.1 架构设计

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Docker    │────▶│  cAdvisor    │────▶│ Prometheus  │
│  Containers │     │ (采集器)      │     │ (时序数据库) │
└─────────────┘     └──────────────┘     └─────────────┘
                                                │
                    ┌──────────────┐            │
                    │  Alertmanager│◀───────────┘
                    │  (告警)       │
                    └──────────────┘
                           │
                    ┌──────────────┐     ┌─────────────┐
                    │  Grafana     │────▶│  Dashboard  │
                    │  (可视化)     │     │  (仪表板)    │
                    └──────────────┘     └─────────────┘
```

### 4.2 完整的监控栈配置

创建 `monitoring/compose.yaml`：

```yaml
services:
  # cAdvisor：容器资源采集
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.47.0
    container_name: cadvisor
    privileged: true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    ports:
      - "8080:8080"
    restart: unless-stopped
    command:
      - '--housekeeping_interval=10s'
      - '--docker_only=true'
      - '--disable_metrics=disk,network,tcp,udp,percpu,sched,process'

  # Prometheus：指标采集与存储
  prometheus:
    image: prom/prometheus:v2.54.1
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./alert.rules.yml:/etc/prometheus/alert.rules.yml:ro
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    restart: unless-stopped
    depends_on:
      - cadvisor

  # Grafana：可视化仪表板
  grafana:
    image: grafana/grafana:11.1.0
    container_name: grafana
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-admin}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3000
    ports:
      - "3000:3000"
    restart: unless-stopped
    depends_on:
      - prometheus

  # Alertmanager：告警管理（可选）
  alertmanager:
    image: prom/alertmanager:v0.27.0
    container_name: alertmanager
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    ports:
      - "9093:9093"
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    restart: unless-stopped

  # Node Exporter：主机指标采集（可选）
  node-exporter:
    image: prom/node-exporter:v1.8.2
    container_name: node-exporter
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    restart: unless-stopped

volumes:
  prometheus_data:
    driver: local
  grafana_data:
    driver: local
  alertmanager_data:
    driver: local
```

### 4.3 Prometheus 配置

创建 `monitoring/prometheus.yml`：

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'docker-prod'
    env: 'production'

# 告警规则文件
rule_files:
  - 'alert.rules.yml'

# 告警管理器配置
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

# 采集目标配置
scrape_configs:
  # Prometheus 自身监控
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # cAdvisor 容器指标
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'docker-host'

  # Node Exporter 主机指标
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  # 应用自定义指标（如果应用暴露了 /metrics 端点）
  - job_name: 'app'
    static_configs:
      - targets: ['app:8080']
    metrics_path: '/metrics'
```

### 4.4 告警规则配置

创建 `monitoring/alert.rules.yml`：

```yaml
groups:
  - name: container_alerts
    interval: 30s
    rules:
      # 容器 CPU 使用率过高
      - alert: ContainerHighCPU
        expr: rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100 > 80
        for: 5m
        labels:
          severity: warning
          category: resource
        annotations:
          summary: "容器 CPU 使用率过高"
          description: "容器 {{ $labels.name }} CPU 使用率 {{ $value | humanize }}% 超过 80%（持续 5 分钟）"

      # 容器内存使用率过高
      - alert: ContainerHighMemory
        expr: (container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100 > 90
        for: 5m
        labels:
          severity: critical
          category: resource
        annotations:
          summary: "容器内存使用率过高"
          description: "容器 {{ $labels.name }} 内存使用率 {{ $value | humanize }}% 超过 90%"

      # 容器频繁重启
      - alert: ContainerRestartTooMuch
        expr: rate(container_last_seen{name!=""}[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
          category: stability
        annotations:
          summary: "容器频繁重启"
          description: "容器 {{ $labels.name }} 在过去 5 分钟内频繁重启"

      # 容器 OOM Kill
      - alert: ContainerOOMKilled
        expr: container_oom_events_total > 0
        labels:
          severity: critical
          category: stability
        annotations:
          summary: "容器发生 OOM Kill"
          description: "容器 {{ $labels.name }} 因内存不足被强制终止"

      # 容器停止运行
      - alert: ContainerDown
        expr: time() - container_last_seen{name!=""} > 60
        for: 1m
        labels:
          severity: critical
          category: availability
        annotations:
          summary: "容器已停止"
          description: "容器 {{ $labels.name }} 已停止超过 1 分钟"

      # 磁盘空间不足
      - alert: HostDiskSpaceWarning
        expr: (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"}) * 100 < 15
        for: 5m
        labels:
          severity: warning
          category: resource
        annotations:
          summary: "主机磁盘空间不足"
          description: "主机 {{ $labels.instance }} 磁盘 {{ $labels.device }} 可用空间低于 15%"
```

### 4.5 Alertmanager 配置

创建 `monitoring/alertmanager.yml`：

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'alertmanager@example.com'
  smtp_auth_password: 'your_password'

# 告警路由规则
route:
  receiver: 'default-receiver'
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

  routes:
    # 严重告警立即发送
    - match:
        severity: critical
      receiver: 'critical-receiver'
      group_wait: 0s
      repeat_interval: 1h

    # 警告类告警可以等待聚合
    - match:
        severity: warning
      receiver: 'warning-receiver'
      group_wait: 30s
      repeat_interval: 4h

# 告警抑制规则
inhibit_rules:
  # 如果容器已停止，抑制该容器的其他告警
  - source_match:
      alertname: 'ContainerDown'
    target_match_re:
      alertname: '(ContainerHighCPU|ContainerHighMemory)'
    equal: ['container_name']

# 告警接收器配置
receivers:
  - name: 'default-receiver'
    email_configs:
      - to: 'ops@example.com'
        headers:
          Subject: '[监控告警] {{ .GroupLabels.alertname }}'

  - name: 'critical-receiver'
    email_configs:
      - to: 'ops-critical@example.com'
        headers:
          Subject: '[严重告警] {{ .GroupLabels.alertname }}'
    webhook_configs:
      - url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        send_resolved: true

  - name: 'warning-receiver'
    email_configs:
      - to: 'ops-warning@example.com'
```

### 4.6 Grafana 仪表板配置

创建 `monitoring/grafana/provisioning/datasources/prometheus.yml`：

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
```

创建 `monitoring/grafana/provisioning/dashboards/default.yml`：

```yaml
apiVersion: 1

providers:
  - name: 'Docker Monitoring'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
```

**推荐的 Grafana 仪表板**：

1. **Docker and System Monitoring** (ID: 179)
2. **Docker Container & Host Metrics** (ID: 10619)
3. **cAdvisor** (ID: 14282)

导入方式：Grafana UI → Dashboards → Import → 输入 Dashboard ID

## 5. 日志管理方案

### 5.1 配置日志驱动

在 `/etc/docker/daemon.json` 中配置全局日志策略：

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5",
    "compress": "true",
    "labels": "app,env",
    "tag": "{{.Name}}/{{.ID}}"
  }
}
```

重启 Docker 使配置生效：

```bash
sudo systemctl restart docker
```

### 5.2 ELK 日志收集方案（可选）

如需集中式日志管理，可以使用 ELK Stack：

```yaml
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.15.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.security.enabled=false
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"

  logstash:
    image: docker.elastic.co/logstash/logstash:8.15.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.15.0
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

volumes:
  es_data:
    driver: local
```

### 5.3 轻量级方案：Loki + Promtail + Grafana

更轻量的日志方案（推荐中小规模使用）：

```yaml
services:
  loki:
    image: grafana/loki:3.0.0
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml:ro
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    restart: unless-stopped

  promtail:
    image: grafana/promtail:3.0.0
    volumes:
      - ./promtail-config.yml:/etc/promtail/config.yml:ro
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    command: -config.file=/etc/promtail/config.yml
    restart: unless-stopped
    depends_on:
      - loki

volumes:
  loki_data:
    driver: local
```

## 6. 启动监控栈

```bash
# 进入监控目录
cd monitoring

# 启动所有监控服务
docker compose up -d

# 检查服务状态
docker compose ps

# 查看日志
docker compose logs -f
```

**访问监控面板**：

- **Grafana**：[http://localhost:3000](http://localhost:3000) - 默认账号：admin/admin
- **Prometheus**：[http://localhost:9090](http://localhost:9090)
- **cAdvisor**：[http://localhost:8080](http://localhost:8080)
- **Alertmanager**：[http://localhost:9093](http://localhost:9093)

## 7. 监控最佳实践

### 7.1 分层监控策略

```
┌─────────────────────────────────────┐
│  应用层：业务指标、错误率、响应时间   │
├─────────────────────────────────────┤
│  容器层：资源使用、健康状态、重启次数 │
├─────────────────────────────────────┤
│  主机层：CPU、内存、磁盘、网络       │
├─────────────────────────────────────┤
│  基础设施：Docker 守护进程、存储驱动  │
└─────────────────────────────────────┘
```

### 7.2 告警分级策略

| 级别 | 响应时间 | 通知方式 | 示例 |
|------|---------|---------|------|
| **P0 - 严重** | 立即（5min内） | 电话 + 短信 + 邮件 | 容器全部停止、数据库不可用 |
| **P1 - 紧急** | 15min 内 | 短信 + 邮件 + IM | 内存 > 95%、频繁 OOM |
| **P2 - 警告** | 1h 内 | 邮件 + IM | CPU > 80%、磁盘 > 85% |
| **P3 - 提示** | 工作日处理 | 邮件 | 容器重启、磁盘 > 70% |

### 7.3 关键监控指标速查

```bash
# 1. 容器健康度（最重要）
docker ps --filter "status=exited" | wc -l  # 退出的容器数
docker ps --filter "status=restarting" | wc -l  # 重启中的容器数

# 2. 资源使用 TOP 5
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | sort -k2 -rh | head -6

# 3. 容器重启次数排名
for container in $(docker ps -q); do
  name=$(docker inspect --format='{{.Name}}' $container | sed 's|/||')
  restarts=$(docker inspect --format='{{.RestartCount}}' $container)
  echo "$name: $restarts"
done | sort -t: -k2 -rn

# 4. 查看最近 OOM 的容器
docker events --since 24h --filter 'event=oom' --format '{{.Time}}: {{.Actor.Attributes.name}}'

# 5. 磁盘空间使用
docker system df -v
```

## 8. 常见问题排查

### 8.1 cAdvisor 无法启动

**问题**：权限不足或挂载点问题

```bash
# 检查 cAdvisor 日志
docker logs cadvisor

# 确保以 privileged 模式运行
docker run --privileged --rm -it \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  gcr.io/cadvisor/cadvisor:latest
```

### 8.2 Prometheus 无法抓取指标

**问题**：网络不通或配置错误

```bash
# 检查 Prometheus targets 状态
curl http://localhost:9090/api/v1/targets | jq

# 测试从 Prometheus 容器访问 cAdvisor
docker exec prometheus wget -O- http://cadvisor:8080/metrics

# 检查防火墙规则
sudo iptables -L -n | grep 8080
```

### 8.3 Grafana 数据源连接失败

**问题**：数据源配置错误

```bash
# 检查 Grafana 日志
docker logs grafana

# 测试从 Grafana 容器访问 Prometheus
docker exec grafana wget -O- http://prometheus:9090/-/healthy

# 确认服务在同一网络中
docker network inspect monitoring_default
```

### 8.4 告警不生效

**问题**：规则配置错误或 Alertmanager 未连接

```bash
# 检查告警规则是否加载
curl http://localhost:9090/api/v1/rules | jq

# 检查 Alertmanager 状态
curl http://localhost:9093/-/healthy

# 查看当前活跃告警
curl http://localhost:9090/api/v1/alerts | jq
```

## 9. 性能优化建议

### 9.1 监控系统资源控制

监控系统本身也需要资源，避免"监控拖垮系统"：

```yaml
services:
  prometheus:
    mem_limit: 2g
    cpus: 1.0

  grafana:
    mem_limit: 512m
    cpus: 0.5

  cadvisor:
    mem_limit: 256m
    cpus: 0.5
```

### 9.2 数据保留策略

```bash
# Prometheus 数据保留 15 天（默认 15d）
--storage.tsdb.retention.time=15d

# 限制存储大小（超过后删除旧数据）
--storage.tsdb.retention.size=10GB
```

### 9.3 采集频率优化

根据环境调整采集频率：

- **开发环境**：30s - 60s
- **生产环境**：10s - 15s（默认）
- **高负载环境**：5s（增加资源消耗）

---

## 10. 总结与进阶

### 监控体系建设路径

1. **起步阶段**：使用 `docker stats`、`docker logs` 手动排查
2. **成长阶段**：部署 Prometheus + Grafana + cAdvisor
3. **成熟阶段**：集成日志系统（Loki/ELK）、完善告警策略
4. **云原生**：迁移到 Kubernetes + Prometheus Operator

### 关键原则

- **监控先行**：在问题发生前就能看到趋势
- **告警精准**：减少无效告警（狼来了效应）
- **响应及时**：明确告警分级和响应时间
- **持续优化**：根据实际情况调整阈值和策略

### 相关文档

- [Docker资源限制](./docker-resource.md) - 深入理解资源限制机制
- [Docker日志管理](./docker-data.md) - 日志治理与轮转策略
- [Docker Compose编排](./docker-compose.md) - 监控栈的容器编排

**监控的本质是"预防"而非"救火"**。完善的监控体系能让你从容应对生产环境的各种挑战。
