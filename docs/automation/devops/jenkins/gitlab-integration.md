---
title: Jenkins 集成 GitLab
sidebar_position: 6
---

# Jenkins 集成 GitLab


## 6.1 集成目标

Jenkins 集成 GitLab 后，可以实现从代码提交到自动构建、测试、镜像构建、部署发布的完整链路。

常见目标：

- Jenkins 拉取 GitLab 仓库代码。
- GitLab Push 自动触发 Jenkins 构建。
- GitLab Merge Request 自动触发 Jenkins 构建。
- Jenkins 构建状态回写 GitLab Commit 或 Merge Request。
- Jenkins 根据分支、Tag、Merge Request 执行不同流水线逻辑。

常见集成方式：

| 方式 | 说明 | 适用场景 |
| --- | --- | --- |
| GitLab Webhook + Jenkins GitLab Plugin | GitLab 事件触发 Jenkins Job | 普通 Pipeline、Freestyle |
| GitLab Project Integration: Jenkins | GitLab 项目内配置 Jenkins 服务 | 希望 GitLab 侧统一管理集成 |
| Multibranch Pipeline + GitLab Branch Source | Jenkins 自动发现分支/MR | 多分支、多 MR 项目 |
| 仅使用 Git 凭据拉代码 | Jenkins 定时或手动构建 | 不需要 Webhook 触发 |

生产环境建议优先使用 Pipeline 或 Multibranch Pipeline，并将构建逻辑放入代码仓库中的 `Jenkinsfile`。

## 6.2 插件准备

Jenkins 推荐安装插件：

- `Git`
- `GitLab`
- `GitLab API`
- `GitLab Branch Source`
- `Git Parameter`
- `Pipeline`
- `Credentials Binding`
- `Multibranch Scan Webhook Trigger`（可选）

插件管理入口：

```text
Manage Jenkins -> Plugins
```

说明：

- 普通 Pipeline 触发 GitLab Webhook，通常使用 `GitLab` 插件。
- Multibranch Pipeline 自动发现 GitLab 分支/MR，通常使用 `GitLab Branch Source` 插件。
- 需要在构建页面动态选择 Git 分支、Tag 时，可以安装 `Git Parameter` 插件。
- 凭据统一放在 Jenkins Credentials 中，不要写在 Jenkinsfile 里。

## 6.3 GitLab Token 准备

### 6.3.1 Token 类型

常见 Token 类型：

| 类型 | 说明 | 适用场景 |
| --- | --- | --- |
| Personal Access Token | 用户级 Token | 管理方便，但和个人账号绑定 |
| Project Access Token | 项目级 Token | 推荐给单项目集成使用 |
| Group Access Token | 组级 Token | 多项目统一集成 |

建议：

- 生产环境优先使用 Project Access Token 或 Group Access Token。
- Token 权限按最小权限授予。
- Token 设置过期时间，并建立轮换机制。

### 6.3.2 常用权限

常见权限范围：

| 权限 | 用途 |
| --- | --- |
| `read_repository` | Jenkins 拉取代码 |
| `read_api` | Jenkins 查询项目信息、分支、MR |
| `api` | 状态回写、评论 MR、部分插件操作 |

如果只是使用 Git HTTP 拉代码，通常 `read_repository` 即可。如果需要 Jenkins 回写构建状态或评论 Merge Request，通常需要 `api` 权限。

## 6.4 Jenkins 凭据配置

配置入口：

```text
Manage Jenkins -> Credentials
```

### 6.4.1 HTTP Token 凭据

适合 GitLab HTTP/HTTPS 仓库地址。

凭据类型：

```text
Username with password
```

填写建议：

- `Username`：GitLab 用户名，或固定写 `oauth2`。
- `Password`：GitLab Access Token。
- `ID`：如 `gitlab-http-token`。

仓库地址示例：

```text
https://gitlab.example.com/devops/demo-service.git
```

### 6.4.2 SSH Key 凭据

适合 GitLab SSH 仓库地址。

凭据类型：

```text
SSH Username with private key
```

填写建议：

- `Username`：通常为 `git`。
- `Private Key`：Jenkins 专用私钥。
- `ID`：如 `gitlab-ssh-key`。

仓库地址示例：

