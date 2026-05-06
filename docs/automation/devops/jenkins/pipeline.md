---
title: Jenkins Pipeline 与 Jenkinsfile
sidebar_position: 2
---

# Jenkins Pipeline 与 Jenkinsfile


## 2.1 Pipeline 介绍

Jenkins Pipeline 是 Jenkins 的流水线能力，用代码描述构建、测试、扫描、打包、发布等流程。通常将流水线定义在代码仓库根目录的 `Jenkinsfile` 中，由 Jenkins 从源码仓库读取并执行。

Pipeline 的核心价值：

- 流程即代码，构建逻辑可以和业务代码一起版本管理。
- 支持参数化、条件判断、并行执行、人工确认、失败通知等发布控制能力。
- 可以复用凭据、工具链、Agent 节点和共享库。
- 适合从简单 CI 扩展到标准化 CD 发布流程。

Jenkins Pipeline 常见语法分为两类：

| 类型 | 说明 | 建议 |
| --- | --- | --- |
| Declarative Pipeline | 声明式语法，结构清晰，约束更多 | 推荐作为团队标准 |
| Scripted Pipeline | Groovy 脚本式语法，灵活度更高 | 适合复杂逻辑或历史流水线 |

团队内建议优先使用 Declarative Pipeline，复杂逻辑再放入 `script {}` 或共享库中。

## 2.2 前置准备

### 2.2.1 推荐插件

使用 Pipeline 前建议安装以下插件：

- `Pipeline`
- `Pipeline: Declarative`
- `Git`
- `Credentials Binding`
- `Workspace Cleanup`
- `Timestamper`
- `AnsiColor`
- `Docker Pipeline`
- `GitLab`
- `SSH Agent`

插件管理入口：

```text
Manage Jenkins -> Plugins
```

### 2.2.2 创建 Pipeline 任务

普通 Pipeline 任务：

```text
New Item -> Pipeline
```

配置方式：

```text
Pipeline -> Definition -> Pipeline script from SCM
```

常用配置：

- `SCM`：选择 `Git`。
- `Repository URL`：填写代码仓库地址。
- `Credentials`：选择 Git 拉取凭据。
- `Branch Specifier`：例如 `*/main`、`*/master`、`*/develop`。
- `Script Path`：通常填写 `Jenkinsfile`。

多分支流水线：

```text
New Item -> Multibranch Pipeline
```

适合一个仓库有多个长期分支，或需要自动发现分支、标签、Merge Request 的场景。

## 2.3 Declarative Pipeline 基础结构

最小可用示例：

```groovy title="Jenkinsfile"
pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'echo "build"'
            }
        }

        stage('Test') {
            steps {
                sh 'echo "test"'
            }
        }
    }

    post {
        always {
            echo 'pipeline finished'
        }
        success {
            echo 'pipeline success'
        }
        failure {
            echo 'pipeline failed'
        }
    }
}
```

常用结构说明：

| 关键字 | 说明 |
| --- | --- |
| `pipeline` | 声明式流水线根块 |
| `agent` | 指定流水线在哪个节点或容器执行 |
| `stages` | 阶段集合 |
| `stage` | 一个具体阶段，如构建、测试、发布 |
| `steps` | 阶段内执行的具体步骤 |
| `post` | 流水线结束后的动作，如通知、清理 |
| `environment` | 定义环境变量 |
| `parameters` | 定义构建参数 |
| `options` | 定义超时、日志、并发等选项 |
| `when` | 阶段执行条件 |
| `tools` | 声明 JDK、Maven、Node.js 等全局工具 |
| `script` | 在声明式流水线中执行 Groovy 逻辑 |
| `input` | 人工确认或审批 |
| `parallel` | 并行执行多个阶段或任务 |

## 2.4 常用指令

### 2.4.1 pipeline

`pipeline` 是 Declarative Pipeline 的根块，所有声明式流水线内容都必须写在这里。

```groovy
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh 'echo build'
            }
        }
    }
}
```

常见顶层块：

