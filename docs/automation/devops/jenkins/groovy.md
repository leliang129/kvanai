---
title: Jenkins Groovy 使用说明
sidebar_position: 3
---

# Jenkins Groovy 使用说明


## 3.1 Groovy 与 Jenkins 的关系

Groovy 是运行在 JVM 上的动态语言，语法兼容大量 Java 写法，同时提供字符串插值、集合字面量、闭包、动态类型等能力。Jenkins Pipeline、共享库、Script Console、Job DSL 等能力都大量使用 Groovy。

Jenkins 中常见 Groovy 使用场景：

- 在 `Jenkinsfile` 的 `script {}` 块中编写复杂逻辑。
- 编写 Pipeline Shared Library 复用流水线能力。
- 在 Script Console 中执行管理脚本。
- 使用 Job DSL 批量生成 Jenkins 任务。
- 调用 Jenkins Java API 查询或修改系统对象。

注意：

- Jenkinsfile 不是普通 Groovy 脚本，而是 Jenkins Pipeline DSL。
- Declarative Pipeline 中只有 `script {}` 块适合写复杂 Groovy 逻辑。
- Script Console 权限极高，可以直接修改 Jenkins Controller 运行时状态，生产环境必须谨慎使用。

## 3.2 Groovy 基础语法

### 3.2.1 变量

Groovy 可以使用 `def` 声明动态类型变量，也可以显式声明类型。

```groovy
def appName = 'demo-service'
def buildNumber = 100
String envName = 'test'
Integer timeoutMinutes = 30

println appName
println buildNumber
println envName
println timeoutMinutes
```

在 Jenkinsfile 中常见写法：

```groovy
script {
    def imageTag = "${env.BUILD_NUMBER}"
    echo "image tag: ${imageTag}"
}
```

### 3.2.2 字符串

单引号字符串不做变量插值：

```groovy
def name = 'jenkins'
println 'hello ${name}'
```

双引号字符串支持变量插值：

```groovy
def name = 'jenkins'
println "hello ${name}"
```

三引号适合多行字符串：

```groovy
def command = """
docker build -t demo-service:latest .
docker push demo-service:latest
"""

println command
```

在 Jenkins `sh` 中建议按用途区分：

```groovy
steps {
    sh 'echo "$BUILD_NUMBER"'

    script {
        def branch = env.BRANCH_NAME ?: 'main'
        sh "echo '${branch}'"
    }
}
```

说明：

- Shell 环境变量一般交给 Shell 展开，如 `$BUILD_NUMBER`。
- Groovy 变量需要 Groovy 插值时使用 `"${value}"`。
- 涉及凭据时避免 `echo` 或把敏感值拼入日志。

### 3.2.3 List

```groovy
def services = ['user-service', 'order-service', 'pay-service']

println services[0]
println services.size()

services.each { service ->
    println "service: ${service}"
}
```

过滤和转换：

```groovy
def prodServices = services.findAll { it.endsWith('-service') }
def imageNames = services.collect { "registry.example.com/devops/${it}" }

println prodServices
println imageNames
```

### 3.2.4 Map

```groovy
def deployConfig = [
    dev : '10.0.0.11',
    test: '10.0.0.12',
    prod: '10.0.0.13'
]

println deployConfig.dev
println deployConfig['prod']
```

遍历：

```groovy
deployConfig.each { envName, host ->
    println "${envName}: ${host}"
}
```

在 Jenkinsfile 中按环境取配置：

```groovy
script {
    def config = [
        dev : [namespace: 'dev', replicas: 1],
        test: [namespace: 'test', replicas: 2],
        prod: [namespace: 'prod', replicas: 3]
    ]

    def current = config[params.DEPLOY_ENV]
    echo "namespace: ${current.namespace}, replicas: ${current.replicas}"
}
```

### 3.2.5 条件判断

```groovy
def deployEnv = 'prod'

if (deployEnv == 'prod') {
    println 'production'
} else if (deployEnv == 'test') {
    println 'test'
} else {
    println 'dev'
}
```

三元表达式：

```groovy
def branch = 'main'
def imageTag = branch == 'main' ? 'stable' : 'snapshot'

println imageTag
```

Elvis 操作符：

```groovy
def branch = null
def actualBranch = branch ?: 'main'

println actualBranch
```

安全导航操作符：

```groovy
def user = null
println user?.name
```

### 3.2.6 循环

```groovy
for (int i = 0; i < 3; i++) {
    println i
}
```

集合循环：

