---
title: Jenkins 故障排查手册
sidebar_position: 14
---

# Jenkins 故障排查手册


## 14.1 排查思路

Jenkins 故障建议按链路分层排查：

1. Jenkins 服务是否正常启动。
2. Web 页面是否能访问。
3. 插件和系统配置是否正常。
4. Job 是否进入队列。
5. Agent 是否在线且标签匹配。
6. 源码、凭据、构建工具是否可用。
7. Docker、Kubernetes、制品库等外部系统是否正常。
8. 磁盘、内存、CPU、网络是否异常。

常用日志入口：

```text
Manage Jenkins -> System Log
Job -> Console Output
Node -> Log
```

系统日志：

```bash
journalctl -u jenkins -f
journalctl -u jenkins -n 300 --no-pager
```

Docker 日志：

```bash
docker logs -f jenkins
```

## 14.2 Jenkins 无法启动

检查服务状态：

```bash
systemctl status jenkins
journalctl -u jenkins -n 300 --no-pager
```

常见原因：

| 原因 | 现象 |
| --- | --- |
| Java 版本不兼容 | 日志提示 unsupported class version |
| 端口被占用 | 8080 bind failed |
| Jenkins Home 权限错误 | permission denied |
| 插件损坏 | 启动时插件加载失败 |
| 磁盘满 | no space left on device |
| 配置 XML 损坏 | cannot parse config.xml |

检查端口：

```bash
ss -lntp | grep :8080
```

检查磁盘：

```bash
df -h
du -sh /var/lib/jenkins/*
```

检查权限：

```bash
ls -ld /var/lib/jenkins
chown -R jenkins:jenkins /var/lib/jenkins
```

## 14.3 页面无法访问

排查方向：

- Jenkins 服务是否启动。
- 端口是否监听。
- 防火墙和安全组是否放行。
- Nginx 反向代理是否正常。
- Jenkins URL 是否配置正确。

命令：

```bash
curl -I http://127.0.0.1:8080
ss -lntp | grep :8080
firewall-cmd --list-ports
```

Nginx 反代检查：

