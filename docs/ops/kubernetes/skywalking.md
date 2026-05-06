---
title: SkyWalking的介绍与使用
sidebar_position: 10
---

## 简介

[Skywalking](https://skywalking.apache.org/)是一个国产的开源框架，主要开发人员来自于华为，2019年4月17日Apache董事会批准SkyWalking成为顶级项目，支持Java, .Net, Node.js, go, python等探针，数据存储支持Mysql, Elasticsearch等，跟Pinpoint一样采用字节码注入的方式实现代码的无侵入，探针采集数据粒度粗，但性能表现优秀，且对云原生支持，目前增长势头强劲，社区活跃。

Skywalking是分布式系统的应用程序性能监视工具，专为微服务，云原生架构和基于容器（Docker, K8S, Mesos）架构而设计，它是一款优秀的APM（Application Performance Management）工具，包括了分布式追踪，性能指标分析和服务依赖分析等。

## Skywalking的介绍

### 分布式链路追踪

链路追踪解决的问题：客户端的一次请求到结束的背后究竟调用了哪些应用以及哪些模块并经过了哪些节点，且每个模块的调用先后顺序是怎样的、每个模块的处理相应性能如何？

Dapper是google公司在2008年就开始内部使用经过生产环境验证的链路追踪系统。随着时代的发展，大型web集群采用分布式架构和微服务环境。应运而生了分布式链路追踪系统，Skywalking是其中的佼佼者，可以在整个分布式系统中跟踪一个用户请求的完整过程。

### APM系统

APM 系统（Application Performance Monitor，即应用性能监控）它实现了分布式链路追踪。常见的APM系统有CAT, Zipkin, Jaeger, Pinpoint, Skywalking。

Skywalking拥有诸多特点：信息记录完整，多语言自动探针，内置服务网格可观察性，模块化架构，支持告警，可视化美观。

### Skywalking组件

Skywalking主要由4大组件构成：探针，主平台，存储，UI。

![](https://pic.imgdb.cn/item/64a634751ddac507cc4321d6.jpg)

skywalking架构图

```plain text
                                         skywalking架构图
```


| 组件 | 作用 |
| --- | --- |
| 探针 | 基于无侵入式的收集，并通过HTTP或者gRPC方式发送数据到OAP Server。 |
| OAP | Observability Analysis Platform 可观测性分析平台，它是一个高度组件化的轻量级分析程序，由兼容各种探针Receiver、流式分析内核和查询内核三部分构成。 |
| 存储实现 | Storage Implementors，支持多种存储实现并且提供了标准接口，可支持不同的存储后端，常用Elasticsearch做数据库存储。 |
| UI模块 | 通过标准的GraphQL(Facebook在2012年开源)协议进行统计数据查询和展示 。 |

## Skywalking的部署

根据上述的4大组件，对Skywalking进行部署，相关服务与端口如下：


| 服务 | 端口 | 作用 |
| --- | --- | --- |
| agent | N/A | 收集应用信息，与oap 11800端口连接 |
| skywalking-oap | 11800, 12800 | 11800为gRPC数据，连接agent。12800为http数据，连接skywalking-ui |
| elasticsearch7 | 9200 | 数据存储读写端口 |
| skywalking-ui | 8080 | 前端页面，用于查询 |

### 二进制部署

### 安装Elasticsearch

需要部署elasticsearch。为简化实验，这里部署单机版。

```shell
# 下载安装包
root@ubuntu:~# wget https://mirrors.tuna.tsinghua.edu.cn/elasticstack/7.x/apt/pool/main/e/elasticsearch/elasticsearch-7.12.1-amd64.deb

#安装
root@ubuntu:~# dpkg -i elasticsearch-7.12.1-amd64.deb
Selecting previously unselected package elasticsearch.
(Reading database ... 72358 files and directories currently installed.)
Preparing to unpack elasticsearch-7.12.1-amd64.deb ...
Creating elasticsearch group... OK
Creating elasticsearch user... OK
Unpacking elasticsearch (7.12.1) ...
Setting up elasticsearch (7.12.1) ...
Created elasticsearch keystore in /etc/elasticsearch/elasticsearch.keystore
Processing triggers for systemd (245.4-4ubuntu3.21) ...
```

修改配置文件，下列选项全部取消注释，IP均为本机地址，根据实际情况修改设置：

```shell
vim /etc/elasticsearch/elasticsearch.yml

17 cluster.name: skywalking-es-cluster
23 node.name: elasticsearch-7
33 path.data: /var/lib/elasticsearch
37 path.logs: /var/log/elasticsearch
56 network.host: 172.16.41.28
61 http.port: 9200
70 discovery.seed_hosts: ["172.16.41.28"]
74 cluster.initial_master_nodes: ["172.16.41.28"]
```

启动elasticsearch服务，默认开启端口为9200和9300.

```shell
root@ubuntu:~# systemctl enable --now elasticsearch.service
root@ubuntu:~# systemctl status elasticsearch

root@ubuntu:~# netstat -lntp | grep java
tcp6       0      0 172.16.41.28:9200       :::*                    LISTEN      3276/java
tcp6       0      0 172.16.41.28:9300       :::*                    LISTEN      3276/java
```

本地浏览器访问172.16.41.28:9200, 查看部署情况

![](https://pic.imgdb.cn/item/64a6593d1ddac507cc8a20c6.jpg)

### 安装skywalking

**准备java环境**

```plain text
# 更新软件源
root@ubuntu:~# apt update

#安装openjdk-11
root@ubuntu:~# apt install -y openjdk-11-jdk

# 验证
root@ubuntu:~# java -version
openjdk version "11.0.19" 2023-04-18
OpenJDK Runtime Environment (build 11.0.19+7-post-Ubuntu-0ubuntu120.04.1)
OpenJDK 64-Bit Server VM (build 11.0.19+7-post-Ubuntu-0ubuntu120.04.1, mixed mode, sharing)
```

**下载二进制安装包**

[skywalking二进制包下载地址: https://archive.apache.org/dist/skywalking/8.6.0/](https://archive.apache.org/dist/skywalking/8.6.0/)

[https://archive.apache.org/dist/skywalking/8.6.0/](https://archive.apache.org/dist/skywalking/8.6.0/)

```plain text
# 下载安装包
root@ubuntu:~# wget https://archive.apache.org/dist/skywalking/8.6.0/apache-skywalking-apm-es7-8.6.0.tar.gz

# 解压缩
root@ubuntu:~# tar xvf apache-skywalking-apm-es7-8.6.0.tar.gz

# 建立程序目录
root@ubuntu:~# mkdir /apps

# 移动压缩包至程序目录
root@ubuntu:~# mv apache-skywalking-apm-bin-es7/ /apps

# 创建软连接
root@ubuntu:/apps# ln -sv apache-skywalking-apm-bin-es7/ skywalking
'skywalking' -> 'apache-skywalking-apm-bin-es7/'

root@ubuntu:/apps# ls -l
total 4
drwxrwxr-x 10 1001 1002 4096 Jun  7  2021 apache-skywalking-apm-bin-es7
lrwxrwxrwx  1 root root   30 Jul  6 14:36 skywalking -> apache-skywalking-apm-bin-es7/
```

**修改skywalking配置文件**

```plain text
root@ubuntu:/apps/skywalking# vim config/application.yml

111 storage:
112   selector: ${SW_STORAGE:elasticsearch7}


139 elasticsearch7:
140   nameSpace: ${SW_NAMESPACE:""}
141   clusterNodes: ${SW_STORAGE_ES_CLUSTER_NODES:172.16.41.28:9200}
```

**利用startup.sh 启动skywalking程序**

默认开启8080, 11800, 12800端口

```plain text
root@ubuntu:/apps/skywalking# ./bin/startup.sh
SkyWalking OAP started successfully!
SkyWalking Web Application started successfully!

root@ubuntu:/apps/skywalking# netstat -lntp | grep java
tcp6       0      0 :::12800                :::*                    LISTEN      6618/java
tcp6       0      0 :::8080                 :::*                    LISTEN      6642/java
tcp6       0      0 :::11800                :::*                    LISTEN      6618/java
```

**通过ElasticSearch-Head查看elasticsearch数据保存情况**

![](https://pic.imgdb.cn/item/64a665091ddac507cca4e486.jpg)

elasticsearch-head

**访问skywalking的web-ui界面**

```plain text
http://172.16.41.29:8080
```

![](https://pic.imgdb.cn/item/64a665cd1ddac507cca68be1.jpg)

skywalking-ui

### docker部署

可以通过docker-compose文件一键部署skywalking系统，包含3个容器：elasticsearch7, skywalking-oap, skywalking-ui

**安装docker**

```plain text
# step 1: 安装必要的一些系统工具
root@ubuntu:~# sudo apt-get update
root@ubuntu:~# sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
# step 2: 安装GPG证书
root@ubuntu:~# curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
# Step 3: 写入软件源信息
root@ubuntu:~# sudo add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
# Step 4: 更新并安装Docker-CE
root@ubuntu:~# sudo apt-get -y update
root@ubuntu:~# sudo apt-get -y install docker-ce
```

**安装docker-compose**

*github下载地址：*[*https://github.com/docker/compose/*](https://github.com/docker/compose/)

[https://github.com/docker/compose/](https://github.com/docker/compose/)

```plain text
root@ubuntu:~# wget https://github.com/docker/compose/releases/download/v2.17.0/docker-compose-linux-x86_64

root@ubuntu:~# chmod +x docker-compose-linux-x86_64

root@ubuntu:~# mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose
```

**编写docker-compose文件**

```plain text
# 创建目录
root@ubuntu:~# mkdir /apps/sw -p

# 编辑docker-compose文件
root@ubuntu:~# cd /apps/sw/
root@ubuntu:/apps/sw# vim docker-compose.yaml

root@ubuntu:/apps/sw# cat docker-compose.yaml
version: '3.3'
services:
  es7:
    image: elasticsearch:7.10.1
    container_name: es7
    ports:
      - 9200:9200
      - 9300:9300
    environment:
      - discovery.type=single-node #单机模式
      - bootstrap.memory_lock=true #锁定物理内存地址
      - "ES_JAVA_OPTS=-Xms1048m -Xmx1048m" #堆内存大小
      - TZ=Asia/Shanghai
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - /data/elasticsearch/data:/usr/share/elasticsearch/data

  skywalking-oap:
    image: apache/skywalking-oap-server:8.6.0-es7
    container_name: skywalking-oap
    restart: always
    depends_on:
      - es7
    links:
      - es7
    ports:
      - 11800:11800
      - 12800:12800
    environment:
      TZ: Asia/Shanghai
      SW_STORAGE: elasticsearch7
      SW_STORAGE_ES_CLUSTER_NODES: es7:9200

  skywalking-ui:
    image: apache/skywalking-ui:8.6.0
    container_name: skywalking-ui
    restart: always
    depends_on:
      - skywalking-oap
    links:
      - skywalking-oap
    ports:
      - 8080:8080
    environment:
      TZ: Asia/Shanghai
      SW_OAP_ADDRESS: skywalking-oap:12800
```

值得注意，docker部署3个容器都在同一个宿主机上。需要宿主机内存4G以上，同时修改共享目录属主属组。

```plain text
#保证宿主机有4G以上内存
root@ubuntu:~# free -h
              total        used        free      shared  buff/cache   available
Mem:          3.8Gi       321Mi       2.5Gi       1.0Mi       980Mi       3.3Gi
Swap:            0B          0B          0B

#创建es7共享目录，修改属主属组
root@ubuntu:~# mkdir /data/elasticsearch/data
root@ubuntu:~# chown -R docker.docker /data/elasticsearch/data
```

**启动容器**

开启的端口也是8080, 11800, 12800

```plain text
# 创建并启动容器
root@ubuntu:~# cd /apps/sw/
root@ubuntu:~# docker-compose up -d

# 查看容器状态，和端口映射
root@ubuntu:~# docker ps
CONTAINER ID   IMAGE                                    COMMAND                  CREATED        STATUS          PORTS                                                                                                    NAMES
1452175e42bf   apache/skywalking-ui:8.6.0               "bash docker-entrypo…"   10 hours ago   Up 2 minutes    0.0.0.0:8080->8080/tcp, :::8080->8080/tcp                                                                skywalking-ui
6a144110ce00   apache/skywalking-oap-server:8.6.0-es7   "bash docker-entrypo…"   10 hours ago   Up 20 seconds   0.0.0.0:11800->11800/tcp, :::11800->11800/tcp, 1234/tcp, 0.0.0.0:12800->12800/tcp, :::12800->12800/tcp   skywalking-oap
c9116ff17397   elasticsearch:7.10.1                     "/tini -- /usr/local…"   10 hours ago   Up 34 seconds   0.0.0.0:9200->9200/tcp, :::9200->9200/tcp, 0.0.0.0:9300->9300/tcp, :::9300->9300/tcp                     es7
```

**查看首页**

```plain text
http://172.16.41.30:8080
```

![](https://pic.imgdb.cn/item/64a66e441ddac507ccbc6184.jpg)

docker-skywalking-ui

## Skywalking收集Java博客案例

### 安装Halo博客

Halo 是一款现代化的个人独立博客系统，而且可能是最好的Java博客系统，从 1.4.3 起，版本要求为`jdk11`以上的版本，1.4.3以下需要 `jdk1.8` 以上的版本。

[Halo博客官网: https://docs.halo.run/](https://docs.halo.run/)

### 安装java

```plain text
# 更新软件源
root@ubuntu:~# apt update

# 安装jdk-11
root@ubuntu:~# apt install -y openjdk-11-jdk

# 验证java安装情况
root@ubuntu:~# java -version
openjdk version "11.0.19" 2023-04-18
OpenJDK Runtime Environment (build 11.0.19+7-post-Ubuntu-0ubuntu120.04.1)
OpenJDK 64-Bit Server VM (build 11.0.19+7-post-Ubuntu-0ubuntu120.04.1, mixed mode, sharing)
```

### 安装halo博客系统

[halo博客jar包下载地址：https://github.com/halo-dev/halo/releases/tag/v1.6.0](https://github.com/halo-dev/halo/releases/tag/v1.6.0)

```plain text
# 创建程序目录
root@ubuntu:~# mkdir /apps/halo

# 进入到程序目录
root@ubuntu:~# cd /apps/halo

# 下载halo的jar包
root@ubuntu:/apps/halo# wget https://github.com/halo-dev/halo/releases/download/v1.6.0/halo-1.6.0.jar

# 启动运行jar包
root@ubuntu:/apps/halo# java -jar halo-1.6.0.jar

# 检查端口是否监听
root@ubuntu:~# netstat -natlp |grep 8090
tcp6       0      0 :::8090                 :::*                    LISTEN      17173/java
```

因此次部署仅作案例演示，仅创建 Halo 实例，使用默认的 H2 数据库，不推荐用于生产环境，建议体验和测试的时候使用

至此，halo博客已经部署完成，可以通过本地浏览器访问如下地址：

```plain text
http://172.16.41.30:8090
```

**配置网站信息**

![](https://pic.imgdb.cn/item/64a6a5511ddac507cc47714a.png)

halo配置网站信息

**博客登录页面**

![](https://pic.imgdb.cn/item/64a687311ddac507ccfbec3f.jpg)

> 💡 最新版本的halo博客默认使用docker部署,本次部署halo-1.6.0的jar包在GitHub获取

使用设置的用户和密码登录成功

![](https://pic.imgdb.cn/item/64a688261ddac507ccfed7da.jpg)

halo博客登录成功界面

### 安装Java-Agent

[Java-Agent下载地址：https://skywalking.apache.org/downloads/](https://skywalking.apache.org/downloads/)

```plain text
# 下载java-agent
root@ubuntu:~# wget https://archive.apache.org/dist/skywalking/java-agent/8.8.0/apache-skywalking-java-agent-8.8.0.tgz

# 解压缩
root@ubuntu:~# tar xvf apache-skywalking-java-agent-8.8.0.tgz

# 移动agent到程序目录
root@ubuntu:~# mv skywalking-agent /apps/
```

### 配置Java-Agent

```plain text
# 进入到agent目录
root@ubuntu:# cd /apps/agent/skywalking-agent/

# 编辑agent配置文件
root@ubuntu:/apps/agent/skywalking-agent# vim config/agent.config
vim /apps/skywalking-agent/config/agent.config

# 项目名称
18 agent.namespace=${SW_AGENT_NAMESPACE:halo}
# 服务名称
21 agent.service_name=${SW_AGENT_NAME:blog_halo}
# skywalking地址
93 collector.backend_service=${SW_AGENT_COLLECTOR_BACKEND_SERVICES:172.16.41.29:11800}
```

### 启动带agent的halo博客系统

```plain text
# 以agent方式启动halo博客
root@ubuntu:~# java -javaagent:/apps/agent/skywalking-agent/skywalking-agent.jar -jar /apps/halo/halo-1.6.0.jar
```

**再次访问博客系统**

![](https://pic.imgdb.cn/item/64a6aabe1ddac507cc54e0cc.png)

带agent的halo博客系统

### Skywalking查看数据

![](https://pic.imgdb.cn/item/64a6abb41ddac507cc57ce79.png)

skywalking查看halo

## Skywalking面板介绍

### 仪表盘

Skywalking UI仪表盘有4个选项卡，功能如下：


| 选项 | 名称 | 功能 |
| --- | --- | --- |
| Global | 全局 | 显示服务的全局统计详情 |
| Service | 服务 | 表示对请求提供相同行为的一系列或一组工作负载(服务名称),在使用Agent或SDK的时候, 可以自定义服务的名字,如果不定义的话,SkyWalking将会使用你在平台(例如说 Istio)上定义的名字。 |
| Instance | 实例 | 上述的一组工作负载中的每一个工作负载称为一个实例(一个服务运行的节点),一个服务实例可以是一个kubernetes中的pod或者是一个虚拟机甚至是物理机 。 |
| Endpoint | 端点 | 对于特定服务所接收的请求路径, 如HTTP的URI路径和gRPC服务的类 +方法签名，如/api/v1/ |

### 全局

![](https://pic.imgdb.cn/item/64a6afed1ddac507cc639004.png)

sw-global


| 指标 | 含义 |
| --- | --- |
| CPM-calls per minute | 服务平均每分钟请求数 |
| Slow Services ms | 慢响应服务，单位ms |
| Un-Health services(Apdex) | Apdex 性能指标，1为满分 |
| Slow Endpoints(ms) | 全局维度的慢响应端点(API),例如一个接口，显示的是全局慢响应Top N的数据,通过这个可以观测平台性能情况 |
| Global Response Latency(percentile in ms) | 全局响应延迟百分位数统计，单位ms |
| Global Heatmap | 服务响应时间热力分布图，根据当时时间段内不同响应时间(0ms、100ms)的数量用不同的颜色表示 |

### 服务

![](https://pic.imgdb.cn/item/64a6b0da1ddac507cc666f7f.png)

sw-service


| 指标 | 含义 |
| --- | --- |
| Service Apdex | 当前服务的评分 |
| Service Avg Response Times | 平均响应延时，单位ms |
| Service Response Time Percentile | 百分比响应延时 |
| Successful Rate | 请求成功率 |
| Servce Load | 每分钟请求数 |
| Service Throughput （Bytes） | 该指标只适用于TCP 服务。当前服务的吞吐量 |

### 实例

![](https://pic.imgdb.cn/item/64a6b2aa1ddac507cc6b88c2.png)

sw-instance


| 指标 | 含义 |
| --- | --- |
| Service Instance Successful Rate | 当前实例的请求成功率 |
| Service Instance Latency | 当前实例的响应延时 |
| JVM CPU（Java Service） | jvm占用CPU的百分比 |
| JVM Memory (Java Service) | JVM内存占用大小，单位m，包括堆内存，与堆外内存（直接内存） |
| JVM GC Time（ms） | JVM垃圾回收时间，包含YGC和OGC |
| JVM GC Count | JVM垃圾回收次数，包含YGC和OGC |

### 端点

![](https://pic.imgdb.cn/item/64a6b34f1ddac507cc6d29b9.png)

sw-endpoint


| 指标 | 含义 |
| --- | --- |
| Endpoint Load in Current Service（CPM / PPM） | 每个端点（API）每分钟请求数 |
| Slow Endpoints in Current Service（ms） | 每个端点（API）的最慢响应请求时间，单位ms |
| Endpoint Load | 当前端点每个时间段的请求数据 |
| Endpoint Avg Response Time | 当前端点每个时间段的请求行响应时间 |
| Endpoint Response Time Percentile（ms） | 当前端点每个时间段的响应时间占比 |

### 拓扑图

**拓步图显示用户，应用，数据库之间的请求与响应路线：**

![](https://pic.imgdb.cn/item/64a6b4161ddac507cc6ec7d5.png)

### 追踪

**追踪可以列出端口访问对应的后台响应类与函数。适合开发者查看：**

![](https://pic.imgdb.cn/item/64a6b6cd1ddac507cc761750.png)
