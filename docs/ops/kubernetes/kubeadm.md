---
sidebar_position: 2
title: kubeadm部署k8s集群
---

# kubeadm 搭建 Kubernetes 集群

本文是一份面向实操的 kubeadm 安装文档，聚焦使用 `containerd + kubeadm` 搭建多节点 Kubernetes 集群。

- 适用场景：测试环境、预生产环境、需要可控安装过程的生产环境。
- 不包含内容：Kind（本地容器化集群）相关章节。

## 1. 架构与规划

### 1.1 最小拓扑

- `control-plane`：1 台（生产建议 3 台高可用）
- `worker`：2 台起
- 容器运行时：`containerd`
- 网络插件（CNI）：Calico 或 Flannel（二选一）

### 1.2 主机信息示例

```text
172.21.0.2  k8s-master
172.21.0.3  k8s-node1
172.21.0.4  k8s-node2
```

在所有节点配置 `/etc/hosts`：

```bash
cat >> /etc/hosts <<'HOSTS'
172.21.0.2 k8s-master
172.21.0.3 k8s-node1
172.21.0.4 k8s-node2
HOSTS
```

### 1.3 前置要求

- 操作系统：Ubuntu 22.04+/Debian 12+ 或 RHEL/Rocky/Alma 8+
- CPU/内存：
  - 控制平面建议 `2C4G` 起步
  - 工作节点建议 `2C4G` 起步
- 时间同步：NTP 必须正常
- 网络连通：节点间可互通
- 主机名：使用合法 DNS 名称（不要使用默认 `localhost`）

## 2. 全节点系统初始化

以下操作在 **所有节点** 执行。

### 2.0 脚本化初始化（推荐）

你可以直接使用仓库中的脚本完成本节初始化步骤：

```bash
# 在每个节点执行（指定 Kubernetes 软件源通道版本）
curl -fsSL https://docs.kvanai.com/scripts/kubeadm_prereq_init.sh | sudo bash -s -- --k8s-version v1.31
```

常用参数：

```bash
# 指定版本（支持 v1.31 或 1.31）
curl -fsSL https://docs.kvanai.com/scripts/kubeadm_prereq_init.sh | sudo bash -s -- --k8s-version 1.31

# 测试环境：关闭防火墙
curl -fsSL https://docs.kvanai.com/scripts/kubeadm_prereq_init.sh | sudo bash -s -- --k8s-version v1.31 --disable-firewall

# 测试环境（RHEL 系）：同时关闭 SELinux
curl -fsSL https://docs.kvanai.com/scripts/kubeadm_prereq_init.sh | sudo bash -s -- --k8s-version v1.31 --disable-firewall --disable-selinux
```

说明：

- 脚本会自动识别发行版（Debian/Ubuntu、RHEL/Rocky/Alma）。
- `--k8s-version` 默认值为 `v1.31`，建议和你计划安装的 kubeadm/kubelet/kubectl 小版本保持一致。
- 默认不会改动防火墙和 SELinux，仅输出提醒。
- 生产环境建议按最小开放原则配置防火墙，不建议直接关闭。

### 2.1 关闭 swap

```bash
swapoff -a
sed -ri '/\sswap\s/s/^/#/' /etc/fstab
```

验证：

```bash
free -h
```

### 2.2 加载内核模块

```bash
cat > /etc/modules-load.d/k8s.conf <<'EOF_MOD'
overlay
br_netfilter
EOF_MOD

modprobe overlay
modprobe br_netfilter
```

### 2.3 配置内核参数

```bash
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<'EOF_SYSCTL'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF_SYSCTL

sysctl --system
```

### 2.4 防火墙与端口

测试环境可临时关闭防火墙；生产环境建议按最小开放原则放行端口。

控制平面常见端口：

- `6443/tcp`：kube-apiserver
- `2379-2380/tcp`：etcd
- `10250/tcp`：kubelet API
- `10257/tcp`：kube-controller-manager
- `10259/tcp`：kube-scheduler

工作节点常见端口：

- `10250/tcp`：kubelet API
- `30000-32767/tcp`：NodePort（按需）

## 3. 安装 containerd

以下为 Debian/Ubuntu 与 RHEL 系两套步骤，按系统选择其一。

