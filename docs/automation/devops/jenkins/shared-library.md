---
title: Jenkins Shared Library
sidebar_position: 5
---

# Jenkins Shared Library


## 5.1 Shared Library 介绍

Jenkins Shared Library 是 Jenkins Pipeline 的共享库机制，用于把多个项目重复使用的流水线逻辑抽离到独立 Git 仓库中统一维护。

适合抽离到 Shared Library 的内容：

- Maven、Gradle、Node.js、Go 等通用构建步骤。
- Docker 镜像构建、登录、推送逻辑。
- Kubernetes、SSH、Ansible 等部署逻辑。
- SonarQube、单元测试、制品归档等质量流程。
- 钉钉、企业微信、邮件等通知逻辑。
- 统一的参数校验、镜像标签生成、分支规则判断。

不建议放入 Shared Library 的内容：

- 单个项目独有的业务构建逻辑。
- 明文密码、Token、私钥。
- 频繁变化且没有复用价值的临时脚本。
- 强绑定某个项目路径或某个环境的硬编码配置。

基本思路：

- 项目仓库保留简洁 `Jenkinsfile`。
- 共享库仓库维护可复用步骤。
- Jenkinsfile 通过 `@Library` 引入共享库。
- 凭据、环境、镜像仓库、命名空间等信息通过参数传入。

## 5.2 目录结构

典型 Shared Library 仓库结构：

```text
jenkins-shared-library
├── vars
│   ├── dockerBuild.groovy
│   ├── k8sDeploy.groovy
│   ├── mavenBuild.groovy
│   └── notifyDingTalk.groovy
├── src
│   └── org
│       └── example
│           └── devops
│               ├── ImageTag.groovy
│               └── DeployConfig.groovy
├── resources
│   └── templates
│       └── deployment.yaml
└── README.md
```

目录说明：

| 目录 | 说明 |
| --- | --- |
| `vars/` | 暴露给 Jenkinsfile 直接调用的全局步骤 |
| `src/` | 标准 Groovy 类源码，适合封装复杂逻辑 |
| `resources/` | 模板、配置等资源文件 |

常用约定：

- `vars/xxx.groovy` 文件名就是 Jenkinsfile 中调用的步骤名。
- `vars/xxx.groovy` 中通常定义 `def call(Map args = [:])`。
- `src/` 中的类需要写标准 `package`。
- `resources/` 中的文件通过 `libraryResource` 读取。

## 5.3 Jenkins 全局配置

配置入口：

```text
Manage Jenkins -> System -> Global Trusted Pipeline Libraries
```

常见配置项：

| 配置项 | 说明 |
| --- | --- |
| `Name` | 共享库名称，如 `devops-shared-library` |
| `Default version` | 默认分支或标签，如 `main`、`master`、`v1.0.0` |
| `Retrieval method` | 获取方式，通常选择 Modern SCM |
| `Source Code Management` | Git 仓库地址和凭据 |
| `Load implicitly` | 是否默认加载到所有 Pipeline |
| `Allow default version to be overridden` | 是否允许 Jenkinsfile 指定版本 |

建议：

- 生产环境不要轻易启用 `Load implicitly`，建议由 Jenkinsfile 显式加载。
- 生产项目优先使用 tag 或稳定分支引用共享库。
- 共享库仓库权限要严格控制，避免普通开发者修改高权限部署逻辑。

## 5.4 Jenkinsfile 加载共享库

### 5.4.1 使用默认版本

```groovy title="Jenkinsfile"
@Library('devops-shared-library') _

pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                mavenBuild()
            }
        }
    }
}
```

### 5.4.2 指定分支或标签

```groovy title="Jenkinsfile"
@Library('devops-shared-library@v1.2.0') _

pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                mavenBuild goals: 'clean package -DskipTests'
            }
        }
    }
}
```

说明：

- `@v1.2.0` 可以是 tag、branch 或 commit。
- 生产环境建议使用 tag，避免共享库变更直接影响所有项目。

### 5.4.3 加载多个共享库

```groovy
@Library(['devops-shared-library@v1.2.0', 'notify-library@main']) _
```

## 5.5 vars 全局步骤

### 5.5.1 基础写法

`vars/hello.groovy`：

```groovy title="vars/hello.groovy"
def call(String name = 'jenkins') {
    echo "hello ${name}"
}
```

Jenkinsfile 调用：

```groovy
hello 'devops'
```

### 5.5.2 推荐 Map 参数

共享步骤推荐使用 `Map args = [:]`，后续扩展参数时兼容性更好。

```groovy title="vars/mavenBuild.groovy"
def call(Map args = [:]) {
    String goals = args.goals ?: 'clean package -DskipTests'
    String settings = args.settings ?: ''

    if (settings) {
        sh "mvn -s ${settings} -B ${goals}"
    } else {
        sh "mvn -B ${goals}"
    }
}
```

