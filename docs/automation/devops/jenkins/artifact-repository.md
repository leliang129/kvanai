---
title: Jenkins 制品管理与制品库集成
sidebar_position: 9
---

# Jenkins 制品管理与制品库集成


## 9.1 制品管理目标

制品是流水线构建后的可交付产物，例如：

- Java 的 `jar`、`war`。
- Node.js 的 `dist/` 静态文件包。
- Go 编译后的二进制文件。
- Python wheel 包。
- Helm Chart。
- Docker 镜像。
- 测试报告、覆盖率报告、扫描报告。

制品管理的目标：

- 构建产物可追踪。
- 发布版本可回滚。
- 制品和源码版本能对应。
- 制品不依赖 Jenkins workspace 长期保存。
- 不同环境发布使用同一份不可变制品。

基本原则：

- Jenkins 负责构建和编排，不建议长期承担制品库职责。
- 临时报告可以使用 Jenkins `archiveArtifacts`。
- 可发布制品应上传到 Nexus、Artifactory、GitLab Package Registry、Harbor 等制品库。
- 生产发布应使用明确版本号，不直接使用临时文件或 workspace 内容。

## 9.2 Jenkins 归档与制品库区别

| 方式 | 说明 | 适用场景 |
| --- | --- | --- |
| `archiveArtifacts` | Jenkins 内置归档，保存在 Jenkins Home | 测试报告、小型构建产物、临时下载 |
| Nexus Repository | 通用制品库，支持 Maven、npm、PyPI、Docker 等 | 企业内部常用 |
| JFrog Artifactory | 企业制品库，功能完整 | 大型企业、多类型制品 |
| GitLab Package Registry | GitLab 内置包仓库 | GitLab 项目内制品管理 |
| Harbor | 容器镜像和 OCI 制品 | Docker 镜像、Helm Chart、OCI Artifact |

建议：

- Jenkins 归档只保存最近 N 次构建。
- 正式版本上传制品库。
- 制品库配置保留策略和清理策略。
- 部署流程从制品库拉取制品，不从 Jenkins workspace 拷贝。

## 9.3 制品命名规范

推荐制品命名包含：

- 应用名。
- 版本号。
- Git Commit。
- 构建号。
- 环境或渠道可选。

示例：

```text
demo-service-1.2.0.jar
demo-service-main-a1b2c3d4-1024.jar
demo-web-1.2.0.tar.gz
demo-chart-1.2.0.tgz
```

版本来源建议：

| 来源 | 示例 | 说明 |
| --- | --- | --- |
| Git Tag | `v1.2.0` | 正式发布推荐 |
| Maven version | `1.2.0-SNAPSHOT` | Java 项目常见 |
| npm version | `1.2.0` | 前端包常见 |
| Jenkins Build Number | `1024` | CI 构建号 |
| Git Commit | `a1b2c3d4` | 精确追踪源码 |

Jenkinsfile 示例：

```groovy
script {
    def shortCommit = env.GIT_COMMIT ? env.GIT_COMMIT.take(8) : env.BUILD_NUMBER
    env.VERSION = env.TAG_NAME ?: "${env.BRANCH_NAME}-${shortCommit}-${env.BUILD_NUMBER}"
}
```

## 9.4 Jenkins 归档制品

### 9.4.1 archiveArtifacts

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && maven'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
    }

    stages {
        stage('Build') {
            steps {
                sh 'mvn -B clean package -DskipTests'
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'target/*.jar',
                                 fingerprint: true,
                                 onlyIfSuccessful: true
            }
        }
    }
}
```

说明：

- `fingerprint: true` 可以记录制品指纹，便于追踪。
- `onlyIfSuccessful: true` 只在构建成功时归档。
- `artifactNumToKeepStr` 控制制品保留数量。

### 9.4.2 归档报告

```groovy
post {
    always {
        junit 'target/surefire-reports/*.xml'
        archiveArtifacts artifacts: 'dependency-check-report/**',
                         allowEmptyArchive: true
    }
}
```

HTML 报告：

```groovy
publishHTML([
    reportDir: 'coverage',
    reportFiles: 'index.html',
    reportName: 'Coverage Report',
    keepAll: true,
    alwaysLinkToLastBuild: true,
    allowMissing: true
])
```

## 9.5 Nexus Repository 集成

### 9.5.1 Maven 制品发布

Maven `pom.xml` 示例：

```xml title="pom.xml"
<distributionManagement>
    <repository>
        <id>nexus-releases</id>
        <url>https://nexus.example.com/repository/maven-releases/</url>
    </repository>
    <snapshotRepository>
        <id>nexus-snapshots</id>
        <url>https://nexus.example.com/repository/maven-snapshots/</url>
    </snapshotRepository>