```bash
nginx -t
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

## 14.4 登录问题

### 14.4.1 忘记管理员密码

操作前先备份：

```bash
systemctl stop jenkins
cp /var/lib/jenkins/config.xml /var/lib/jenkins/config.xml.bak
```

编辑：

```xml
<useSecurity>false</useSecurity>
```

启动：

```bash
systemctl start jenkins
```

登录后立即重新开启安全配置并重置管理员密码。

### 14.4.2 LDAP / OAuth 登录失败

排查方向：

- Jenkins 到 LDAP/OAuth 服务网络是否通。
- 账号是否存在且未禁用。
- 回调地址是否正确。
- Jenkins URL 是否配置为外部访问域名。
- 时间是否同步。

## 14.5 插件问题

### 14.5.1 插件下载失败

排查：

- Jenkins 是否能访问 Update Center。
- 代理、DNS、证书是否正常。
- 插件源是否可用。

国内镜像示例：

```text
https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json
https://mirrors.huaweicloud.com/jenkins/updates/update-center.json
```

### 14.5.2 插件升级后 Jenkins 异常

处理方式：

- 查看 Jenkins 日志。
- 查看插件依赖是否缺失。
- 回退插件版本。
- 必要时恢复升级前备份。

插件目录：

```text
/var/lib/jenkins/plugins
```

禁用插件可以临时重命名：

```bash
mv /var/lib/jenkins/plugins/plugin-name.jpi /var/lib/jenkins/plugins/plugin-name.jpi.disabled
systemctl restart jenkins
```

## 14.6 构建一直排队

常见原因：

- 没有可用 Agent。
- Job 指定的 label 不匹配。
- Agent 离线。
- 执行器数量不足。
- 上一次构建未结束。
- 启用了 `disableConcurrentBuilds()`。

检查：

```text
Build Queue
Manage Jenkins -> Nodes
Node -> Build Executor Status
```

Jenkinsfile：

```groovy
agent {
    label 'linux && docker'
}
```

确认是否有节点同时具备 `linux` 和 `docker` 标签。

## 14.7 Agent 离线

SSH Agent 排查：

```bash
ssh jenkins@agent-host
java -version
df -h
free -m
```

Inbound Agent 排查：

```bash
systemctl status jenkins-agent
journalctl -u jenkins-agent -n 200 --no-pager
```

常见原因：

- Java 版本不兼容。
- SSH 凭据错误。
- 工作目录权限错误。
- Agent 主机磁盘满。
- Agent 无法连接 Controller。
- Controller URL 或 WebSocket 配置错误。

## 14.8 Git 拉取失败

常见错误：

| 错误 | 可能原因 |
| --- | --- |
| Authentication failed | Token 或密码错误 |
| Repository not found | 仓库 URL 错误或无权限 |
| Host key verification failed | SSH known_hosts 问题 |
| Could not resolve host | DNS 问题 |
| Connection timed out | 网络或防火墙问题 |

排查：

```bash
git ls-remote https://gitlab.example.com/devops/demo-service.git
ssh -T git@gitlab.example.com
```

Jenkins 中检查：

- Git 凭据 ID。
- 仓库 URL。
- 分支名。
- Agent 是否能访问 GitLab。

## 14.9 Pipeline 报错

### 14.9.1 No such DSL method

常见原因：

- 插件未安装。
- Pipeline Step 名称写错。
- Shared Library 未加载。
- `vars/xxx.groovy` 中没有 `call` 方法。

处理：

```text
http://jenkins.example.com/pipeline-syntax
```

使用 Pipeline Syntax 生成标准步骤。

### 14.9.2 MissingPropertyException

常见原因：

- 变量未定义。
- Groovy 变量和 Shell 变量混用。
- `params.xxx` 或 `env.xxx` 写错。

建议：

```groovy
script {
    def image = "demo:${env.BUILD_NUMBER}"
    sh "docker build -t ${image} ."
}
```

### 14.9.3 script 位置错误

Declarative Pipeline 中复杂 Groovy 必须放入 `script {}`：

```groovy
steps {
    script {
        def name = 'demo'
        echo name
    }
}
```

## 14.10 凭据问题

排查方向：

- `credentialsId` 是否正确。
- 凭据类型是否匹配。
- 凭据作用域是否当前 Job 可见。
- 是否在 `withCredentials` 作用域外使用变量。
- MR / Fork 构建是否被限制读取凭据。

验证变量非空：

```groovy
withCredentials([
    string(credentialsId: 'api-token', variable: 'API_TOKEN')
]) {
    sh 'test -n "${API_TOKEN}"'
}
```

不要直接打印凭据内容。

## 14.11 Docker 构建问题

### 14.11.1 Docker 权限错误

```bash
id jenkins
ls -l /var/run/docker.sock
docker version
```

常见处理：

```bash
usermod -aG docker jenkins
systemctl restart docker
```

然后重启 Jenkins Agent。

### 14.11.2 镜像推送失败

排查：

- Registry 地址是否正确。
- 凭据是否有效。
- Harbor Robot Account 是否有 Push 权限。
- HTTPS 证书是否可信。
- 镜像项目是否存在。

### 14.11.3 磁盘不足

```bash
docker system df
docker image prune -f
docker builder prune -f
df -h
```

## 14.12 Kubernetes 发布问题

### 14.12.1 kubectl 无权限

```bash
kubectl auth can-i get pods -n test
kubectl auth can-i patch deployment -n test
```

检查：

- kubeconfig 是否正确。
- ServiceAccount 是否绑定 Role。
- namespace 是否正确。

### 14.12.2 镜像拉取失败

排查：

```bash
kubectl -n test describe pod <pod-name>
```

常见原因：

- imagePullSecret 缺失。
- 镜像地址错误。
- 镜像 tag 不存在。
- Harbor 证书不可信。
- 节点无法访问镜像仓库。

### 14.12.3 rollout 超时

```bash
kubectl -n test rollout status deployment/demo-service --timeout=300s
kubectl -n test describe deploy demo-service
kubectl -n test get pods -l app=demo-service
kubectl -n test logs <pod-name>
```

常见原因：

- 应用启动失败。
- readinessProbe 不通过。
- 资源不足无法调度。
- 配置或 Secret 缺失。

## 14.13 Webhook 不触发

GitLab Webhook 排查：

- GitLab Webhook URL 是否正确。
- Secret Token 是否一致。
- GitLab 是否能访问 Jenkins。
- Jenkins Job 是否启用 GitLab 触发器。
- Jenkins 反向代理是否转发正确。

GitLab 测试：

```text
Project -> Settings -> Webhooks -> Test
```

Jenkins 检查：

```text
Manage Jenkins -> System Log
Job -> Build Triggers
```

## 14.14 磁盘与性能问题

### 14.14.1 Jenkins Home 过大

检查：

```bash
du -sh /var/lib/jenkins/*
du -sh /var/lib/jenkins/jobs/*
```

处理：

- 配置构建保留策略。
- 清理 workspace。
- 大制品上传制品库。
- 删除无用 Job。

Pipeline：

```groovy
options {
    buildDiscarder(logRotator(numToKeepStr: '20'))
}

post {
    always {
        cleanWs()
    }
}
```

### 14.14.2 Jenkins 页面慢

排查方向：

- 插件过多或异常。
- Job 和构建历史过多。
- Controller 内存不足。
- 磁盘 IO 慢。
- 大量构建运行在 Controller。

检查：

```bash
top
free -m
iostat -x 1
journalctl -u jenkins -n 300 --no-pager
```

建议：

- Controller 执行器设置为 0。
- 构建转移到 Agent。
- 清理构建历史。
- 给 Jenkins 单独数据盘。
- 合理配置 JVM 内存。

## 14.15 常用诊断命令

```bash
# 服务
systemctl status jenkins
journalctl -u jenkins -n 300 --no-pager

# 端口
ss -lntp | grep -E ':8080|:50000'

# 资源
df -h
free -m
top

# 网络
curl -I http://127.0.0.1:8080
curl -I https://gitlab.example.com
curl -I https://harbor.example.com

# Docker
docker version
docker system df

# Kubernetes
kubectl get ns
kubectl get pods -A
```

## 14.16 参考资料

- [Jenkins Troubleshooting](https://www.jenkins.io/doc/book/troubleshooting/)
- [Jenkins System Administration](https://www.jenkins.io/doc/book/system-administration/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Jenkins Managing Nodes](https://www.jenkins.io/doc/book/using/using-agents/)