调用：

```groovy
mavenBuild goals: 'clean test package',
           settings: '/opt/maven/settings.xml'
```

### 5.5.3 参数校验

必填参数建议明确校验：

```groovy title="vars/dockerBuild.groovy"
def call(Map args = [:]) {
    String image = args.image ?: error('image is required')
    String tag = args.tag ?: env.BUILD_NUMBER
    String context = args.context ?: '.'
    String dockerfile = args.dockerfile ?: 'Dockerfile'

    sh """
        docker build \
          -f ${dockerfile} \
          -t ${image}:${tag} \
          ${context}
    """
}
```

调用：

```groovy
dockerBuild image: 'registry.example.com/devops/demo-service',
            tag: env.BUILD_NUMBER
```

## 5.6 常用共享步骤示例

### 5.6.1 Docker 镜像构建与推送

```groovy title="vars/dockerBuildPush.groovy"
def call(Map args = [:]) {
    String registry = args.registry ?: error('registry is required')
    String image = args.image ?: error('image is required')
    String tag = args.tag ?: env.BUILD_NUMBER
    String credentialsId = args.credentialsId ?: error('credentialsId is required')
    String context = args.context ?: '.'
    String dockerfile = args.dockerfile ?: 'Dockerfile'

    String fullImage = "${registry}/${image}:${tag}"

    withCredentials([
        usernamePassword(
            credentialsId: credentialsId,
            usernameVariable: 'REGISTRY_USER',
            passwordVariable: 'REGISTRY_PASS'
        )
    ]) {
        sh """
            docker build -f ${dockerfile} -t ${fullImage} ${context}
            echo "\${REGISTRY_PASS}" | docker login ${registry} \
              -u "\${REGISTRY_USER}" --password-stdin
            docker push ${fullImage}
            docker logout ${registry} || true
        """
    }

    return fullImage
}
```

Jenkinsfile：

```groovy title="Jenkinsfile"
@Library('devops-shared-library@v1.0.0') _

pipeline {
    agent {
        label 'linux && docker'
    }

    stages {
        stage('Build Image') {
            steps {
                script {
                    env.IMAGE = dockerBuildPush registry: 'registry.example.com',
                                                image: 'devops/demo-service',
                                                tag: env.BUILD_NUMBER,
                                                credentialsId: 'docker-registry'
                }
            }
        }
    }
}
```

### 5.6.2 Kubernetes 发布

```groovy title="vars/k8sDeploy.groovy"
def call(Map args = [:]) {
    String namespace = args.namespace ?: error('namespace is required')
    String deployment = args.deployment ?: error('deployment is required')
    String container = args.container ?: deployment
    String image = args.image ?: error('image is required')
    String kubeconfig = args.kubeconfig ?: error('kubeconfig is required')
    String timeout = args.timeout ?: '300s'

    withCredentials([
        file(credentialsId: kubeconfig, variable: 'KUBECONFIG')
    ]) {
        sh """
            kubectl -n ${namespace} set image deployment/${deployment} \
              ${container}=${image}

            kubectl -n ${namespace} rollout status deployment/${deployment} \
              --timeout=${timeout}
        """
    }
}
```

Jenkinsfile：

```groovy
k8sDeploy namespace: 'test',
          deployment: 'demo-service',
          image: env.IMAGE,
          kubeconfig: 'kubeconfig-test'
```

### 5.6.3 钉钉通知

```groovy title="vars/notifyDingTalk.groovy"
def call(Map args = [:]) {
    String credentialsId = args.credentialsId ?: error('credentialsId is required')
    String title = args.title ?: "Jenkins Build ${currentBuild.currentResult}"
    String message = args.message ?: ''

    withCredentials([
        string(credentialsId: credentialsId, variable: 'DINGTALK_WEBHOOK')
    ]) {
        sh """
            curl -sS -X POST "\${DINGTALK_WEBHOOK}" \
              -H 'Content-Type: application/json' \
              -d '{
                "msgtype": "markdown",
                "markdown": {
                  "title": "${title}",
                  "text": "### ${title}\\n${message}"
                }
              }'
        """
    }
}
```

Jenkinsfile：

```groovy
post {
    success {
        notifyDingTalk credentialsId: 'dingtalk-webhook',
                       title: '构建成功',
                       message: "- Job: ${env.JOB_NAME}\\n- Build: #${env.BUILD_NUMBER}"
    }
    failure {
        notifyDingTalk credentialsId: 'dingtalk-webhook',
                       title: '构建失败',
                       message: "- Job: ${env.JOB_NAME}\\n- Build: #${env.BUILD_NUMBER}"
    }
}
```

注意：

- 通知内容如果复杂，建议用 `writeJSON` 生成 JSON 文件，再用 `curl -d @file.json` 发送。
- 不要把 Webhook URL 明文写在共享库或 Jenkinsfile 中。