| 顶层块 | 说明 |
| --- | --- |
| `agent` | 指定流水线运行节点 |
| `options` | 配置超时、日志、并发、构建保留策略 |
| `parameters` | 定义构建参数 |
| `environment` | 定义环境变量 |
| `tools` | 声明 JDK、Maven、Node.js 等工具 |
| `stages` | 定义构建阶段 |
| `post` | 定义流水线结束后的处理动作 |

### 2.4.2 stages / stage / steps

`stages` 是阶段集合，里面可以包含多个 `stage`。每个 `stage` 表示流水线中的一个阶段，例如拉代码、构建、测试、打包、部署。

```groovy
stages {
    stage('Checkout') {
        steps {
            checkout scm
        }
    }

    stage('Build') {
        steps {
            sh 'mvn -B clean package -DskipTests'
        }
    }

    stage('Test') {
        steps {
            sh 'mvn -B test'
        }
    }
}
```

使用建议：

- `stage` 名称要稳定清晰，便于在 Jenkins 页面中定位失败阶段。
- 常见阶段可以统一为 `Checkout`、`Build`、`Test`、`Scan`、`Package`、`Deploy`。
- `steps` 中直接写 Jenkins Pipeline Step，例如 `sh`、`echo`、`checkout`、`archiveArtifacts`。
- 复杂 Groovy 逻辑不要直接写在 `steps` 下，应放入 `script {}`。

### 2.4.3 script

`script` 用于在 Declarative Pipeline 中执行 Groovy 逻辑。变量处理、循环、Map 配置、动态生成任务等复杂逻辑通常放在 `script {}` 中。

```groovy
stage('Prepare') {
    steps {
        script {
            def branch = env.BRANCH_NAME ?: 'main'
            def safeBranch = branch.replaceAll('/', '-')

            env.IMAGE_TAG = "${safeBranch}-${env.BUILD_NUMBER}"
            echo "image tag: ${env.IMAGE_TAG}"
        }
    }
}
```

适合放入 `script` 的内容：

- 定义局部变量，如 `def imageTag = ...`。
- 根据参数或分支选择配置。
- 遍历服务列表。
- 生成 `parallel` 动态任务。
- 调用自定义 Groovy 方法或共享库返回值。

不建议放入 `script` 的内容：

- 简单阶段开关，优先使用 `when`。
- 固定环境变量，优先使用 `environment`。
- 构建参数定义，必须放在 `parameters`。
- 大量复杂逻辑，建议抽到脚本或 Shared Library。

### 2.4.4 agent

使用任意可用节点：

```groovy
pipeline {
    agent any
}
```

指定标签节点：

```groovy
pipeline {
    agent {
        label 'linux && docker'
    }
}
```

顶层不分配节点，按阶段指定节点：

```groovy
pipeline {
    agent none

    stages {
        stage('Build') {
            agent {
                label 'builder'
            }
            steps {
                sh 'mvn -v'
            }
        }
    }
}
```

### 2.4.5 options

常用配置：

```groovy
options {
    timestamps()
    ansiColor('xterm')
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
}
```

说明：

- `timestamps()`：日志增加时间戳。
- `ansiColor('xterm')`：支持彩色终端输出。
- `timeout`：限制流水线最长执行时间。
- `buildDiscarder`：限制历史构建数量。
- `disableConcurrentBuilds()`：禁止同一个任务并发执行，避免部署互相覆盖。

### 2.4.6 environment

定义全局环境变量：

```groovy
environment {
    APP_NAME = 'demo-service'
    IMAGE_REPO = 'registry.example.com/devops/demo-service'
}
```

在步骤中使用：

```groovy
steps {
    sh 'echo "$APP_NAME"'
    sh 'echo "$IMAGE_REPO"'
}
```

### 2.4.7 parameters

定义构建参数：

```groovy
parameters {
    string(name: 'BRANCH_NAME', defaultValue: 'main', description: '构建分支')
    choice(name: 'DEPLOY_ENV', choices: ['dev', 'test', 'prod'], description: '部署环境')
    booleanParam(name: 'SKIP_TEST', defaultValue: false, description: '是否跳过测试')
}
```

