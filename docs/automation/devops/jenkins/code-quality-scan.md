---
title: Jenkins 代码扫描与质量门禁
sidebar_position: 8
---

# Jenkins 代码扫描与质量门禁


## 8.1 扫描目标

代码扫描用于在流水线中尽早发现质量、安全和合规问题。

常见扫描类型：

| 类型 | 工具示例 | 目标 |
| --- | --- | --- |
| 静态代码扫描 | SonarQube、Checkstyle、ESLint、Pylint | 代码质量、重复率、复杂度 |
| 单元测试覆盖率 | JaCoCo、nyc、coverage.py | 覆盖率和测试结果 |
| 依赖漏洞扫描 | OWASP Dependency-Check、Snyk、Trivy FS | 第三方依赖漏洞 |
| 凭据扫描 | Gitleaks、TruffleHog | 防止密钥泄露 |
| 镜像漏洞扫描 | Trivy Image、Harbor Scanner | 容器镜像漏洞 |
| IaC 扫描 | Checkov、tfsec、kube-score | Terraform、K8s YAML、Helm 风险 |

建议扫描顺序：

1. 单元测试。
2. 静态代码扫描。
3. 依赖漏洞扫描。
4. 凭据扫描。
5. Docker 镜像构建。
6. 镜像漏洞扫描。
7. 质量门禁通过后发布。

## 8.2 插件准备

Jenkins 常用插件：

- `SonarQube Scanner`
- `Warnings Next Generation`
- `JUnit`
- `JaCoCo`
- `HTML Publisher`
- `Credentials Binding`

配置入口：

```text
Manage Jenkins -> Plugins
```

全局工具入口：

```text
Manage Jenkins -> Tools
```

## 8.3 SonarQube 集成

### 8.3.1 SonarQube Token

SonarQube 中创建 Token：

```text
My Account -> Security -> Generate Tokens
```

Jenkins 凭据：

```text
Type: Secret text
ID: sonarqube-token
```

### 8.3.2 Jenkins 全局配置

入口：

```text
Manage Jenkins -> System -> SonarQube servers
```

配置：

| 配置项 | 示例 |
| --- | --- |
| `Name` | `sonarqube` |
| `Server URL` | `https://sonar.example.com` |
| `Server authentication token` | `sonarqube-token` |

工具配置：

```text
Manage Jenkins -> Tools -> SonarQube Scanner
```

名称示例：

```text
sonar-scanner
```