## 5.7 src Groovy 类

`src/` 适合放纯逻辑类，例如镜像标签生成、环境配置计算、字符串处理等。

示例：

```groovy title="src/org/example/devops/ImageTag.groovy"
package org.example.devops

class ImageTag implements Serializable {
    static String fromBranch(String branchName, String commit, String buildNumber) {
        String branch = branchName ?: 'main'
        String safeBranch = branch.replaceAll('/', '-')
        String shortCommit = commit ? commit.take(8) : buildNumber

        return "${safeBranch}-${shortCommit}-${buildNumber}"
    }
}
```

在 `vars/` 中调用：

```groovy title="vars/createImageTag.groovy"
import org.example.devops.ImageTag

def call(Map args = [:]) {
    return ImageTag.fromBranch(
        args.branchName ?: env.BRANCH_NAME,
        args.commit ?: env.GIT_COMMIT,
        args.buildNumber ?: env.BUILD_NUMBER
    )
}
```

Jenkinsfile：

```groovy
script {
    env.IMAGE_TAG = createImageTag()
}
```

建议：

- `src/` 中尽量写纯 Groovy/Java 逻辑。
- 不建议在 `src/` 类中直接调用 `sh`、`echo`、`checkout` 等 Pipeline Step。
- 需要调用 Pipeline Step 时，优先放在 `vars/` 中。

## 5.8 resources 模板

`resources/` 适合存放模板文件，例如 Kubernetes YAML、通知模板等。

模板文件：

```yaml title="resources/templates/deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: __APP_NAME__
  namespace: __NAMESPACE__
spec:
  replicas: __REPLICAS__
  selector:
    matchLabels:
      app: __APP_NAME__
  template:
    metadata:
      labels:
        app: __APP_NAME__
    spec:
      containers:
        - name: __APP_NAME__
          image: __IMAGE__
```

共享步骤：

```groovy title="vars/k8sApplyTemplate.groovy"
def call(Map args = [:]) {
    String appName = args.appName ?: error('appName is required')
    String namespace = args.namespace ?: error('namespace is required')
    String image = args.image ?: error('image is required')
    String replicas = (args.replicas ?: 1).toString()
    String kubeconfig = args.kubeconfig ?: error('kubeconfig is required')

    String content = libraryResource('templates/deployment.yaml')
        .replace('__APP_NAME__', appName)
        .replace('__NAMESPACE__', namespace)
        .replace('__IMAGE__', image)
        .replace('__REPLICAS__', replicas)

    writeFile file: 'deployment.rendered.yaml', text: content

    withCredentials([
        file(credentialsId: kubeconfig, variable: 'KUBECONFIG')
    ]) {
        sh 'kubectl apply -f deployment.rendered.yaml'
    }
}
```

Jenkinsfile：

```groovy
k8sApplyTemplate appName: 'demo-service',
                 namespace: 'test',
                 image: env.IMAGE,
                 replicas: 2,
                 kubeconfig: 'kubeconfig-test'
```

说明：

- `libraryResource` 只能读取共享库 `resources/` 下的文件。
- 模板变量较多时，建议使用明确占位符，避免误替换。
- 复杂模板渲染可以考虑 Helm、Kustomize 或专门的模板工具。

## 5.9 完整 Jenkinsfile 示例

```groovy title="Jenkinsfile"
@Library('devops-shared-library@v1.0.0') _

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
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                mavenBuild goals: params.SKIP_TEST ? 'clean package -DskipTests' : 'clean test package'
            }
        }

        stage('Build Image') {
            steps {
                script {
                    env.IMAGE_TAG = createImageTag()
                    env.IMAGE = dockerBuildPush registry: env.REGISTRY,
                                                image: "devops/${env.APP_NAME}",
                                                tag: env.IMAGE_TAG,
                                                credentialsId: 'docker-registry'
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
                    input message: "确认发布 ${env.IMAGE} 到生产环境？", ok: '确认发布'
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    def envConfig = [
                        dev : [namespace: 'dev', kubeconfig: 'kubeconfig-dev'],
                        test: [namespace: 'test', kubeconfig: 'kubeconfig-test'],
                        prod: [namespace: 'prod', kubeconfig: 'kubeconfig-prod']
                    ]

                    def config = envConfig[params.DEPLOY_ENV]

                    k8sDeploy namespace: config.namespace,
                              deployment: env.APP_NAME,
                              image: env.IMAGE,
                              kubeconfig: config.kubeconfig
                }
            }
        }
    }

    post {
        success {
            notifyDingTalk credentialsId: 'dingtalk-webhook',
                           title: '构建成功',
                           message: "- Job: ${env.JOB_NAME}\\n- Build: #${env.BUILD_NUMBER}\\n- Image: ${env.IMAGE}"
        }
        failure {
            notifyDingTalk credentialsId: 'dingtalk-webhook',
                           title: '构建失败',
                           message: "- Job: ${env.JOB_NAME}\\n- Build: #${env.BUILD_NUMBER}"
        }
        always {
            cleanWs()
        }
    }
}
```