使用参数：

```groovy
steps {
    sh 'echo "branch: ${BRANCH_NAME}"'
    sh 'echo "env: ${DEPLOY_ENV}"'
}
```

在 Groovy 表达式中使用：

```groovy
when {
    expression {
        return params.DEPLOY_ENV == 'prod'
    }
}
```

如果需要在构建页面动态选择 Git 分支、Tag 或 Revision，可以安装 `Git Parameter` 插件。插件安装后可以使用 `gitParameter` 参数类型：

```groovy
parameters {
    gitParameter(
        name: 'GIT_BRANCH',
        type: 'PT_BRANCH',
        defaultValue: 'main',
        branchFilter: 'origin/(.*)',
        selectedValue: 'DEFAULT',
        sortMode: 'ASCENDING_SMART',
        description: '选择构建分支'
    )
}

stages {
    stage('Checkout') {
        steps {
            git branch: "${params.GIT_BRANCH}",
                credentialsId: 'gitlab-http-token',
                url: 'https://gitlab.example.com/devops/demo-service.git'
        }
    }
}
```

常用 `type`：

| 类型 | 说明 |
| --- | --- |
| `PT_BRANCH` | 分支 |
| `PT_TAG` | 标签 |
| `PT_BRANCH_TAG` | 分支和标签 |
| `PT_REVISION` | Revision，可能需要更多仓库扫描成本 |

注意：

- `Git Parameter` 插件依赖 Job 的 Git SCM 配置或参数中的仓库配置来获取分支/Tag。
- 分支很多的大仓库不建议无过滤使用，建议配置 `branchFilter`。
- Multibranch Pipeline 通常已经由分支发现机制决定分支，不一定需要 `gitParameter`。

### 2.4.8 when

按分支执行：

```groovy
when {
    branch 'main'
}
```

按参数执行：

```groovy
when {
    expression {
        return params.SKIP_TEST == false
    }
}
```

多个条件：

```groovy
when {
    allOf {
        branch 'main'
        expression {
            return params.DEPLOY_ENV == 'prod'
        }
    }
}
```

### 2.4.9 tools

`tools` 用于声明流水线需要的工具，例如 JDK、Maven、Gradle、Node.js。工具名称必须先在 Jenkins 全局工具配置中定义。

配置入口：

```text
Manage Jenkins -> Tools
```

示例：

```groovy
pipeline {
    agent any

    tools {
        jdk 'jdk21'
        maven 'maven-3.9'
        nodejs 'node-20'
    }

    stages {
        stage('Version') {
            steps {
                sh 'java -version'
                sh 'mvn -v'
                sh 'node -v'
            }
        }
    }
}
```

说明：

- `tools` 声明后，Jenkins 会把对应工具加入当前构建环境。
- 如果使用容器 Agent，通常更推荐把工具直接放进镜像中。
- 工具名称必须和 Jenkins 全局配置中的名称完全一致。

### 2.4.10 input

`input` 用于人工确认，常见于生产发布前的审批。

```groovy
stage('Approve Prod') {
    when {
        expression {
            return params.DEPLOY_ENV == 'prod'
        }
    }
    steps {
        timeout(time: 10, unit: 'MINUTES') {
            input message: '确认发布到生产环境？', ok: '确认发布'
        }
    }
}
```

建议：

- `input` 一定要配合 `timeout`，避免流水线长期挂起。
- 生产发布审批要结合 Jenkins 权限控制。
- 不建议在普通 CI 构建中加入人工确认，否则会影响反馈速度。

### 2.4.11 parallel

`parallel` 用于并行执行多个分支，适合测试、扫描、多个模块构建等场景。

```groovy
stage('Check') {
    parallel {
        stage('Unit Test') {
            steps {
                sh 'npm run test:unit'
            }
        }

        stage('Lint') {
            steps {
                sh 'npm run lint'
            }
        }

        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }
    }
}
```

动态并行任务需要放在 `script` 中：

