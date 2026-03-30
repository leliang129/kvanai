---
title: nsenter命令的使用
sidebar_position: 2
---

## nsenter简介
nsenter命令是一个可以在指定进程的命令空间下运行指定程序的命令。它位于util-linux包中。
    
我们使用 Kubernetes 时难免发生一些网络问题，往往需要进入容器的网络命名空间 (netns) 中，进行一些网络调试来定位问题，本文介绍如何进入容器的 netns。

## 排查步骤
### 获取容器的ID
```bash
root@master01:~# kubectl describe pods nginx-demo-65df8cb4c4-zbckd 

Containers:
  nginx:
    Container ID:   containerd://d9ec0a5a912e0b6e21b76b86c2e02c114a3906e2cb87e3de3b84ec1e93b43c54
```

### 获取PID
拿到 `container id` 后，查询 `pod` 所在节点,去获取其主进程 `pid`。

```bash
# 查看pod所在节点
root@master01:~# kubectl get pods -owide
NAME                          READY   STATUS    RESTARTS      AGE   IP           NODE     NOMINATED NODE   READINESS GATES
nginx-demo-65df8cb4c4-zbckd   1/1     Running   0             10m   10.244.2.8   node03   <none>           <none>

# 查询主进程pid
root@node03:~# nerdctl inspect d9ec0a5a912e0b6e21b76b86c2e02c114a3906e2cb87e3de3b84ec1e93b43c54 | grep -i pid
            "Pid": 4361,
```

### 使用nsenter命令进入容器的netns
```bash
root@node03:~# nsenter -n -t 4361
```

### 调试网络
成功进入容器的 netns，可以使用节点上的网络工具进行调试网络，可以首先使用 `ip a` 验证下 ip 地址是否为 pod ip:
```bash
root@node03:~# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default 
    link/ether ea:e0:56:fc:84:40 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.244.2.8/24 brd 10.244.2.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::e8e0:56ff:fefc:8440/64 scope link 
       valid_lft forever preferred_lft forever
```