```text
git@gitlab.example.com:devops/demo-service.git
```

GitLab 中需要把 Jenkins 公钥添加到：

```text
Project -> Settings -> Repository -> Deploy keys
```

或添加到专用机器人账号的 SSH Keys 中。

### 6.4.3 GitLab API Token

用于 Jenkins GitLab 插件访问 GitLab API、回写状态等。

凭据类型：

```text
GitLab API token
```

或：

```text
Secret text
```

建议 ID：

```text
gitlab-api-token
```

## 6.5 Jenkins 全局 GitLab 配置

配置入口：

```text
Manage Jenkins -> System -> GitLab
```

常见配置：

| 配置项 | 示例 |
| --- | --- |
| `Connection name` | `gitlab` |
| `GitLab host URL` | `https://gitlab.example.com` |
| `Credentials` | `gitlab-api-token` |

配置后点击：

```text
Test Connection
```

如果连接失败，重点检查：

- Jenkins 是否能访问 GitLab 地址。
- GitLab URL 是否包含正确协议和域名。
- Token 是否有效。
- GitLab 使用自签名证书时，Jenkins JVM 是否信任该证书。

## 6.6 Jenkins 拉取 GitLab 代码

### 6.6.1 Pipeline script from SCM

推荐让 Jenkins 从 GitLab 仓库读取 `Jenkinsfile`。

任务配置：

```text
Pipeline -> Definition -> Pipeline script from SCM
```

常见配置：

| 配置项 | 示例 |
| --- | --- |
| `SCM` | `Git` |
| `Repository URL` | `https://gitlab.example.com/devops/demo-service.git` |
| `Credentials` | `gitlab-http-token` |
| `Branch Specifier` | `*/main` |
| `Script Path` | `Jenkinsfile` |

### 6.6.2 Jenkinsfile 中 checkout scm

```groovy title="Jenkinsfile"
pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
    }
}
```

`checkout scm` 会使用 Jenkins Job 中配置的 SCM 信息，适合 `Pipeline script from SCM` 或 Multibranch Pipeline。

### 6.6.3 手写 checkout

```groovy title="Jenkinsfile"
pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'gitlab-http-token',
                    url: 'https://gitlab.example.com/devops/demo-service.git'
            }
        }
    }
}
```

适合简单场景，但不如 `checkout scm` 适合多分支流水线。

## 6.7 GitLab Webhook 触发 Jenkins

### 6.7.1 Jenkins Job 配置

进入 Jenkins Pipeline 任务配置：

```text
Configure -> Build Triggers
```

勾选：

```text
Build when a change is pushed to GitLab
```

常见触发事件：

- `Push Events`
- `Opened Merge Request Events`
- `Accepted Merge Request Events`
- `Closed Merge Request Events`
- `Approved Merge Requests`
- `Comments`

配置完成后，Jenkins 页面通常会显示 GitLab Webhook URL，形式类似：

```text
https://jenkins.example.com/project/demo-service
```

如果启用 Secret Token，需要复制 Jenkins 中生成或配置的 Secret Token。

### 6.7.2 GitLab Webhook 配置

GitLab 项目配置入口：

```text
Project -> Settings -> Webhooks
```

填写：

| 配置项 | 示例 |
| --- | --- |
| `URL` | `https://jenkins.example.com/project/demo-service` |
| `Secret token` | Jenkins 中配置的 Secret Token |
| `Trigger` | Push events、Merge request events |
| `SSL verification` | 生产环境建议开启 |

添加后点击：

```text
Test -> Push events
```

如果返回 `200` 或 `201`，说明 GitLab 能正常请求 Jenkins。

## 6.8 GitLab Project Integration: Jenkins

GitLab 也提供项目级 Jenkins 集成入口：

```text
Project -> Settings -> Integrations -> Jenkins
```

常见配置：

| 配置项 | 说明 |
| --- | --- |
| `Jenkins URL` | Jenkins 服务地址 |
| `Project name` | Jenkins Job 名称 |
| `Username` | Jenkins 用户 |
| `Password or token` | Jenkins API Token |
| `Push events` | Push 触发构建 |
| `Merge request events` | MR 触发构建 |

适用场景：