```groovy
stage('Parallel Modules') {
    steps {
        script {
            def modules = ['api', 'web', 'worker']
            def tasks = [:]

            modules.each { module ->
                tasks[module] = {
                    sh "make test MODULE=${module}"
                }
            }

            parallel tasks
        }
    }
}
```

### 2.4.12 post

```groovy
post {
    always {
        cleanWs()
    }
    success {
        echo 'success'
    }
    failure {
        echo 'failure'
    }
    unstable {
        echo 'unstable'
    }
}
```

常见状态：

- `always`：无论成功失败都会执行。
- `success`：成功时执行。
- `failure`：失败时执行。
- `unstable`：测试失败或质量门禁不通过时执行。
- `changed`：本次状态与上一次不同才执行。

## 2.5 凭据使用

### 2.5.1 凭据类型

Jenkins 常见凭据类型：

| 类型 | 场景 |
| --- | --- |
| Username with password | Git、镜像仓库、HTTP API |
| SSH Username with private key | Git SSH 拉取、远程部署 |
| Secret text | Token、Webhook 密钥 |
| Secret file | kubeconfig、证书文件、配置文件 |

凭据配置入口：

```text
Manage Jenkins -> Credentials
```

建议：

- 给凭据设置清晰的 `ID`，如 `gitlab-token`、`docker-registry`、`prod-ssh-key`。
- 不要在 Jenkinsfile 中明文写密码、Token、私钥。
- 生产凭据和测试凭据分开管理。

### 2.5.2 credentials helper

Secret text 示例：

```groovy
environment {
    API_TOKEN = credentials('api-token')
}

stages {
    stage('Call API') {
        steps {
            sh '''
                curl -H "Authorization: Bearer ${API_TOKEN}" \
                  https://api.example.com/health
            '''
        }
    }
}
```

用户名密码示例：

```groovy
environment {
    REGISTRY_AUTH = credentials('docker-registry')
}

stages {
    stage('Login') {
        steps {
            sh '''
                echo "${REGISTRY_AUTH_PSW}" | docker login registry.example.com \
                  -u "${REGISTRY_AUTH_USR}" --password-stdin
            '''
        }
    }
}
```

说明：

- `credentials('docker-registry')` 如果是用户名密码类型，会生成变量：
  - `REGISTRY_AUTH`
  - `REGISTRY_AUTH_USR`
  - `REGISTRY_AUTH_PSW`

### 2.5.3 withCredentials

更推荐将凭据限制在较小作用域中：

```groovy
stage('Push Image') {
    steps {
        withCredentials([
            usernamePassword(
                credentialsId: 'docker-registry',
                usernameVariable: 'REGISTRY_USER',
                passwordVariable: 'REGISTRY_PASS'
            )
        ]) {
            sh '''
                echo "${REGISTRY_PASS}" | docker login registry.example.com \
                  -u "${REGISTRY_USER}" --password-stdin
                docker push registry.example.com/devops/demo-service:${BUILD_NUMBER}
            '''
        }
    }
}
```

SSH 私钥示例：

```groovy
stage('Deploy') {
    steps {
        withCredentials([
            sshUserPrivateKey(
                credentialsId: 'prod-ssh-key',
                keyFileVariable: 'SSH_KEY',
                usernameVariable: 'SSH_USER'
            )
        ]) {
            sh '''
                ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no \
                  "${SSH_USER}@10.0.0.10" "hostname && uptime"
            '''
        }
    }
}
```

## 2.6 常见流水线模板

