---
title: Groovy 语法与 Pipeline 结合
sidebar_position: 4
---

# Groovy 语法与 Pipeline 结合


## 4.1 为什么 Jenkins Pipeline 需要 Groovy

Jenkins Pipeline 使用 Groovy 作为底层脚本语言。日常写 `Jenkinsfile` 时，大多数时候是在写 Jenkins 提供的 Pipeline DSL，但只要涉及变量处理、条件判断、循环、集合、字符串拼接、动态生成阶段、封装方法，就会用到 Groovy 语法。

可以简单理解为：

- `pipeline {}`、`stages {}`、`stage {}`、`steps {}` 是 Jenkins Pipeline DSL。
- `def`、`if`、`for`、`each`、`Map`、`List` 是常见 Groovy 语法。
- Declarative Pipeline 中，复杂 Groovy 逻辑通常放在 `script {}` 块中。

示例：

```groovy title="Jenkinsfile"
pipeline {
    agent any

    stages {
        stage('Demo') {
            steps {
                script {
                    def services = ['user-service', 'order-service']

                    services.each { service ->
                        echo "build ${service}"
                    }
                }
            }
        }
    }
}
```

其中：

- `pipeline`、`agent`、`stages`、`stage`、`steps`、`script` 属于 Pipeline DSL。
- `def services = [...]` 和 `services.each { ... }` 属于 Groovy 语法。

Groovy 基础语法说明放在 [Jenkins Groovy 使用说明](./groovy.md) 中维护。本文只保留 Pipeline 中最常见的结合方式、边界和实战示例。

## 4.2 Declarative Pipeline 中 Groovy 的边界

Declarative Pipeline 对结构有严格限制。以下写法容易报错：

```groovy
pipeline {
    agent any

    stages {
        stage('Bad') {
            steps {
                def name = 'demo'
                echo name
            }
        }
    }
}
```

应改为：

```groovy
pipeline {
    agent any

    stages {
        stage('Good') {
            steps {
                script {
                    def name = 'demo'
                    echo name
                }
            }
        }
    }
}
```

经验规则：

- `steps` 中直接写 Jenkins Step，例如 `sh`、`echo`、`checkout`。
- 变量、循环、复杂判断、方法调用放入 `script {}`。
- 阶段级条件优先使用 `when`。
- 全局固定值优先放在 `environment`。
- 构建输入优先放在 `parameters`。

## 4.3 Groovy 与 Pipeline 常用组合

### 4.3.1 根据分支生成镜像标签

```groovy title="Jenkinsfile"
pipeline {
    agent any

    environment {
        APP_NAME = 'demo-service'
        REGISTRY = 'registry.example.com'
    }

    stages {
        stage('Generate Image Tag') {
            steps {
                script {
                    def branch = env.BRANCH_NAME ?: 'main'
                    def safeBranch = branch.replaceAll('/', '-')
                    def shortCommit = env.GIT_COMMIT ? env.GIT_COMMIT.take(8) : env.BUILD_NUMBER

                    env.IMAGE_TAG = "${safeBranch}-${shortCommit}"
                    env.IMAGE = "${env.REGISTRY}/devops/${env.APP_NAME}:${env.IMAGE_TAG}"

                    echo "image: ${env.IMAGE}"
                }
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t "${IMAGE}" .'
            }
        }
    }
}
```

### 4.3.2 根据环境选择部署配置

```groovy title="Jenkinsfile"
pipeline {
    agent any

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['dev', 'test', 'prod'], description: '部署环境')
    }

    stages {
        stage('Select Config') {
            steps {
                script {
                    def configs = [
                        dev : [namespace: 'dev', domain: 'dev.example.com'],
                        test: [namespace: 'test', domain: 'test.example.com'],
                        prod: [namespace: 'prod', domain: 'example.com']
                    ]

                    def config = configs[params.DEPLOY_ENV]

                    if (config == null) {
                        error "unknown deploy env: ${params.DEPLOY_ENV}"
                    }

                    env.NAMESPACE = config.namespace
                    env.DOMAIN = config.domain
                }
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    echo "deploy to namespace: ${NAMESPACE}"
                    echo "domain: ${DOMAIN}"
                '''
            }
        }
    }
}
```

### 4.3.3 动态生成并行任务

```groovy title="Jenkinsfile"
pipeline {
    agent any

    stages {
        stage('Parallel Test') {
            steps {
                script {
                    def modules = ['api', 'web', 'worker']
                    def tasks = [:]

                    modules.each { module ->
                        tasks[module] = {
                            sh "echo test ${module}"
                            sh "make test MODULE=${module}"
                        }
                    }

                    parallel tasks
                }
            }
        }
    }
}
```