- 希望在 GitLab 项目内统一管理 Jenkins 集成。
- 希望 GitLab 页面展示 Jenkins 构建状态。
- Jenkins 可以被 GitLab 直接访问。

注意：

- GitLab 必须能访问 Jenkins URL。
- Jenkins 用户需要有触发 Job 的权限。
- Jenkins Job 名称、Folder 路径要填写正确。

## 6.9 Pipeline 状态回写 GitLab

### 6.9.1 gitlabCommitStatus

`gitlabCommitStatus` 可以将阶段状态回写到 GitLab。

```groovy title="Jenkinsfile"
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                gitlabCommitStatus(name: 'build') {
                    sh 'mvn -B clean package -DskipTests'
                }
            }
        }

        stage('Test') {
            steps {
                gitlabCommitStatus(name: 'test') {
                    sh 'mvn -B test'
                }
            }
        }
    }
}
```

### 6.9.2 gitlabBuilds

`gitlabBuilds` 用于提前声明多个构建状态，避免 GitLab 只看到部分状态。

```groovy title="Jenkinsfile"
pipeline {
    agent any

    options {
        gitLabConnection('gitlab')
    }

    stages {
        stage('CI') {
            steps {
                gitlabBuilds(builds: ['build', 'test']) {
                    gitlabCommitStatus(name: 'build') {
                        sh 'mvn -B clean package -DskipTests'
                    }

                    gitlabCommitStatus(name: 'test') {
                        sh 'mvn -B test'
                    }
                }
            }
        }
    }
}
```

说明：

- `gitLabConnection('gitlab')` 中的名称需要和 Jenkins 全局 GitLab Connection 名称一致。
- 如果状态没有回写，优先检查 Jenkins 全局 GitLab 配置和 Token 权限。

## 6.10 Merge Request 流水线示例

目标：