### 2.6.1 Java Maven 项目

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && maven'
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    tools {
        jdk 'jdk21'
        maven 'maven-3.9'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'mvn -B clean package -DskipTests'
            }
        }

        stage('Test') {
            steps {
                sh 'mvn -B test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
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

说明：

- `tools` 中的 `jdk21`、`maven-3.9` 需要先在全局工具配置中定义。
- `junit` 用于收集测试报告。
- `archiveArtifacts` 用于归档构建产物。

### 2.6.2 Node.js 前端项目

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && node'
    }

    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    tools {
        nodejs 'node-20'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Lint') {
            steps {
                sh 'npm run lint'
            }
        }

        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'dist/**', fingerprint: true
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

### 2.6.3 Docker 镜像构建与推送

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
        APP_NAME = 'demo-service'
        REGISTRY = 'registry.example.com'
        IMAGE = "${REGISTRY}/devops/${APP_NAME}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh '''
                    docker build \
                      -t ${IMAGE}:${BUILD_NUMBER} \
                      -t ${IMAGE}:latest \
                      .
                '''
            }
        }

        stage('Push Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-registry',
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASS'
                    )
                ]) {
                    sh '''
                        echo "${REGISTRY_PASS}" | docker login ${REGISTRY} \
                          -u "${REGISTRY_USER}" --password-stdin

                        docker push ${IMAGE}:${BUILD_NUMBER}
                        docker push ${IMAGE}:latest
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout ${REGISTRY} || true'
            cleanWs()
        }
    }
}
```

注意：

- Jenkins Agent 节点需要安装 Docker，并允许 Jenkins 用户执行 Docker 命令。
- 生产环境建议镜像标签使用 `Git Commit SHA`、版本号或构建号，不建议只依赖 `latest`。

### 2.6.4 Kubernetes 发布示例

前提：

- Jenkins 已配置 `kubeconfig` 类型的 Secret file 凭据，ID 为 `kubeconfig-test`。
- Agent 节点已安装 `kubectl`。

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && kubectl'
    }

    parameters {
        string(name: 'IMAGE_TAG', defaultValue: 'latest', description: '镜像标签')
        choice(name: 'NAMESPACE', choices: ['test', 'prod'], description: '目标命名空间')
    }

    environment {
        DEPLOYMENT = 'demo-service'
        CONTAINER = 'demo-service'
        IMAGE = "registry.example.com/devops/demo-service:${params.IMAGE_TAG}"
    }

    stages {
        stage('Confirm Prod') {
            when {
                expression {
                    return params.NAMESPACE == 'prod'
                }
            }
            steps {
                input message: "确认发布到生产环境？", ok: '确认发布'
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    file(credentialsId: 'kubeconfig-test', variable: 'KUBECONFIG')
                ]) {
                    sh '''
                        kubectl -n ${NAMESPACE} set image deployment/${DEPLOYMENT} \
                          ${CONTAINER}=${IMAGE}

                        kubectl -n ${NAMESPACE} rollout status deployment/${DEPLOYMENT} \
                          --timeout=300s
                    '''
                }
            }
        }
    }
}
```

## 2.7 并行与人工确认

### 2.7.1 parallel

并行执行多个测试阶段：

```groovy
stage('Test') {
    parallel {
        stage('Unit Test') {
            steps {
                sh 'npm run test:unit'
            }
        }

        stage('Lint') {
            steps {
                sh 'npm run lint'
            }
        }

        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }
    }
}
```

适用场景：

- 单元测试、代码扫描、前端构建可并行。
- 多架构镜像构建。
- 多环境验证。

### 2.7.2 input

生产发布前增加人工确认：

```groovy
stage('Approve') {
    when {
        branch 'main'
    }
    steps {
        timeout(time: 10, unit: 'MINUTES') {
            input message: '确认发布到生产环境？', ok: '发布'
        }
    }
}
```

建议：

- `input` 必须配合 `timeout`，避免流水线长期挂起。
- 生产环境建议限制有权限的用户才能确认发布。

## 2.8 GitLab 触发 Jenkins

### 2.8.1 Webhook 触发流程

常见流程：

1. Jenkins 安装 `GitLab` 插件。
2. Jenkins 中创建 Pipeline 或 Multibranch Pipeline。
3. Jenkins 任务中启用 GitLab 触发器。
4. GitLab 项目中配置 Webhook。
5. 代码提交或 Merge Request 触发 Jenkins 构建。

GitLab Webhook 地址通常类似：

```text
http://jenkins.example.com/project/job-name
```

如果使用 Multibranch Pipeline，通常由 Jenkins 扫描分支或通过插件触发分支索引。