## 8.4 Maven 项目扫描

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && maven'
    }

    tools {
        jdk 'jdk21'
        maven 'maven-3.9'
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                sh 'mvn -B clean test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh '''
                        mvn -B sonar:sonar \
                          -Dsonar.projectKey=demo-service \
                          -Dsonar.projectName=demo-service
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
    }
}
```

说明：

- `withSonarQubeEnv('sonarqube')` 名称要和 Jenkins 全局 SonarQube 配置一致。
- `waitForQualityGate` 需要 SonarQube Webhook 回调 Jenkins。

SonarQube Webhook：

```text
SonarQube -> Administration -> Configuration -> Webhooks
```

URL 示例：

```text
https://jenkins.example.com/sonarqube-webhook/
```

## 8.5 Node.js 项目扫描

```groovy title="Jenkinsfile"
pipeline {
    agent {
        label 'linux && nodejs'
    }

    tools {
        nodejs 'node-20'
    }

    stages {
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

        stage('Test') {
            steps {
                sh 'npm run test -- --coverage'
            }
        }

        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=demo-web \
                          -Dsonar.sources=src \
                          -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                    '''
                }
            }
        }
    }
}
```

## 8.6 依赖漏洞扫描

### 8.6.1 OWASP Dependency-Check

```groovy
stage('Dependency Check') {
    steps {
        sh '''
            dependency-check.sh \
              --project demo-service \
              --scan . \
              --format HTML \
              --format XML \
              --out dependency-check-report
        '''
    }
    post {
        always {
            archiveArtifacts artifacts: 'dependency-check-report/**', allowEmptyArchive: true
            publishHTML([
                reportDir: 'dependency-check-report',
                reportFiles: 'dependency-check-report.html',
                reportName: 'Dependency Check Report',
                keepAll: true,
                alwaysLinkToLastBuild: true,
                allowMissing: true
            ])
        }
    }
}
```

### 8.6.2 Trivy FS

```groovy
stage('Dependency Scan') {
    steps {
        sh '''
            trivy fs \
              --exit-code 1 \
              --severity HIGH,CRITICAL \
              .
        '''
    }
}
```

建议：

- MR 阶段可以只扫描 HIGH、CRITICAL。
- 首次接入可以先不阻断，只输出报告。
- 稳定后再逐步启用质量门禁。

## 8.7 凭据扫描

使用 Gitleaks：

```groovy
stage('Secret Scan') {
    steps {
        sh '''
            gitleaks detect \
              --source . \
              --report-format json \
              --report-path gitleaks-report.json \
              --exit-code 1
        '''
    }
    post {
        always {
            archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
        }
    }
}
```

建议：

- 凭据扫描应尽早执行。
- 发现泄露后应立即废止 Token，而不是只删除代码。
- 历史提交中的密钥也需要处理。

## 8.8 镜像漏洞扫描

镜像构建后使用 Trivy：

```groovy
stage('Image Scan') {
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

Harbor 也可以在镜像推送后自动扫描。常见做法：

- Jenkins 推送镜像到 Harbor。
- Harbor 自动触发扫描。
- Jenkins 或发布平台读取扫描结果。
- 不满足安全策略时禁止发布生产。

## 8.9 质量门禁策略

建议按阶段逐步收紧：

| 阶段 | 策略 |
| --- | --- |
| 接入初期 | 只生成报告，不阻断 |
| 稳定期 | 阻断 Critical 漏洞和测试失败 |
| 生产发布 | 阻断质量门禁失败、高危漏洞、凭据泄露 |

常见门禁：

- 单元测试必须通过。
- 覆盖率不低于团队阈值。
- SonarQube Quality Gate 必须通过。
- 不允许新增 Critical 漏洞。
- 不允许凭据泄露。
- 主分支和生产发布执行更严格策略。

分支策略示例：

```groovy
stage('Quality Gate') {
    when {
        anyOf {
            branch 'main'
            branch 'release/*'
        }
    }
    steps {
        timeout(time: 5, unit: 'MINUTES') {
            waitForQualityGate abortPipeline: true
        }
    }
}
```

## 8.10 MR 场景建议

Merge Request 流水线建议执行：

- 编译。
- 单元测试。
- Lint。
- SonarQube 扫描。
- 依赖漏洞扫描。
- 凭据扫描。

不建议执行：

- 推送生产镜像。
- 部署生产环境。
- 注入生产凭据。

示例：

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
        sh './deploy.sh'
    }
}
```

## 8.11 常见问题

### 8.11.1 waitForQualityGate 一直等待

排查：

- SonarQube Webhook 是否配置。
- Webhook URL 是否为 `/sonarqube-webhook/`。
- SonarQube 是否能访问 Jenkins。
- Jenkins 中 SonarQube server name 是否正确。

### 8.11.2 SonarQube 扫描失败

常见原因：

- Token 无效。
- `sonar.projectKey` 重复或无权限。
- Jenkins Agent 无法访问 SonarQube。
- Java 或 scanner 版本不兼容。
- 代码路径或报告路径错误。

### 8.11.3 扫描太慢

优化：

- 缓存依赖目录。
- 合理排除无关目录。
- MR 只扫描变更相关内容，主分支全量扫描。
- 大仓库拆分模块扫描。

### 8.11.4 报告没有展示

检查：

- 是否安装 `HTML Publisher`。
- 报告路径是否正确。
- `allowMissing` 是否掩盖了路径错误。
- 构建后归档是否执行。

## 8.12 参考资料

- [Jenkins SonarQube Scanner Plugin](https://plugins.jenkins.io/sonar/)
- [SonarQube Jenkins Extension](https://docs.sonarsource.com/sonarqube-server/latest/analyzing-source-code/ci-integration/jenkins-integration/)
- [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)
- [Trivy Documentation](https://trivy.dev/latest/)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