- Merge Request 只执行构建和测试。
- `main` 分支才构建镜像并部署。
- 构建状态回写 GitLab。

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && docker'
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        gitLabConnection('gitlab')
    }

    environment {
        APP_NAME = 'demo-service'
        REGISTRY = 'registry.example.com'
        IMAGE_REPO = "${REGISTRY}/devops/${APP_NAME}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                gitlabCommitStatus(name: 'build') {
                    sh 'mvn -B clean package -DskipTests'
                }
            }
        }

        stage('Test') {
            steps {
                gitlabCommitStatus(name: 'test') {
                    sh 'mvn -B test'
                }
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Docker Build') {
            when {
                allOf {
                    branch 'main'
                    not {
                        changeRequest()
                    }
                }
            }
            steps {
                script {
                    env.IMAGE = "${env.IMAGE_REPO}:${env.BUILD_NUMBER}"
                }
                sh 'docker build -t "${IMAGE}" .'
            }
        }

        stage('Docker Push') {
            when {
                allOf {
                    branch 'main'
                    not {
                        changeRequest()
                    }
                }
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-registry',
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
            cleanWs()
        }
    }
}
```

## 6.11 Multibranch Pipeline

Multibranch Pipeline 适合自动发现分支和 Merge Request。

创建入口：

```text
New Item -> Multibranch Pipeline
```

常见配置：

```text
Branch Sources -> GitLab Project
```

配置项：

| 配置项 | 示例 |
| --- | --- |
| `Server` | Jenkins 全局 GitLab 连接 |
| `Credentials` | GitLab API Token |
| `Owner` | Group 或 User |
| `Projects` | 目标项目 |
| `Behaviors` | Discover branches、Discover merge requests |
| `Script Path` | `Jenkinsfile` |

常见发现策略：

- 发现所有分支。
- 只发现包含 Jenkinsfile 的分支。
- 发现 Origin MR。
- 发现 Fork MR。

建议：

- 大型 GitLab 实例不要无节制扫描整个 Group。
- 使用明确的项目范围和分支过滤规则。
- MR 构建只做编译、测试、扫描，不直接部署生产。

## 6.12 常用环境变量

不同插件、不同 Job 类型中环境变量可能不同，实际以构建日志中的 `printenv` 为准。

常见变量：

| 变量 | 说明 |
| --- | --- |
| `BRANCH_NAME` | 当前分支名，Multibranch 常见 |
| `CHANGE_ID` | Merge Request / Change Request ID |
| `CHANGE_TARGET` | MR 目标分支 |
| `CHANGE_BRANCH` | MR 源分支 |
| `GIT_COMMIT` | 当前提交 SHA |
| `GIT_BRANCH` | Git 插件提供的分支名 |
| `gitlabSourceBranch` | GitLab 插件可能提供的源分支 |
| `gitlabTargetBranch` | GitLab 插件可能提供的目标分支 |
| `gitlabMergeRequestIid` | GitLab MR IID |

调试环境变量：

```groovy
stage('Debug Env') {
    steps {
        sh 'printenv | sort'
    }
}
```

生产流水线中不建议长期保留完整 `printenv`，避免泄露环境信息。

## 6.13 常见问题

### 6.13.1 GitLab Webhook 返回 403

常见原因：

- Jenkins Job 没有启用 GitLab 触发器。
- Secret Token 不一致。
- Jenkins 安全策略、CSRF、反向代理拦截。
- GitLab 请求的 URL 不是 Jenkins 插件提供的 Webhook URL。

处理方式：

- 复制 Jenkins Job 页面中显示的 Webhook URL。
- 检查 GitLab Webhook Secret Token。
- 查看 Jenkins 系统日志和 Job 构建记录。

### 6.13.2 GitLab Webhook 测试超时

排查方向：

- GitLab 服务器是否能访问 Jenkins 域名和端口。
- Jenkins 是否在内网，GitLab 是否无路由。
- Nginx 反向代理是否转发到 Jenkins。
- HTTPS 证书是否被 GitLab 信任。
- 防火墙、安全组是否放行。

### 6.13.3 Jenkins 拉代码失败

常见原因：

- 仓库 URL 写错。
- Jenkins 凭据类型不匹配。
- Token 缺少 `read_repository` 权限。
- SSH 公钥没有添加到 GitLab。
- Jenkins Agent 无法解析或访问 GitLab 域名。

排查命令：

```bash
git ls-remote https://gitlab.example.com/devops/demo-service.git
ssh -T git@gitlab.example.com
```

### 6.13.4 状态无法回写 GitLab

排查方向：

- Jenkins 全局 GitLab Connection 是否配置正确。
- `gitLabConnection('gitlab')` 名称是否一致。
- Token 是否有 `api` 权限。
- Jenkins 构建是否能拿到正确的 Git Commit SHA。
- GitLab 项目是否允许外部状态回写。

### 6.13.5 Merge Request 不触发

排查方向：

- GitLab Webhook 是否勾选 `Merge request events`。
- Jenkins Job 触发器是否启用 MR 相关事件。
- Multibranch 是否配置 Discover merge requests。
- Jenkinsfile 是否存在于源分支或目标分支。
- 分支过滤规则是否排除了 MR 分支。

### 6.13.6 自签名证书问题

如果 GitLab 使用自签名证书，Jenkins 访问 GitLab API 或 Git 仓库时可能失败。

处理方式：

- 生产环境建议使用权威 CA 证书。
- 自签名证书需要导入 Jenkins Controller 和 Agent 的系统信任。
- Java 进程访问 GitLab API 时，还可能需要导入 JVM truststore。

## 6.14 安全建议

- Jenkins 和 GitLab 之间统一使用 HTTPS。
- GitLab Token 使用最小权限，设置过期时间并定期轮换。
- Jenkins API Token 不要使用管理员账号，建议使用专用机器人账号。
- Webhook Secret Token 必须配置，避免任意请求触发构建。
- MR 流水线不要直接使用生产凭据。
- Fork MR 构建要特别谨慎，避免不可信代码读取 Jenkins 凭据。
- Jenkinsfile 中不要打印 Token、密码、私钥、完整环境变量。

## 6.15 参考资料

- [GitLab Jenkins 集成文档](https://docs.gitlab.com/ee/integration/jenkins.html)
- [Jenkins GitLab Plugin](https://plugins.jenkins.io/gitlab-plugin)
- [Jenkins GitLab Plugin Pipeline Steps](https://www.jenkins.io/doc/pipeline/steps/gitlab-plugin/)
- [GitLab External Commit Statuses](https://docs.gitlab.com/ci/ci_cd_for_external_repos/external_commit_statuses/)
