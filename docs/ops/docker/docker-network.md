---
title: Docker 网络管理
sidebar_position: 4
---

Docker 提供多种网络驱动（bridge、host、overlay、macvlan、none 等），运维工程师需要理解其适用场景、关键命令与排障方法。本章整理单机与多主机网络常见操作。

## 1. 查看网络

```bash
# 列出网络列表
docker network ls

# 查看网络详情（包括网段、已连接容器）
docker network inspect bridge

# 观察默认 bridge（docker0）信息
ip addr show docker0
brctl show docker0
```

常见驱动：

| 驱动    | 说明                                                     | 使用场景                                       |
| ------- | -------------------------------------------------------- | ---------------------------------------------- |
| bridge  | 单机 NAT 网络（默认），容器间可互访                      | docker run/compose 默认模式                    |
| host    | 容器与宿主共享网络命名空间，无 NAT                      | 高性能、需直接使用宿主网络的场景               |
| overlay | 基于 VXLAN 实现跨主机容器通信，需要 Swarm/K8s 等协调器 | Docker Swarm、Consul/etcd 上自建多机网络      |
| macvlan | 容器获取与宿主同网段的独立 MAC/IP                       | 与物理网络融合、需要二层可见的旧系统或设备    |
| none    | 无网络，需自行管理 namespace                            | 高安全隔离                                        |

## 2. 创建自定义 bridge 网络

```bash
docker network create \
  --driver bridge \
  --subnet 172.30.0.0/16 \
  --gateway 172.30.0.1 \
  --opt com.docker.network.bridge.name=br_custom \
  ops-bridge

# 指定网络启动容器
docker run -d --name app1 --network ops-bridge nginx
docker run -d --name app2 --network ops-bridge busybox sleep 3600
```

- 自定义网络可避免默认 `172.17.0.0/16` 与业务冲突；
- `--ip` 可以固定容器 IP： `docker run --network ops-bridge --ip 172.30.0.10 ...`

## 3. Host 网络

```bash
# 容器直接复用宿主网络
sudo docker run --rm --network host nicolaka/netshoot ifconfig
```

- 无 NAT，端口与宿主共享，需确保无冲突；
- 适合需要访问宿主服务或吞吐要求高的场景（如负载均衡器、日志 agent）。

## 4. Overlay 网络（多主机）

使用 Docker Swarm 或者借助 etcd/consul driver 创建 overlay 网络。

```bash
# 初始化 swarm
docker swarm init --advertise-addr 10.0.0.10

# 创建 overlay 网络
docker network create -d overlay --attachable ops-overlay

# 以服务方式部署
docker service create --name web --network ops-overlay nginx
```

排障：

- 确保各节点互通 UDP 4789（VXLAN），TCP 2377/7946；
- `docker network inspect ops-overlay` 查看节点状态；
- 使用 `tcpdump -i vxlan0` 或 `ethtool -S` 检查封包情况。

## 5. Macvlan

```bash
# 创建 macvlan 网络（父接口 enp0s8）
docker network create -d macvlan \
  --subnet=192.168.100.0/24 \
  --gateway=192.168.100.1 \
  -o parent=enp0s8 ops-macvlan

# 启动容器
sudo docker run -d --name legacy --network ops-macvlan --ip 192.168.100.50 nginx
```

- 容器会被视为局域网中的真实设备；
- 需要交换机开启端口转发（或使用 macvlan bridge 模式）；
- 宿主机默认无法访问 macvlan 容器，可创建 bridge + macvlan 的混合模式或额外 veth。

## 6. 网络排障命令

```bash
# 进入容器查看网络
docker exec -it app1 /bin/sh -c 'ip a && netstat -rn && cat /etc/resolv.conf'

# 宿主机进入容器 namespace 调试
nsenter --target $(docker inspect -f '{{.State.Pid}}' app1) --net /bin/bash

# 检查 iptables NAT 规则
sudo iptables -t nat -L -n --line-number | grep DOCKER
```

常见问题与处理：

| 现象                         | 排查策略                                                                                                            |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| 容器 DNS 解析失败            | 检查 `/etc/docker/daemon.json` 的 `dns` 配置；查看 `/etc/resolv.conf` 是否被宿主机 NetworkManager 修改             |
| 容器出网失败                 | 检查宿主防火墙是否允许 `MASQUERADE`，`iptables -t nat -L -n | grep MASQUERADE`；确保 `ip_forward=1`                 |
| bridge 网段冲突              | 使用 `docker network inspect bridge` 确认网段，与企业 VPC 冲突时可在 daemon.json 中设置 `default-address-pools` |
| overlay 网络节点不可达       | 检查 swarm 节点状态、UDP 4789 是否开放，使用 `docker network inspect` 观察是否有节点 `Endpoint` down               |
| macvlan 宿主无法访问容器     | 通过创建 `macvlan` `bridge` 模式或使用 `ip link add macvlan-shim link enp0s8 type macvlan mode bridge`            |

## 7. Compose/CI 场景

- `docker compose up` 默认创建 project 级 network，可在 `docker-compose.yml` 中声明自定义配置：

```yaml
networks:
  ops-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.40.0.0/24
services:
  web:
    image: nginx
    networks:
      ops-net:
        ipv4_address: 172.40.0.10
```

- 在 CI/CD 中启动容器做集成测试时，可复用 `docker network create ci-net`，让服务与数据库共享同一网络；
- 与 Kubernetes 对接时，Docker 网络主要用于本地开发或构建阶段，生产由 CNI（Calico/Flannel/Cilium）负责。

掌握网络驱动特点和命令，能帮助迅速定位连接问题，并设计适合的容器网络拓扑，为后续迁移到 Kubernetes 等编排器铺平道路。