### 3.1 Debian / Ubuntu

```bash
apt-get update
apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
  $(. /etc/os-release; echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y containerd.io
```

### 3.2 RHEL / Rocky / Alma

```bash
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y containerd.io
```

### 3.3 containerd 配置

```bash
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
```

将 `/etc/containerd/config.toml` 中以下项设为 `true`：

```toml
SystemdCgroup = true
```

启动并设置开机自启：

```bash
systemctl daemon-reload
systemctl enable --now containerd
systemctl status containerd --no-pager
```

可选：安装 `crictl` 便于调试 CRI。

## 4. 安装 kubeadm/kubelet/kubectl

以下操作在 **所有节点** 执行。

### 4.1 Debian / Ubuntu（pkgs.k8s.io）

```bash
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
```

### 4.2 RHEL / Rocky / Alma（pkgs.k8s.io）

```bash
cat > /etc/yum.repos.d/kubernetes.repo <<'EOF_REPO'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF_REPO

yum install -y kubelet kubeadm kubectl
systemctl enable --now kubelet
```

> `v1.31` 可替换为你目标版本通道。建议 kubeadm/kubelet/kubectl 保持同一小版本。

## 5. 初始化控制平面

以下仅在 `k8s-master` 执行。

### 5.1 准备 kubeadm 配置文件

```bash
cat > kubeadm-config.yaml <<'EOF_KADM'
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
    cgroup-driver: systemd
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.31.0
controlPlaneEndpoint: "k8s-master:6443"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF_KADM
```

### 5.2 拉取镜像并初始化

```bash
kubeadm config images pull --config kubeadm-config.yaml
kubeadm init --config kubeadm-config.yaml --upload-certs
```

初始化成功后，按输出提示配置 `kubectl`：

```bash
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

## 6. 安装 CNI 网络插件

`kubeadm` 不会自动安装网络插件。下面给出两个选项，任选其一。

### 6.1 Flannel（轻量）

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### 6.2 Calico（生产更常见）

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
```

验证：

```bash
kubectl get pods -A
kubectl get nodes -o wide
```

## 7. Worker 节点加入集群

在 `k8s-master` 获取 join 命令：

```bash
kubeadm token create --print-join-command
```

在每个 worker 上执行输出命令，例如：

```bash
kubeadm join k8s-master:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

如需重新生成证书哈希：

```bash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
  | openssl rsa -pubin -outform der 2>/dev/null \
  | openssl dgst -sha256 -hex | sed 's/^.* //'
```

## 8. 验证与基础检查

```bash
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

建议在安装完成后至少检查：

- 所有节点 `Ready`
- `kube-system` 核心组件 Running
- CoreDNS 正常
- CNI 组件正常

## 9. 可选：安装 Kubernetes Dashboard

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

创建管理员账号（仅测试环境）：

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

```bash
kubectl apply -f admin-user.yaml
kubectl -n kubernetes-dashboard create token admin-user
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```

浏览器访问：`https://127.0.0.1:8443`

## 10. 重置与清理

如安装过程出错，需要回滚节点状态：

```bash
kubeadm reset -f
rm -rf /etc/cni/net.d
rm -rf $HOME/.kube
systemctl restart containerd
```

如果你使用的是 Flannel，可按需清理残留网卡：

```bash
ip link delete cni0 || true
ip link delete flannel.1 || true
```

## 11. 常见问题

### 11.1 `kubeadm init` 卡在 preflight

排查顺序：

1. `swap` 是否彻底关闭。
2. `containerd` 是否启动。
3. `SystemdCgroup=true` 是否生效。
4. 端口是否被占用：`ss -lntp`。

### 11.2 `kubectl get nodes` 一直 NotReady

通常是 CNI 未安装或异常：

```bash
kubectl -n kube-system get pods -o wide
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=100
```

### 11.3 节点加入失败

- token 过期：重新生成 `kubeadm token create --print-join-command`
- 时钟漂移：同步 NTP
- DNS/hosts 不通：检查节点间解析与路由

## 12. 后续建议

- 生产环境建议升级为多控制平面（HA）架构。
- 补齐监控、日志、备份与灾备演练。
- 将安装过程脚本化（Ansible/Terraform）并纳入版本管理。
