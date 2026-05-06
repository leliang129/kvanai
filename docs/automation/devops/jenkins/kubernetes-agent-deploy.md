---
title: Jenkins Kubernetes 发布与动态 Agent
sidebar_position: 11
---

# Jenkins Kubernetes 发布与动态 Agent


## 11.1 场景说明

Jenkins 与 Kubernetes 常见有两类集成：

| 场景 | 说明 |
| --- | --- |
| Jenkins 发布应用到 Kubernetes | Jenkins 使用 `kubectl`、Helm、Kustomize 等工具更新业务应用 |
| Jenkins 使用 Kubernetes 动态 Agent | Jenkins 每次构建动态创建 Pod 作为 Agent，构建完成后销毁 |

这两类场景可以同时存在，但权限、凭据和网络路径不同：

- 发布应用需要 Jenkins 有目标集群的部署权限。
- 动态 Agent 需要 Jenkins Controller 能连接 Kubernetes API，并能调度构建 Pod。

## 11.2 发布到 Kubernetes 的准备

Jenkins Agent 需要：

- 安装 `kubectl`。
- 能访问 Kubernetes API Server。
- Jenkins Credentials 中保存 kubeconfig。
- kubeconfig 对应账号具备目标 namespace 权限。

检查命令：

```bash
kubectl version --client
kubectl get ns
kubectl -n test get deploy
```

建议使用专用 ServiceAccount，而不是管理员 kubeconfig。

## 11.3 ServiceAccount 与 RBAC

示例：给 Jenkins 一个 namespace 级发布权限。

```yaml title="jenkins-deployer-rbac.yaml"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-deployer
  namespace: test
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: jenkins-deployer
  namespace: test
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch", "patch", "update"]
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jenkins-deployer
  namespace: test
subjects:
  - kind: ServiceAccount
    name: jenkins-deployer
    namespace: test
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: jenkins-deployer
```

应用：

```bash
kubectl apply -f jenkins-deployer-rbac.yaml
```

建议：

- 按环境创建不同 ServiceAccount。
- 测试和生产 kubeconfig 分开。
- 生产发布账号不要授予集群管理员权限。

## 11.4 kubeconfig 凭据

Jenkins 凭据类型：

```text
Secret file
```

建议 ID：

```text
kubeconfig-test
kubeconfig-prod
```

Pipeline 使用：

```groovy
withCredentials([
    file(credentialsId: 'kubeconfig-test', variable: 'KUBECONFIG')
]) {
    sh 'kubectl -n test get deploy'
}
```

注意：

- kubeconfig 文件中引用的证书路径必须在 Jenkins Agent 上可用。
- 更推荐把证书内容内嵌到 kubeconfig。
- 不要把 kubeconfig 提交到代码仓库。

## 11.5 kubectl 发布示例