## 5.10 版本管理建议

共享库影响范围通常比单个项目更大，必须做好版本管理。

建议：

- `main` 分支用于开发或测试，不直接给生产项目使用。
- 发布稳定版本时打 tag，例如 `v1.0.0`、`v1.1.0`。
- 生产 Jenkinsfile 使用 `@Library('devops-shared-library@v1.0.0')` 固定版本。
- 共享库变更先在少量项目灰度验证。
- 破坏性变更要升级主版本号，并保留旧版本一段时间。
- 每个共享步骤都写清楚参数、默认值和返回值。

常见版本引用：

```groovy
@Library('devops-shared-library@main') _
@Library('devops-shared-library@develop') _
@Library('devops-shared-library@v1.0.0') _
@Library('devops-shared-library@a1b2c3d4') _
```

生产建议优先使用 tag。

## 5.11 常见问题

### 5.11.1 No such DSL method

常见原因：

- `vars/` 文件名和调用名称不一致。
- 共享库没有加载成功。
- Jenkinsfile 中 `@Library` 名称和 Jenkins 全局配置名称不一致。
- `vars/xxx.groovy` 中没有定义 `call` 方法。

排查方式：

- 检查构建日志中是否有加载共享库的记录。
- 检查共享库仓库分支或 tag 是否存在。
- 检查文件路径是否为 `vars/xxx.groovy`。

### 5.11.2 Script Approval

如果共享库不是受信任库，调用部分方法可能需要审批。

审批入口：

```text
Manage Jenkins -> In-process Script Approval
```

建议：

- 企业内部平台级共享库可以配置为 trusted library。
- 普通项目共享库尽量只使用标准 Pipeline Step。
- 不审批来源不明或权限过大的方法调用。

### 5.11.3 CPS 序列化问题

Jenkins Pipeline 会做 CPS 转换以支持暂停和恢复。共享库中如果保存复杂对象，可能出现序列化问题。

建议：

- Pipeline 状态尽量使用 String、Integer、Boolean、List、Map。
- `src/` 中的类如需跨阶段传递，建议实现 `Serializable`。
- `@NonCPS` 方法只做纯数据处理，不调用 `sh`、`echo`、`checkout` 等 Pipeline Step。
- 不把 Jenkins 内部复杂对象长期保存在全局变量中。

### 5.11.4 共享库修改不生效

排查方向：

- Jenkinsfile 是否固定了旧 tag。
- Jenkins 是否缓存了共享库源码。
- 构建是否拉取到了目标分支。
- 全局配置中的默认版本是否正确。
- 是否修改了另一个同名共享库。

处理方式：

- 临时指定分支测试：`@Library('devops-shared-library@develop') _`。
- 确认 Jenkins 构建日志中的共享库 revision。
- 发布正式版本后切换到新 tag。

### 5.11.5 凭据无法读取

排查方向：

- `credentialsId` 是否传入正确。
- 凭据类型是否和 `withCredentials` 绑定方式匹配。
- 当前 Job 是否有权限读取该凭据。
- 凭据是否放在 Folder 作用域，导致其他 Job 不可见。

建议共享库不要硬编码凭据 ID，凭据 ID 应由 Jenkinsfile 或参数传入。

## 5.12 规范建议

共享库编写建议：

- 入口统一使用 `def call(Map args = [:])`。
- 必填参数用 `error('xxx is required')` 明确报错。
- 不在共享库中硬编码生产环境地址、命名空间、凭据 ID。
- 共享步骤职责保持单一，例如构建、推送、部署、通知拆开。
- 返回关键结果，例如镜像完整地址、版本号、部署结果。
- 日志输出要清晰，但不要打印敏感信息。
- 复杂逻辑放 `src/`，Pipeline Step 放 `vars/`。
- 模板文件放 `resources/`。
- 生产项目使用 tag 固定共享库版本。

Jenkinsfile 编写建议：

- Jenkinsfile 保留项目特有信息和流程编排。
- 环境差异通过 Map 或参数传给共享步骤。
- 生产发布保留 `input` 人工确认。
- 凭据由 Jenkins Credentials 管理。
- 不直接复制共享库内部逻辑到项目 Jenkinsfile。

## 5.13 参考资料

- [Jenkins Shared Libraries 官方文档](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)
- [Jenkins Pipeline 官方文档](https://www.jenkins.io/doc/book/pipeline/)
- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/)
- [Using a Jenkinsfile](https://www.jenkins.io/doc/book/pipeline/jenkinsfile/)