```groovy
['dev', 'test', 'prod'].each { envName ->
    println "deploy env: ${envName}"
}
```

带索引循环：

```groovy
['build', 'test', 'deploy'].eachWithIndex { stageName, index ->
    println "${index}: ${stageName}"
}
```

### 3.2.7 方法

```groovy
def imageName(String registry, String appName, String tag) {
    return "${registry}/devops/${appName}:${tag}"
}

println imageName('registry.example.com', 'demo-service', '1.0.0')
```

在 Jenkinsfile 中定义方法时，建议放在 `pipeline {}` 外部或使用共享库。复杂逻辑不建议堆在 Jenkinsfile 中。

```groovy title="Jenkinsfile"
def normalizeBranch(String branchName) {
    return branchName.replaceAll('/', '-')
}

pipeline {
    agent any

    stages {
        stage('Demo') {
            steps {
                script {
                    def tag = normalizeBranch(env.BRANCH_NAME ?: 'main')
                    echo "tag: ${tag}"
                }
            }
        }
    }
}
```

## 3.3 闭包

闭包是 Groovy 中非常重要的语法，Jenkins Pipeline DSL 大量使用闭包组织结构。

基础示例：

```groovy
def sayHello = { name ->
    println "hello ${name}"
}

sayHello('jenkins')
```

隐式参数 `it`：

```groovy
def names = ['jenkins', 'gitlab', 'docker']
names.each {
    println it
}
```

带返回值：

```groovy
def upper = { value ->
    return value.toUpperCase()
}

println upper('jenkins')
```

Pipeline 中这些结构本质上都依赖闭包风格：

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

## 3.4 Jenkinsfile 中使用 Groovy

### 3.4.1 script 块

Declarative Pipeline 中复杂逻辑应放入 `script {}`：

```groovy title="Jenkinsfile"
pipeline {
    agent any

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['dev', 'test', 'prod'], description: '部署环境')
    }

    stages {
        stage('Generate Config') {
            steps {
                script {
                    def config = [
                        dev : [replicas: 1, namespace: 'dev'],
                        test: [replicas: 2, namespace: 'test'],
                        prod: [replicas: 3, namespace: 'prod']
                    ]

                    def current = config[params.DEPLOY_ENV]
                    env.K8S_NAMESPACE = current.namespace
                    env.REPLICAS = current.replicas.toString()
                }
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    echo "namespace: ${K8S_NAMESPACE}"
                    echo "replicas: ${REPLICAS}"
                '''
            }
        }
    }
}
```

说明：

- `script {}` 内可以使用 Groovy 的变量、集合、循环、方法调用。
- 如果后续 `sh` 阶段需要使用某个值，可以写入 `env.xxx`。
- `env` 中的值本质是字符串，数字需要 `toString()`。

### 3.4.2 动态生成 parallel

根据服务列表动态生成并行任务：

```groovy title="Jenkinsfile"
pipeline {
    agent any

    stages {
        stage('Parallel Build') {
            steps {
                script {
                    def services = ['user-service', 'order-service', 'pay-service']
                    def tasks = [:]

                    services.each { service ->
                        tasks[service] = {
                            stage("Build ${service}") {
                                sh "echo build ${service}"
                            }
                        }
                    }

                    parallel tasks
                }
            }
        }
    }
}
```

适用场景：

- 单仓库多服务构建。
- 多环境并行验证。
- 多模块并行测试。

### 3.4.3 捕获错误

使用 `try/catch/finally`：

```groovy
pipeline {
    agent any

    stages {
        stage('Deploy') {
            steps {
                script {
                    try {
                        sh './deploy.sh'
                    } catch (Exception e) {
                        currentBuild.result = 'FAILURE'
                        echo "deploy failed: ${e.message}"
                        throw e
                    } finally {
                        echo 'cleanup'
                    }
                }
            }
        }
    }
}
```

使用 `catchError`：

```groovy
stage('Quality Gate') {
    steps {
        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
            sh './quality-check.sh'
        }
    }
}
```

## 3.5 外部 Groovy 脚本

### 3.5.1 load 加载脚本

仓库结构：

```text
.
├── Jenkinsfile
└── scripts
    └── pipelineUtils.groovy
```

`scripts/pipelineUtils.groovy`：

```groovy title="scripts/pipelineUtils.groovy"
def imageTag(String branchName, String buildNumber) {
    def normalized = branchName.replaceAll('/', '-')
    return "${normalized}-${buildNumber}"
}

return this
```

`Jenkinsfile`：

