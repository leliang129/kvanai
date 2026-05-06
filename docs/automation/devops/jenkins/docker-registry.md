---
title: Jenkins Docker 镜像构建与 Registry 集成
sidebar_position: 10
---

# Jenkins Docker 镜像构建与 Registry 集成


## 10.1 集成目标

Jenkins 构建 Docker 镜像并推送到 Harbor、Docker Registry、GitLab Container Registry 或云厂商镜像仓库，是 CI/CD 中最常见的流程之一。

典型流程：

1. Jenkins 拉取代码。
2. 执行单元测试和构建。
3. 使用 Dockerfile 构建镜像。
4. 登录镜像仓库。
5. 推送镜像。
6. 将镜像地址传给部署阶段。

常见镜像仓库：

| 仓库 | 说明 |
| --- | --- |
| Harbor | 企业内部最常见，支持项目、机器人账号、漏洞扫描、复制策略 |
| Docker Registry | 官方轻量级 Registry |
| GitLab Container Registry | GitLab 内置镜像仓库 |
| Docker Hub | 公共镜像仓库 |
| 云厂商 Registry | 阿里云 ACR、腾讯云 TCR、AWS ECR 等 |

## 10.2 Jenkins Agent 准备

构建镜像的 Agent 需要具备：

- Docker CLI。
- 可访问 Docker Daemon。
- 可访问镜像仓库网络。
- 有足够磁盘空间保存镜像层和构建缓存。

检查命令：

```bash
docker version
docker info
docker login registry.example.com
```

常见 Agent 方式：

| 方式 | 说明 |
| --- | --- |
| VM / 物理机安装 Docker | 简单直接，适合固定 Agent |
| Docker in Docker | 容器内启动 Docker Daemon，隔离较好 |
| 挂载宿主机 `/var/run/docker.sock` | 使用宿主机 Docker，方便但安全风险高 |
| Kaniko / Buildah / BuildKit | 无 Docker Daemon 构建，适合 Kubernetes |

注意：

- 挂载 `/var/run/docker.sock` 等同于给容器宿主机高权限，生产环境要谨慎。
- 多团队共享 Agent 时，建议按团队或环境隔离构建节点。

## 10.3 Harbor 准备

Harbor 推荐使用 Robot Account 给 Jenkins 推送镜像。

Harbor 配置入口：

```text
Project -> Robot Accounts -> New Robot Account
```

常用权限：

| 权限 | 说明 |
| --- | --- |
| `Push Repository` | 推送镜像 |
| `Pull Repository` | 拉取镜像 |
| `Read Artifact` | 读取制品 |
| `Delete Artifact` | 删除制品，生产慎开 |

建议：

- 每个项目单独创建 Robot Account。
- Robot Account 只授予对应项目权限。
- 密码保存到 Jenkins Credentials。
- 定期轮换 Robot Account Secret。

Jenkins 凭据：

```text
Type: Username with password
ID: harbor-robot-demo
Username: robot$demo+jenkins
Password: Harbor Robot Secret
```

## 10.4 镜像标签规范

不建议只使用 `latest`，因为难以追踪和回滚。

推荐标签：

| 标签 | 示例 | 说明 |
| --- | --- | --- |
| 构建号 | `1024` | Jenkins 构建号 |
| Git Commit | `a1b2c3d4` | 可追溯源码 |
| 分支 + Commit | `main-a1b2c3d4` | 多分支构建 |
| 版本号 | `v1.2.0` | 发布版本 |
| 环境标签 | `test-1024` | 环境区分 |

推荐组合：

```text
registry.example.com/devops/demo-service:main-a1b2c3d4-1024
```

Jenkinsfile 生成示例：

```groovy
script {
    def branch = env.BRANCH_NAME ?: 'main'
    def safeBranch = branch.replaceAll('/', '-')
    def shortCommit = env.GIT_COMMIT ? env.GIT_COMMIT.take(8) : env.BUILD_NUMBER

    env.IMAGE_TAG = "${safeBranch}-${shortCommit}-${env.BUILD_NUMBER}"
    env.IMAGE = "${env.REGISTRY}/${env.PROJECT}/${env.APP_NAME}:${env.IMAGE_TAG}"
}
```

## 10.5 Dockerfile 示例

### 10.5.1 Java 应用

```dockerfile title="Dockerfile"
FROM eclipse-temurin:21-jre

WORKDIR /app
COPY target/demo-service.jar /app/app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

### 10.5.2 Node.js 前端

```dockerfile title="Dockerfile"
FROM nginx:1.27-alpine

COPY dist/ /usr/share/nginx/html/

