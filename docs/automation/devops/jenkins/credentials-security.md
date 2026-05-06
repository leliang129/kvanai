---
title: Jenkins 凭据与权限管理
sidebar_position: 7
---

# Jenkins 凭据与权限管理


## 7.1 安全模型

Jenkins 安全主要分为两层：

| 层级 | 说明 |
| --- | --- |
| 认证 Authentication | 判断用户是谁，如本地用户、LDAP、OAuth |
| 授权 Authorization | 判断用户能做什么，如查看 Job、触发构建、配置凭据 |

生产环境建议：

- 禁止匿名用户访问。
- 使用专用管理员账号，避免多人共用 `admin`。
- 普通开发者只授予必要 Job 或 Folder 权限。
- 凭据按 Folder 或项目隔离，不全部放在 Global。
- MR / Fork 构建不要暴露生产凭据。
- Controller 不直接跑不可信构建，构建任务放到 Agent 执行。

安全配置入口：

```text
Manage Jenkins -> Security
```

## 7.2 认证方式

常见认证方式：

| 方式 | 说明 | 适用场景 |
| --- | --- | --- |
| Jenkins 本地用户 | Jenkins 自带用户库 | 小团队、测试环境 |
| LDAP / AD | 对接企业目录 | 企业内部统一账号 |
| GitLab OAuth | 使用 GitLab 登录 Jenkins | GitLab 作为统一身份源 |
| GitHub OAuth | 使用 GitHub 登录 Jenkins | GitHub 组织项目 |
| OIDC / SAML | 对接统一身份平台 | 企业 SSO |

建议：

- 生产环境优先对接企业统一身份源。
- 管理员账号开启强密码和最小人数原则。
- 离职账号要能统一禁用。
- Jenkins API Token 与登录密码分开管理。

## 7.3 授权策略

常见授权插件：

- `Matrix Authorization Strategy`
- `Role-based Authorization Strategy`
- `Folders`

### 7.3.1 Matrix Authorization Strategy

矩阵权限适合小规模 Jenkins：

- 按用户或组直接配置权限。
- 权限清晰，但用户和项目多时维护成本较高。

常见权限：

| 权限 | 说明 |
| --- | --- |
| `Overall/Administer` | Jenkins 管理员权限 |
| `Overall/Read` | 访问 Jenkins |
| `Job/Read` | 查看 Job |
| `Job/Build` | 触发构建 |
| `Job/Configure` | 修改 Job 配置 |
| `Job/Cancel` | 停止构建 |
| `Credentials/View` | 查看凭据元信息 |
| `Credentials/Create` | 创建凭据 |
| `Credentials/Update` | 修改凭据 |

### 7.3.2 Role-based Authorization Strategy

角色权限适合团队和项目较多的 Jenkins。

常见角色设计：

| 角色 | 权限 |
| --- | --- |
| `jenkins-admin` | 管理 Jenkins 全局配置 |
| `project-admin` | 管理指定 Folder 下的 Job 和凭据 |
| `developer` | 查看和触发构建 |
| `viewer` | 只读查看 |
| `release-manager` | 发布审批和生产部署 |

建议：

- 用 Folder 隔离团队或业务线。
- 每个 Folder 绑定独立项目角色。
- 生产发布权限单独授予。
- 不给普通开发者 `Overall/Administer`。

### 7.3.3 Folder 级权限

Folder 是 Jenkins 多团队隔离的基础。

建议结构：

```text
Jenkins
├── devops
├── frontend
├── backend
├── data-platform
└── production
```

Folder 可以隔离：

- Job。
- 凭据。
- 视图。
- 权限。

生产环境建议把项目凭据放在对应 Folder 中，避免所有 Job 都能读取 Global 凭据。

## 7.4 凭据类型

配置入口：

```text
Manage Jenkins -> Credentials
```

常见凭据类型：

| 类型 | 场景 |
| --- | --- |
| `Username with password` | Git HTTP、Docker Registry、Harbor、HTTP API |
| `Secret text` | Token、Webhook、API Key |
| `Secret file` | kubeconfig、证书文件、配置文件 |
| `SSH Username with private key` | Git SSH、SSH 部署、Agent 连接 |
| `Certificate` | 证书认证 |
| `GitLab API token` | GitLab 插件访问 API |

命名建议：

```text
gitlab-http-token
gitlab-api-token
docker-registry
harbor-prod
kubeconfig-test
kubeconfig-prod
prod-ssh-key
dingtalk-webhook
```

## 7.5 凭据作用域

常见作用域：

| 作用域 | 说明 |
| --- | --- |
| Global | 全局可用，所有有权限的 Job 都可能读取 |
| System | Jenkins 系统内部使用 |
| Folder | Folder 内 Job 可用 |
| Job | 单个 Job 可用，具体能力取决于插件和配置 |

建议：

- 测试凭据可以放在团队 Folder。
- 生产凭据单独放生产 Folder。
- 全局凭据只放确实需要全局共享的内容。
- 不同环境使用不同凭据 ID，例如 `kubeconfig-test`、`kubeconfig-prod`。

## 7.6 Pipeline 使用凭据

### 7.6.1 credentials helper

Secret text：

```groovy
pipeline {
    agent any

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
}
```