说明：

- `tasks` 是一个 Map。
- key 是并行分支名称。
- value 是具体执行步骤代码块。

### 4.3.4 根据变更文件决定是否构建

适合单仓库多模块项目：

```groovy title="Jenkinsfile"
pipeline {
    agent any

    stages {
        stage('Detect Changes') {
            steps {
                script {
                    def changedFiles = sh(
                        script: 'git diff --name-only HEAD~1 HEAD',
                        returnStdout: true
                    ).trim().split('\n') as List

                    env.BUILD_WEB = changedFiles.any { it.startsWith('web/') }.toString()
                    env.BUILD_API = changedFiles.any { it.startsWith('api/') }.toString()

                    echo "build web: ${env.BUILD_WEB}"
                    echo "build api: ${env.BUILD_API}"
                }
            }
        }

        stage('Build Web') {
            when {
                expression {
                    return env.BUILD_WEB == 'true'
                }
            }
            steps {
                sh 'echo build web'
            }
        }

        stage('Build API') {
            when {
                expression {
                    return env.BUILD_API == 'true'
                }
            }
            steps {
                sh 'echo build api'
            }
        }
    }
}
```

注意：

- `sh(returnStdout: true)` 返回字符串。
- `.trim().split('\n')` 可以转为文件列表。
- 写入 `env.xxx` 后，后续 `when` 可以读取。

### 4.3.5 凭据与 Groovy 变量结合

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && docker'
    }

    environment {
        REGISTRY = 'registry.example.com'
        IMAGE = 'registry.example.com/devops/demo-service'
    }

    stages {
        stage('Push') {
            steps {
                script {
                    def tag = env.BUILD_NUMBER
                    def fullImage = "${env.IMAGE}:${tag}"

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'docker-registry',
                            usernameVariable: 'REGISTRY_USER',
                            passwordVariable: 'REGISTRY_PASS'
                        )
                    ]) {
                        sh """
                            docker build -t ${fullImage} .
                            echo "\${REGISTRY_PASS}" | docker login ${REGISTRY} \
                              -u "\${REGISTRY_USER}" --password-stdin
                            docker push ${fullImage}
                        """
                    }
                }
            }
        }
    }
}
```

注意：

- `fullImage` 是 Groovy 变量，需要 Groovy 插值。
- `REGISTRY_PASS` 是凭据注入的 Shell 环境变量，在双引号 Groovy 字符串中要写成 `\${REGISTRY_PASS}`，避免被 Groovy 提前解析。
- 涉及密码时不要 `echo` 到日志，示例中只通过管道传给 `docker login`。

## 4.4 Groovy 语法常见坑

### 4.4.1 Groovy 变量和 Shell 变量混淆

错误示例：

```groovy
script {
    def image = 'demo-service:latest'
    sh '''
        docker push ${image}
    '''
}
```

问题：

- 三单引号中的 `${image}` 不会被 Groovy 插值。
- Shell 中也没有名为 `image` 的环境变量。

修复方式一：使用 Groovy 插值。

```groovy
script {
    def image = 'demo-service:latest'
    sh """
        docker push ${image}
    """
}
```

修复方式二：写入环境变量。

```groovy
script {
    env.IMAGE = 'demo-service:latest'
}

sh '''
    docker push "${IMAGE}"
'''
```

### 4.4.2 params 和 env 混用

```groovy
parameters {
    choice(name: 'DEPLOY_ENV', choices: ['dev', 'test'], description: '部署环境')
}
```

读取参数：

```groovy
script {
    echo "deploy env: ${params.DEPLOY_ENV}"
}
```

如果 Shell 中要使用：

```groovy
script {
    env.DEPLOY_ENV_VALUE = params.DEPLOY_ENV
}

sh 'echo "${DEPLOY_ENV_VALUE}"'
```

说明：

- `params.DEPLOY_ENV` 是 Jenkins 参数对象。
- `env.DEPLOY_ENV_VALUE` 是环境变量，Shell 可以直接读取。

### 4.4.3 Declarative 区域不能随意写 Groovy

错误示例：

```groovy
pipeline {
    agent any

    def name = 'demo'

    stages {
        stage('Build') {
            steps {
                echo name
            }
        }
    }
}
```

修复方式：

```groovy
def name = 'demo'

pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                echo name
            }
        }
    }
}
```

或：

```groovy
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                script {
                    def name = 'demo'
                    echo name
                }
            }
        }
    }
}
```

### 4.4.4 env 中只能稳定保存字符串

```groovy
script {
    env.REPLICAS = 3
}
```

建议改成：

```groovy
script {
    env.REPLICAS = 3.toString()
}
```

读取时如需数字：

```groovy
script {
    def replicas = env.REPLICAS as Integer
    echo "next replicas: ${replicas + 1}"
}
```

### 4.4.5 JSON/YAML 处理

如果安装了 Pipeline Utility Steps 插件，可以用结构化方法读写文件。

读取 JSON：

```groovy
script {
    def config = readJSON file: 'deploy.json'
    echo "app: ${config.appName}"
}
```

读取 YAML：

```groovy
script {
    def values = readYaml file: 'values.yaml'
    echo "image: ${values.image.repository}"
}
```

建议：

- 不要用大量 `grep`、`sed` 拼复杂配置。
- 能用 `readJSON`、`readYaml` 就用结构化读取。

## 4.5 完整示例：Maven + Docker + Kubernetes

下面示例展示 Groovy 语法和 Pipeline DSL 的结合：

- 使用 `parameters` 接收部署环境。
- 使用 `Map` 维护环境配置。
- 使用 Groovy 生成镜像标签。
- 使用凭据登录镜像仓库。
- 使用 `when` 控制生产发布确认。
- 使用 kubeconfig 发布 Kubernetes。

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && docker && kubectl'
    }

    options {
        timestamps()
        timeout(time: 40, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['dev', 'test', 'prod'], description: '部署环境')
        booleanParam(name: 'SKIP_TEST', defaultValue: false, description: '是否跳过测试')
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

        stage('Prepare') {
            steps {
                script {
                    def configs = [
                        dev : [namespace: 'dev', kubeconfig: 'kubeconfig-dev'],
                        test: [namespace: 'test', kubeconfig: 'kubeconfig-test'],
                        prod: [namespace: 'prod', kubeconfig: 'kubeconfig-prod']
                    ]

                    def config = configs[params.DEPLOY_ENV]
                    if (config == null) {
                        error "unknown deploy env: ${params.DEPLOY_ENV}"
                    }

                    def branch = env.BRANCH_NAME ?: 'main'
                    def safeBranch = branch.replaceAll('/', '-')
                    def shortCommit = env.GIT_COMMIT ? env.GIT_COMMIT.take(8) : env.BUILD_NUMBER

                    env.K8S_NAMESPACE = config.namespace
                    env.KUBECONFIG_CREDENTIALS_ID = config.kubeconfig
                    env.IMAGE_TAG = "${safeBranch}-${shortCommit}-${env.BUILD_NUMBER}"
                    env.IMAGE = "${env.IMAGE_REPO}:${env.IMAGE_TAG}"

                    echo "deploy env: ${params.DEPLOY_ENV}"
                    echo "namespace: ${env.K8S_NAMESPACE}"
                    echo "image: ${env.IMAGE}"
                }
            }
        }

        stage('Build') {
            steps {
                sh 'mvn -B clean package -DskipTests'
            }
        }

        stage('Test') {
            when {
                expression {
                    return params.SKIP_TEST == false
                }
            }
            steps {
                sh 'mvn -B test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
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

        stage('Approve Prod') {
            when {
                expression {
                    return params.DEPLOY_ENV == 'prod'
                }
            }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input message: "确认发布 ${IMAGE} 到生产环境？", ok: '确认发布'
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: 'KUBECONFIG')
                ]) {
                    sh '''
                        kubectl -n "${K8S_NAMESPACE}" set image deployment/"${APP_NAME}" \
                          "${APP_NAME}"="${IMAGE}"

                        kubectl -n "${K8S_NAMESPACE}" rollout status deployment/"${APP_NAME}" \
                          --timeout=300s
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

## 4.6 学习建议

建议按下面顺序掌握：

1. 先掌握 Declarative Pipeline 的固定结构。
2. 再掌握 `def`、字符串、List、Map、if、each。
3. 学会在 `script {}` 中处理动态逻辑。
4. 学会把结果写入 `env.xxx`，供后续阶段和 Shell 使用。
5. 学会用 `withCredentials` 处理敏感信息。
6. 多项目复用时，再引入 `load` 和 Shared Library。

日常 Jenkinsfile 中最常用的 Groovy 能力其实不多：

- 字符串拼接和替换。
- 根据分支、参数、环境选择配置。
- 遍历服务列表。
- 动态生成并行任务。
- 封装少量工具方法。

## 4.7 参考资料

- [Groovy 官方语言文档](https://docs.groovy-lang.org/docs/latest/html/documentation/)
- [Jenkins Pipeline 官方文档](https://www.jenkins.io/doc/book/pipeline/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Using a Jenkinsfile](https://www.jenkins.io/doc/book/pipeline/jenkinsfile/)
- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/)