EXPOSE 80
```

### 10.5.3 多阶段构建

```dockerfile title="Dockerfile"
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /src
COPY pom.xml .
COPY src ./src
RUN mvn -B clean package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=builder /src/target/*.jar /app/app.jar
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

建议：

- 使用明确基础镜像版本，不要长期使用浮动 tag。
- `.dockerignore` 排除无关文件。
- 不把 `.git`、密钥、配置文件复制进镜像。
- 应用配置通过环境变量、ConfigMap、Secret 注入。

## 10.6 Jenkinsfile 示例

### 10.6.1 构建并推送 Harbor

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && docker'
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        REGISTRY = 'harbor.example.com'
        PROJECT = 'devops'
        APP_NAME = 'demo-service'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build App') {
            steps {
                sh 'mvn -B clean package -DskipTests'
            }
        }

        stage('Generate Image Tag') {
            steps {
                script {
                    def branch = env.BRANCH_NAME ?: 'main'
                    def safeBranch = branch.replaceAll('/', '-')
                    def shortCommit = env.GIT_COMMIT ? env.GIT_COMMIT.take(8) : env.BUILD_NUMBER

                    env.IMAGE_TAG = "${safeBranch}-${shortCommit}-${env.BUILD_NUMBER}"
                    env.IMAGE = "${env.REGISTRY}/${env.PROJECT}/${env.APP_NAME}:${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build Image') {
            steps {
                sh 'docker build -t "${IMAGE}" .'
            }
        }

        stage('Push Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'harbor-robot-demo',
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASS'
                    )
                ]) {
                    sh '''
                        echo "${REGISTRY_PASS}" | docker login "${REGISTRY}" \
                          -u "${REGISTRY_USER}" --password-stdin
                        docker push "${IMAGE}"
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout "${REGISTRY}" || true'
            cleanWs()
        }
    }
}
```

### 10.6.2 同时推送 latest

```groovy
stage('Build Image') {
    steps {
        sh '''
            docker build \
              -t "${IMAGE}" \
              -t "${REGISTRY}/${PROJECT}/${APP_NAME}:latest" \
              .
        '''
    }
}

stage('Push Image') {
    steps {
        sh '''
            docker push "${IMAGE}"
            docker push "${REGISTRY}/${PROJECT}/${APP_NAME}:latest"
        '''
    }
}
```

说明：

- `latest` 只能作为辅助标签，不应作为生产发布唯一依据。
- 生产部署应使用不可变标签，如 Commit SHA 或版本号。

## 10.7 GitLab Container Registry

GitLab 镜像仓库地址通常为：

```text
gitlab.example.com/group/project
```

Jenkins 凭据可以使用：

- GitLab Username + Personal Access Token。
- Project Access Token。
- Deploy Token。

Jenkinsfile 示例：

```groovy
environment {
    REGISTRY = 'gitlab.example.com'
    IMAGE = 'gitlab.example.com/devops/demo-service'
}

stage('Push Image') {
    steps {
        withCredentials([
            usernamePassword(
                credentialsId: 'gitlab-registry-token',
                usernameVariable: 'REGISTRY_USER',
                passwordVariable: 'REGISTRY_PASS'
            )
        ]) {
            sh '''
                echo "${REGISTRY_PASS}" | docker login "${REGISTRY}" \
                  -u "${REGISTRY_USER}" --password-stdin
                docker build -t "${IMAGE}:${BUILD_NUMBER}" .
                docker push "${IMAGE}:${BUILD_NUMBER}"
            '''
        }
    }
}
```

## 10.8 缓存与加速

常见优化方式：

- 使用 `.dockerignore` 减少上下文。
- Dockerfile 中把变化少的步骤放前面。
- 使用镜像仓库代理缓存基础镜像。
- 使用 BuildKit。
- 固定 Agent 保留本地 Docker layer cache。

启用 BuildKit：

```groovy
environment {
    DOCKER_BUILDKIT = '1'
}
```

构建示例：

```bash
docker build --pull -t "${IMAGE}" .
```

说明：

- `--pull` 会尝试拉取最新基础镜像。
- 如果追求完全可复现，基础镜像应固定 digest。

## 10.9 镜像扫描与质量门禁

Harbor 支持集成 Trivy 等扫描器。常见策略：

- 镜像推送后由 Harbor 自动扫描。
- Jenkins 调用 Harbor API 查询扫描结果。
- 使用 Trivy 在 Jenkins 构建阶段扫描。

Trivy 示例：

```groovy
stage('Scan Image') {
    steps {
        sh '''
            trivy image \
              --exit-code 1 \
              --severity HIGH,CRITICAL \
              "${IMAGE}"
        '''
    }
}
```

建议：

- 测试环境可以先只告警。
- 生产发布建议阻断 Critical 漏洞。
- 基础镜像要定期更新。

## 10.10 清理策略

Jenkins Agent 清理：

```bash
docker system df
docker image prune -f
docker builder prune -f
```

谨慎使用：

```bash
docker system prune -af --volumes
```

Harbor 清理：

- 配置 Retention Policy。
- 定期执行 Garbage Collection。
- 保留正式版本和最近 N 个构建版本。

建议：

- 不在每次构建后无差别清理全部镜像，否则会失去缓存。
- 磁盘紧张的共享 Agent 要配置定时清理。
- Harbor 清理策略要和回滚策略一致。

## 10.11 常见问题

### 10.11.1 docker: permission denied

原因：

- Jenkins 用户没有访问 Docker Daemon 权限。
- Agent 容器没有挂载 Docker socket。
- Docker 服务未启动。

排查：

```bash
id jenkins
ls -l /var/run/docker.sock
systemctl status docker
```

### 10.11.2 docker login 失败

排查方向：

- Registry 地址是否正确。
- 凭据用户名密码是否正确。
- Harbor Robot Account 是否过期。
- Jenkins Agent 是否能访问 Registry。
- HTTPS 证书是否可信。

### 10.11.3 push denied

常见原因：

- Robot Account 没有 Push 权限。
- Harbor 项目不存在。
- 镜像路径项目名写错。
- Registry 开启不可覆盖 tag 策略。

### 10.11.4 构建很慢

优化方向：

- 减小构建上下文。
- 优化 Dockerfile 层顺序。
- 使用缓存节点或 BuildKit。
- 基础镜像配置内网代理。
- 避免每次构建都清空缓存。

### 10.11.5 no space left on device

处理：

```bash
docker system df
docker image prune -f
docker builder prune -f
df -h
du -sh /var/lib/docker/*
```

长期方案：

- 扩容 Docker 数据盘。
- 定时清理旧镜像。
- Harbor 和 Jenkins Agent 分别配置清理策略。

## 10.12 参考资料

- [Docker Build 官方文档](https://docs.docker.com/build/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Harbor 官方文档](https://goharbor.io/docs/)
- [Jenkins Credentials Binding Plugin](https://plugins.jenkins.io/credentials-binding/)