### 2.8.2 Jenkinsfile 分支控制

只在主分支推送镜像：

```groovy
stage('Push Image') {
    when {
        branch 'main'
    }
    steps {
        sh 'echo "push image"'
    }
}
```

Merge Request 场景只做构建和测试，不做部署：

```groovy
stage('Deploy') {
    when {
        allOf {
            branch 'main'
            not {
                changeRequest()
            }
        }
    }
    steps {
        sh 'echo "deploy"'
    }
}
```

## 2.9 编写规范建议

建议团队统一以下规范：

- 每个项目根目录放置 `Jenkinsfile`。
- 阶段名称固定使用 `Checkout`、`Build`、`Test`、`Scan`、`Package`、`Deploy`。
- 所有流水线默认配置 `timeout`、`timestamps`、`buildDiscarder`。
- 生产发布必须有参数、权限控制和人工确认。
- 敏感信息必须走 Jenkins Credentials。
- 构建产物必须有版本号或构建号，不直接覆盖历史产物。
- Docker 镜像标签建议包含 `${BUILD_NUMBER}` 和 Git Commit SHA。
- 不在 Jenkinsfile 中写复杂业务逻辑，复杂逻辑应放入脚本或共享库。
- `post { always { cleanWs() } }` 清理工作区，避免磁盘持续增长。

推荐标准骨架：

```groovy title="Jenkinsfile"
pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['dev', 'test', 'prod'], description: '部署环境')
    }

    environment {
        APP_NAME = 'demo-service'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh './build.sh'
            }
        }

        stage('Test') {
            steps {
                sh './test.sh'
            }
        }

        stage('Deploy') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                sh './deploy.sh ${DEPLOY_ENV}'
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

## 2.10 常见问题

### 2.10.1 No such DSL method

常见原因：

- 插件未安装或版本过低。
- Jenkinsfile 中步骤名称写错。
- 将 Groovy 逻辑直接写在 Declarative Pipeline 的非法位置。

处理方式：

- 在 Jenkins 内置语法生成器中检查步骤：

```text
http://jenkins.example.com/pipeline-syntax
```

- 将复杂 Groovy 逻辑放入 `script {}` 中。
- 检查插件是否安装，如 `Docker Pipeline`、`SSH Agent`。

### 2.10.2 Jenkinsfile 变量不生效

常见原因：

- Shell 单引号和双引号使用不当。
- Groovy 变量和 Shell 环境变量混用。
- `params.xxx` 和 `${xxx}` 使用场景混淆。

示例：

```groovy
steps {
    sh 'echo "$BUILD_NUMBER"'
    sh "echo '${params.DEPLOY_ENV}'"
}
```

建议：

- Shell 环境变量优先在 `sh ''' ... '''` 中使用 `$VAR`。
- Groovy 表达式优先在 `script {}` 或 `when { expression { ... } }` 中使用。

### 2.10.3 凭据无法读取

排查方向：

- 凭据 ID 是否正确。
- 凭据类型是否和绑定方式匹配。
- 当前任务是否有权限读取该凭据。
- 是否把凭据放在了错误的作用域中。

### 2.10.4 构建一直排队

排查方向：

- 是否没有可用 Agent。
- `agent label` 是否和节点标签匹配。
- 节点是否离线。
- 是否启用了 `disableConcurrentBuilds()`，上一轮构建还未结束。
- Jenkins Controller 执行器数量是否为 `0`。

### 2.10.5 工作区磁盘占满

处理方式：

- 使用 `post { always { cleanWs() } }`。
- 配置 `buildDiscarder(logRotator(...))`。
- 定期清理老旧 Job 的 workspace。
- 大文件制品上传制品库，不长期保存在 Jenkins Home。

## 2.11 参考资料

- [Jenkins Pipeline 官方文档](https://www.jenkins.io/doc/book/pipeline/)
- [Jenkins Pipeline 语法](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Using a Jenkinsfile](https://www.jenkins.io/doc/book/pipeline/jenkinsfile/)
- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/)