用户名密码：

```groovy
environment {
    REGISTRY_AUTH = credentials('docker-registry')
}
```

会生成：

| 变量 | 说明 |
| --- | --- |
| `REGISTRY_AUTH` | `username:password` |
| `REGISTRY_AUTH_USR` | 用户名 |
| `REGISTRY_AUTH_PSW` | 密码 |

### 7.6.2 withCredentials

更推荐使用 `withCredentials`，把凭据限制在小范围内。

用户名密码：

```groovy
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
    '''
}
```

Secret text：

```groovy
withCredentials([
    string(credentialsId: 'gitlab-api-token', variable: 'GITLAB_TOKEN')
]) {
    sh '''
        curl -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
          https://gitlab.example.com/api/v4/projects
    '''
}
```

Secret file：

```groovy
withCredentials([
    file(credentialsId: 'kubeconfig-test', variable: 'KUBECONFIG')
]) {
    sh 'kubectl get ns'
}
```

SSH Key：

```groovy
withCredentials([
    sshUserPrivateKey(
        credentialsId: 'prod-ssh-key',
        keyFileVariable: 'SSH_KEY',
        usernameVariable: 'SSH_USER'
    )
]) {
    sh '''
        ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no \
          "${SSH_USER}@10.0.0.10" "hostname"
    '''
}
```

## 7.7 凭据安全规范

必须遵守：

- 不在 Jenkinsfile、共享库、Shell 脚本中写明文密码。
- 不打印完整 `printenv` 到长期日志。
- 不在共享库中硬编码生产凭据 ID。
- 不把生产凭据暴露给 MR / Fork 构建。
- 不把 kubeconfig、私钥、Token 放入构建产物。
- 不用个人账号 Token 作为长期生产凭据。
- 凭据要定期轮换，离职人员相关 Token 立即废止。

Shell 注意事项：

```groovy
withCredentials([
    string(credentialsId: 'api-token', variable: 'API_TOKEN')
]) {
    sh '''
        set +x
        curl -H "Authorization: Bearer ${API_TOKEN}" https://api.example.com/health
    '''
}
```

建议：

- 敏感命令前使用 `set +x`，避免 shell trace 泄露。
- 使用 `--password-stdin`，不要把密码放在命令行参数中。
- 凭据变量只在 `withCredentials` 作用域内使用。

## 7.8 MR / Fork 构建安全

Merge Request 和 Fork 构建风险较高，因为 Jenkinsfile 可能来自未完全信任的代码。

建议：

- MR 构建只做编译、测试、扫描。
- MR 构建不推送生产镜像。
- MR 构建不部署生产环境。
- Fork MR 默认不注入敏感凭据。
- 生产发布只允许受保护分支触发，例如 `main`、`release/*`。
- 使用 `input` 审批和 Jenkins 权限控制生产发布。

示例：

```groovy
stage('Deploy Prod') {
    when {
        allOf {
            branch 'main'
            not {
                changeRequest()
            }
        }
    }
    steps {
        input message: '确认发布生产环境？', ok: '发布'
        sh './deploy-prod.sh'
    }
}
```

## 7.9 常见问题

### 7.9.1 凭据找不到

排查方向：

- `credentialsId` 是否拼写正确。
- 凭据是否在当前 Job 可见的作用域中。
- 当前用户或 Job 是否有权限读取凭据。
- Folder 凭据是否被放到了错误 Folder。

### 7.9.2 Shell 中变量为空

常见原因：

- 在 `withCredentials` 外使用凭据变量。
- Groovy 字符串和 Shell 变量混用。
- 变量名写错。

建议：

```groovy
withCredentials([
    string(credentialsId: 'api-token', variable: 'API_TOKEN')
]) {
    sh '''
        test -n "${API_TOKEN}"
        curl -H "Authorization: Bearer ${API_TOKEN}" https://api.example.com
    '''
}
```

### 7.9.3 SSH Key 无法使用

排查方向：

- 私钥格式是否正确。
- GitLab 或目标服务器是否添加了公钥。
- 目标用户是否正确。
- Jenkins Agent 是否能访问目标服务器。
- SSH known_hosts 是否校验失败。

### 7.9.4 kubeconfig 无权限

排查方向：

- kubeconfig 是否有效。
- ServiceAccount 是否有目标 namespace 权限。
- Jenkins Agent 是否能访问 Kubernetes API Server。
- kubeconfig 是否引用了本地不存在的证书文件。

### 7.9.5 日志中显示星号但命令失败

Jenkins 会对部分凭据做日志脱敏，显示为 `****`。这只表示日志被掩码，不代表命令拿到的值正确。

排查方式：

- 检查凭据值是否过期。
- 检查凭据类型是否匹配。
- 使用不泄露内容的方式验证变量非空。
- 检查目标服务返回的错误码。

## 7.10 参考资料

- [Jenkins Credentials 官方文档](https://www.jenkins.io/doc/book/using/using-credentials/)
- [Credentials Binding Plugin](https://plugins.jenkins.io/credentials-binding/)
- [Role-based Authorization Strategy](https://plugins.jenkins.io/role-strategy/)
- [Matrix Authorization Strategy](https://plugins.jenkins.io/matrix-auth/)