```groovy title="Jenkinsfile"
pipeline {
    agent any

    stages {
        stage('Load Script') {
            steps {
                script {
                    def utils = load 'scripts/pipelineUtils.groovy'
                    def tag = utils.imageTag(env.BRANCH_NAME ?: 'main', env.BUILD_NUMBER)
                    echo "tag: ${tag}"
                }
            }
        }
    }
}
```

说明：

- 使用 `load` 的脚本通常需要 `return this`，便于 Jenkinsfile 调用脚本中的方法。
- `load` 适合项目内少量复用，不适合跨大量项目复用。
- 跨项目复用建议使用 Shared Library。

### 3.5.2 Shared Library 目录结构

典型共享库结构：

```text
jenkins-shared-library
├── vars
│   ├── dockerBuild.groovy
│   └── k8sDeploy.groovy
├── src
│   └── org
│       └── example
│           └── PipelineConfig.groovy
└── resources
    └── templates
        └── deployment.yaml
```

目录说明：

| 目录 | 说明 |
| --- | --- |
| `vars/` | 暴露给 Jenkinsfile 直接调用的全局变量或步骤 |
| `src/` | 标准 Groovy 类源码 |
| `resources/` | 存放模板、配置等资源文件 |

`vars/dockerBuild.groovy`：

```groovy title="vars/dockerBuild.groovy"
def call(Map args = [:]) {
    def image = args.image
    def tag = args.tag ?: env.BUILD_NUMBER

    sh """
        docker build -t ${image}:${tag} .
        docker push ${image}:${tag}
    """
}
```

Jenkinsfile 调用：

```groovy title="Jenkinsfile"
@Library('devops-shared-library') _

pipeline {
    agent {
        label 'linux && docker'
    }

    stages {
        stage('Build Image') {
            steps {
                dockerBuild image: 'registry.example.com/devops/demo-service',
                            tag: env.BUILD_NUMBER
            }
        }
    }
}
```

## 3.6 Script Console

### 3.6.1 入口与风险

Script Console 入口：

```text
Manage Jenkins -> Script Console
```

或直接访问：

```text
http://jenkins.example.com/script
```

风险说明：

- Script Console 中的 Groovy 脚本运行在 Jenkins Controller JVM 中。
- 管理员可以通过脚本读取、修改、删除 Jenkins 内部对象。
- 错误脚本可能导致配置损坏、任务误删、凭据泄露或服务不可用。
- 生产环境执行前必须先备份 Jenkins Home，并在测试环境验证。

### 3.6.2 查看 Jenkins 基本信息

```groovy
import jenkins.model.Jenkins

def jenkins = Jenkins.get()

println "Jenkins URL: ${jenkins.rootUrl}"
println "Version: ${jenkins.version}"
println "Nodes: ${jenkins.nodes.size()}"
println "Jobs: ${jenkins.allItems.size()}"
```

### 3.6.3 列出所有 Job

```groovy
import jenkins.model.Jenkins
import hudson.model.Job

Jenkins.get().getAllItems(Job.class).each { job ->
    println "${job.fullName} -> ${job.url}"
}
```

### 3.6.4 查看最近构建状态

```groovy
import jenkins.model.Jenkins
import hudson.model.Job

Jenkins.get().getAllItems(Job.class).each { job ->
    def build = job.getLastBuild()
    if (build != null) {
        println "${job.fullName}: #${build.number} ${build.result}"
    } else {
        println "${job.fullName}: no build"
    }
}
```

### 3.6.5 查找禁用任务

```groovy
import jenkins.model.Jenkins
import hudson.model.AbstractProject

Jenkins.get().getAllItems(AbstractProject.class).findAll { job ->
    job.disabled
}.each { job ->
    println job.fullName
}
```

### 3.6.6 安全删除构建历史示例

删除指定任务 `30` 天前的构建历史：

```groovy
import jenkins.model.Jenkins

def jobName = 'folder/demo-job'
def days = 30
def cutoff = System.currentTimeMillis() - days * 24L * 60L * 60L * 1000L

def job = Jenkins.get().getItemByFullName(jobName)

if (job == null) {
    println "job not found: ${jobName}"
    return
}

job.builds.each { build ->
    if (build.timeInMillis < cutoff) {
        println "delete ${jobName} #${build.number}"
        build.delete()
    }
}
```

执行前建议先把 `build.delete()` 注释掉，仅输出确认范围。

### 3.6.7 批量设置构建保留策略