### 11.5.1 set image

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && kubectl'
    }

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['test', 'prod'], description: '部署环境')
        string(name: 'IMAGE', defaultValue: 'registry.example.com/devops/demo-service:latest', description: '镜像地址')
    }

    environment {
        APP_NAME = 'demo-service'
    }

    stages {
        stage('Deploy') {
            steps {
                script {
                    def config = [
                        test: [namespace: 'test', kubeconfig: 'kubeconfig-test'],
                        prod: [namespace: 'prod', kubeconfig: 'kubeconfig-prod']
                    ][params.DEPLOY_ENV]

                    if (params.DEPLOY_ENV == 'prod') {
                        input message: "确认发布 ${params.IMAGE} 到生产环境？", ok: '确认发布'
                    }

                    withCredentials([
                        file(credentialsId: config.kubeconfig, variable: 'KUBECONFIG')
                    ]) {
                        sh """
                            kubectl -n ${config.namespace} set image deployment/${APP_NAME} \
                              ${APP_NAME}=${params.IMAGE}

                            kubectl -n ${config.namespace} rollout status deployment/${APP_NAME} \
                              --timeout=300s
                        """
                    }
                }
            }
        }
    }
}
```

### 11.5.2 apply YAML

```groovy
stage('Deploy') {
    steps {
        withCredentials([
            file(credentialsId: 'kubeconfig-test', variable: 'KUBECONFIG')
        ]) {
            sh '''
                kubectl -n test apply -f k8s/
                kubectl -n test rollout status deployment/demo-service --timeout=300s
            '''
        }
    }
}
```

适合仓库中维护 Kubernetes YAML 的项目。

## 11.6 Helm 发布示例

Agent 需要安装 `helm`。

```groovy
stage('Helm Deploy') {
    steps {
        withCredentials([
            file(credentialsId: 'kubeconfig-test', variable: 'KUBECONFIG')
        ]) {
            sh '''
                helm upgrade --install demo-service ./charts/demo-service \
                  -n test \
                  --create-namespace \
                  --set image.repository=registry.example.com/devops/demo-service \
                  --set image.tag=${BUILD_NUMBER} \
                  --wait \
                  --timeout 5m
            '''
        }
    }
}
```

建议：

- Helm Chart 和 values 文件纳入版本管理。
- 不同环境使用不同 values 文件。
- 生产发布使用 `--wait` 和明确 `--timeout`。

## 11.7 Kubernetes 动态 Agent

Jenkins Kubernetes Plugin 可以为每次构建动态创建 Pod：

1. Jenkins Controller 连接 Kubernetes API。
2. Pipeline 开始时创建 Agent Pod。
3. 构建在 Pod 中执行。
4. 构建结束后删除 Pod。

优点：

- Agent 弹性伸缩。
- 构建环境镜像化。
- 不同技术栈使用不同 Pod 模板。
- 构建完成后环境自动清理。

插件：

```text
Kubernetes
```

配置入口：

```text
Manage Jenkins -> Clouds -> New cloud -> Kubernetes
```

常见配置：

| 配置项 | 说明 |
| --- | --- |
| `Kubernetes URL` | Kubernetes API 地址 |
| `Kubernetes Namespace` | Jenkins Agent Pod 所在 namespace |
| `Credentials` | 访问 Kubernetes API 的凭据 |
| `Jenkins URL` | Agent 回连 Jenkins 的地址 |
| `Jenkins tunnel` | 入站 Agent 通道，可选 |
| `Pod Labels` | Pod 标签 |

## 11.8 Pod Template 示例

### 11.8.1 Jenkinsfile 内联 Pod

```groovy title="Jenkinsfile"
pipeline {
    agent {
        kubernetes {
            label 'maven-docker-agent'
            defaultContainer 'maven'
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: maven
      image: maven:3.9-eclipse-temurin-21
      command:
        - cat
      tty: true
    - name: docker
      image: docker:27-cli
      command:
        - cat
      tty: true
'''
        }
    }

    stages {
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn -B clean package -DskipTests'
                }
            }
        }

        stage('Docker Version') {
            steps {
                container('docker') {
                    sh 'docker version'
                }
            }
        }
    }
}
```

注意：

- 上面 `docker:27-cli` 只有 Docker CLI，不包含 Docker Daemon。
- 如果需要构建镜像，可使用 Kaniko、BuildKit、Dind 或挂载宿主机 Docker。

### 11.8.2 Kaniko 构建镜像

Kaniko 适合 Kubernetes 中无 Docker Daemon 构建镜像。

```groovy title="Jenkinsfile"
pipeline {
    agent {
        kubernetes {
            defaultContainer 'kaniko'
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command:
        - /busybox/cat
      tty: true
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
  volumes:
    - name: docker-config
      secret:
        secretName: harbor-docker-config
'''
        }
    }

    environment {
        IMAGE = 'harbor.example.com/devops/demo-service'
    }

    stages {
        stage('Build Image') {
            steps {
                sh '''
                    /kaniko/executor \
                      --context "${WORKSPACE}" \
                      --dockerfile "${WORKSPACE}/Dockerfile" \
                      --destination "${IMAGE}:${BUILD_NUMBER}"
                '''
            }
        }
    }
}
```

说明：

- `harbor-docker-config` 是 Kubernetes Secret，内容为 Docker config。
- Kaniko 不依赖 Docker Daemon，适合动态 Agent。

## 11.9 动态 Agent 权限与网络

需要确认：

- Jenkins Controller 能访问 Kubernetes API。
- Agent Pod 能访问 Jenkins Controller。
- Agent Pod 能访问 GitLab、Harbor、Maven 仓库、npm 仓库等依赖源。
- Agent Pod 所在 namespace 有创建 Pod、删除 Pod、查看 Pod 日志的权限。
- 镜像拉取 Secret 配置正确。

常见 RBAC：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: jenkins-agent-manager
  namespace: jenkins
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "events"]
    verbs: ["create", "delete", "get", "list", "watch"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
```

## 11.10 常见问题

### 11.10.1 kubectl 无权限

排查：

```bash
kubectl auth can-i patch deployment -n test
kubectl auth can-i get pods -n test
```

检查：

- kubeconfig 是否正确。
- ServiceAccount 是否绑定 Role。
- namespace 是否正确。

### 11.10.2 rollout 超时

排查：

```bash
kubectl -n test describe deploy demo-service
kubectl -n test get pods -l app=demo-service
kubectl -n test describe pod <pod-name>
kubectl -n test logs <pod-name>
```

常见原因：

- 镜像拉取失败。
- 应用启动失败。
- readinessProbe 不通过。
- 资源不足无法调度。

### 11.10.3 动态 Agent Pod 启动失败

排查：

```bash
kubectl -n jenkins get pods
kubectl -n jenkins describe pod <agent-pod>
kubectl -n jenkins logs <agent-pod> -c jnlp
```

常见原因：

- 镜像拉取失败。
- PodTemplate YAML 格式错误。
- ServiceAccount 权限不足。
- Agent 无法连接 Jenkins Controller。
- Jenkins URL 或 tunnel 配置错误。

### 11.10.4 Kaniko 推送失败

排查方向：

- Docker config Secret 是否正确。
- Harbor 证书是否可信。
- Robot Account 是否有 Push 权限。
- 镜像路径项目名是否正确。

## 11.11 参考资料

- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Jenkins Kubernetes Pipeline Steps](https://www.jenkins.io/doc/pipeline/steps/kubernetes/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Helm 官方文档](https://helm.sh/docs/)
- [Kaniko 项目文档](https://github.com/GoogleContainerTools/kaniko)