</distributionManagement>
```

Jenkins 凭据：

```text
Type: Username with password
ID: nexus-maven
```

临时生成 Maven settings：

```groovy title="Jenkinsfile"
stage('Deploy Maven Artifact') {
    steps {
        withCredentials([
            usernamePassword(
                credentialsId: 'nexus-maven',
                usernameVariable: 'NEXUS_USER',
                passwordVariable: 'NEXUS_PASS'
            )
        ]) {
            writeFile file: 'settings.xml', text: """
<settings>
  <servers>
    <server>
      <id>nexus-releases</id>
      <username>${env.NEXUS_USER}</username>
      <password>${env.NEXUS_PASS}</password>
    </server>
    <server>
      <id>nexus-snapshots</id>
      <username>${env.NEXUS_USER}</username>
      <password>${env.NEXUS_PASS}</password>
    </server>
  </servers>
</settings>
"""

            sh 'mvn -B -s settings.xml clean deploy'
        }
    }
}
```

更推荐使用 Config File Provider 插件统一管理 `settings.xml`。

### 9.5.2 上传通用制品

使用 curl 上传 tar.gz：

```groovy
stage('Upload Artifact') {
    steps {
        sh 'tar czf demo-web-${BUILD_NUMBER}.tar.gz dist/'

        withCredentials([
            usernamePassword(
                credentialsId: 'nexus-generic',
                usernameVariable: 'NEXUS_USER',
                passwordVariable: 'NEXUS_PASS'
            )
        ]) {
            sh '''
                curl -u "${NEXUS_USER}:${NEXUS_PASS}" \
                  --upload-file "demo-web-${BUILD_NUMBER}.tar.gz" \
                  "https://nexus.example.com/repository/generic/demo-web/demo-web-${BUILD_NUMBER}.tar.gz"
            '''
        }
    }
}
```

## 9.6 npm 制品发布

适用于 Nexus npm repository、Artifactory npm repository 或 GitLab npm Package Registry。

`.npmrc` 示例：

```text
registry=https://nexus.example.com/repository/npm-hosted/
//nexus.example.com/repository/npm-hosted/:_authToken=${NPM_TOKEN}
```

Jenkinsfile：

```groovy
stage('Publish npm Package') {
    steps {
        withCredentials([
            string(credentialsId: 'npm-token', variable: 'NPM_TOKEN')
        ]) {
            sh '''
                cat > .npmrc <<EOF
registry=https://nexus.example.com/repository/npm-hosted/
//nexus.example.com/repository/npm-hosted/:_authToken=${NPM_TOKEN}
EOF
                npm ci
                npm publish
            '''
        }
    }
}
```

注意：

- 不要把 `.npmrc` 和 Token 提交到仓库。
- 发布完成后可以删除临时 `.npmrc`。

## 9.7 GitLab Package Registry

GitLab Package Registry 适合和 GitLab 项目绑定的制品。

### 9.7.1 Generic Package

上传通用制品：

```groovy
stage('Upload GitLab Generic Package') {
    steps {
        sh 'tar czf demo-service-${BUILD_NUMBER}.tar.gz target/*.jar'

        withCredentials([
            string(credentialsId: 'gitlab-api-token', variable: 'GITLAB_TOKEN')
        ]) {
            sh '''
                curl --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
                  --upload-file "demo-service-${BUILD_NUMBER}.tar.gz" \
                  "https://gitlab.example.com/api/v4/projects/${GITLAB_PROJECT_ID}/packages/generic/demo-service/${BUILD_NUMBER}/demo-service-${BUILD_NUMBER}.tar.gz"
            '''
        }
    }
}
```

其中 `GITLAB_PROJECT_ID` 可以作为参数或环境变量传入。

### 9.7.2 Maven Package

Maven 发布到 GitLab Package Registry 时，需要按 GitLab 项目配置对应仓库 URL 和 Token。适合希望制品和代码项目绑定管理的团队。

## 9.8 Helm Chart 制品

Helm Chart 可以上传到：

- Nexus Helm repository。
- Artifactory Helm repository。
- Harbor OCI Registry。

使用 OCI 推送到 Harbor：

```groovy
stage('Push Helm Chart') {
    steps {
        sh 'helm package charts/demo-service --version ${BUILD_NUMBER}'

        withCredentials([
            usernamePassword(
                credentialsId: 'harbor-robot-demo',
                usernameVariable: 'HARBOR_USER',
                passwordVariable: 'HARBOR_PASS'
            )
        ]) {
            sh '''
                echo "${HARBOR_PASS}" | helm registry login harbor.example.com \
                  -u "${HARBOR_USER}" --password-stdin

                helm push demo-service-${BUILD_NUMBER}.tgz \
                  oci://harbor.example.com/devops/charts
            '''
        }
    }
}
```

## 9.9 制品晋级

制品晋级是指同一份制品从测试环境逐步进入预发、生产，而不是每个环境重新构建。

推荐流程：

1. CI 构建一次制品。
2. 制品上传到 snapshot 或 staging 仓库。
3. 测试通过后标记或复制到 release 仓库。
4. 生产发布只拉取 release 制品。

好处：

- 避免“测试的是 A，生产发的是 B”。
- 版本可追踪。
- 回滚更清晰。

建议：

- snapshot 和 release 仓库分开。
- release 制品不允许覆盖。
- 制品晋级需要审批或自动质量门禁。

## 9.10 制品清理策略

Jenkins：

```groovy
options {
    buildDiscarder(logRotator(
        numToKeepStr: '20',
        artifactNumToKeepStr: '10'
    ))
}
```

制品库：

- Snapshot 制品保留最近 N 天或 N 个版本。
- Release 制品长期保留，按合规要求清理。
- 大文件制品设置生命周期策略。
- 定期清理未被引用的临时制品。

注意：

- 清理策略要和回滚策略一致。
- 生产 release 制品不要随意删除。
- 清理前确认没有部署系统仍在引用旧版本。

## 9.11 常见问题

### 9.11.1 Maven deploy 401

排查方向：

- `settings.xml` 中 server id 是否和 `pom.xml` 中 repository id 一致。
- Jenkins 凭据是否正确。
- Nexus 用户是否有 deploy 权限。
- release 和 snapshot 是否发到了正确仓库。

### 9.11.2 npm publish 失败

常见原因：

- `.npmrc` registry 地址错误。
- Token 无权限。
- 包名或 scope 不符合仓库规则。
- 版本号已存在。

### 9.11.3 制品上传成功但无法下载

排查方向：

- 仓库权限是否允许读取。
- URL 路径是否正确。
- 代理仓库是否缓存延迟。
- 制品是否被清理策略删除。

### 9.11.4 Jenkins Home 占用过大

处理：

- 减少 `archiveArtifacts` 保留数量。
- 大制品上传制品库后不在 Jenkins 长期保存。
- 清理历史构建。
- 清理 workspace。

## 9.12 参考资料

- [Jenkins archiveArtifacts](https://www.jenkins.io/doc/pipeline/steps/core/#archiveartifacts-archive-the-artifacts)
- [Nexus Repository Documentation](https://help.sonatype.com/en/sonatype-nexus-repository.html)
- [JFrog Artifactory Documentation](https://jfrog.com/help/r/jfrog-artifactory-documentation)
- [GitLab Package Registry](https://docs.gitlab.com/user/packages/package_registry/)
- [Helm OCI Registry](https://helm.sh/docs/topics/registries/)