```groovy
import jenkins.model.Jenkins
import hudson.tasks.LogRotator
import jenkins.model.BuildDiscarderProperty
import hudson.model.Job

Jenkins.get().getAllItems(Job.class).each { job ->
    def discarder = new LogRotator(
        -1,
        30,
        -1,
        10
    )

    job.removeProperty(BuildDiscarderProperty.class)
    job.addProperty(new BuildDiscarderProperty(discarder))
    job.save()

    println "updated: ${job.fullName}"
}
```

说明：

- `daysToKeep`：构建保留天数。
- `numToKeep`：构建保留数量。
- `artifactDaysToKeep`：制品保留天数。
- `artifactNumToKeep`：制品保留数量。

## 3.7 常见问题

### 3.7.1 MissingPropertyException

常见原因：

- 变量未定义。
- 在 Groovy 作用域中直接使用了 Shell 变量。
- Declarative Pipeline 中变量位置不合法。

错误示例：

```groovy
script {
    echo imageTag
}
```

修复示例：

```groovy
script {
    def imageTag = env.BUILD_NUMBER
    echo imageTag
}
```

### 3.7.2 GString 与 String 类型问题

Groovy 双引号插值生成的可能是 `GString`，部分 Java API 需要严格的 `String`。

```groovy
def tag = "${env.BUILD_NUMBER}".toString()
```

在 Jenkins Pipeline 中，如果遇到奇怪的类型问题，可以显式调用 `toString()`。

### 3.7.3 CPS 序列化问题

Jenkins Pipeline 使用 CPS 转换来支持暂停和恢复。部分普通 Groovy/Java 对象不适合跨 Pipeline 步骤长期保存。

容易出问题的场景：

- 将复杂对象保存在全局变量中。
- 在闭包中持有不可序列化对象。
- 在 `@NonCPS` 方法中调用 `sh`、`echo`、`checkout` 等 Pipeline 步骤。

建议：

- Pipeline 状态尽量使用简单字符串、数字、List、Map。
- 复杂计算完成后返回简单对象。
- `@NonCPS` 只用于纯数据处理，不调用 Jenkins Pipeline Step。

示例：

```groovy
@NonCPS
def sortNames(List<String> names) {
    return names.sort()
}
```

### 3.7.4 沙箱审批

如果 Pipeline 或共享库使用了未被允许的方法，可能出现脚本审批提示。

审批入口：

```text
Manage Jenkins -> In-process Script Approval
```

建议：

- 普通项目 Jenkinsfile 尽量使用标准 Pipeline Step。
- 高权限逻辑放入受信任的 Shared Library。
- 不随意审批来源不明的方法调用。

### 3.7.5 Script Console 脚本执行后没有效果

排查方向：

- 是否调用了 `save()`。
- 查询对象是否正确。
- 是否修改了 Folder 下的 Job，需要使用 `fullName`。
- 是否运行在测试 Jenkins，而不是目标 Jenkins。
- 是否需要重启或重新加载配置。

## 3.8 编写规范建议

建议：

- Jenkinsfile 中 Groovy 逻辑保持短小，复杂逻辑抽到脚本或共享库。
- 共享库 `vars/` 中的入口统一使用 `call(Map args = [:])`。
- 方法参数尽量使用 `Map`，方便后续扩展。
- 变量命名清晰，避免 `data`、`info`、`tmp` 这类模糊名称。
- 凭据只在 `withCredentials` 作用域内使用。
- Script Console 脚本默认先 dry run，再执行真实修改。
- 涉及删除、批量修改、凭据、权限的脚本必须先备份。

推荐共享库入口风格：

```groovy title="vars/k8sDeploy.groovy"
def call(Map args = [:]) {
    String namespace = args.namespace ?: error('namespace is required')
    String deployment = args.deployment ?: error('deployment is required')
    String container = args.container ?: deployment
    String image = args.image ?: error('image is required')

    sh """
        kubectl -n ${namespace} set image deployment/${deployment} \
          ${container}=${image}
        kubectl -n ${namespace} rollout status deployment/${deployment} \
          --timeout=300s
    """
}
```

调用：

```groovy
k8sDeploy namespace: 'test',
          deployment: 'demo-service',
          image: 'registry.example.com/devops/demo-service:1.0.0'
```

## 3.9 参考资料

- [Groovy 官方语言文档](https://docs.groovy-lang.org/docs/latest/html/documentation/)
- [Jenkins Pipeline 官方文档](https://www.jenkins.io/doc/book/pipeline/)
- [Jenkins Pipeline 语法](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Jenkins Shared Libraries](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)
- [Jenkins Script Console](https://www.jenkins.io/doc/book/managing/script-console/)
