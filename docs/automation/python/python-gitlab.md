---
title: Python-GitLab模块
---

# Python GitLab 模块使用指南

python-gitlab 是用于与 GitLab API 交互的 Python 包，提供了完整的 GitLab API 访问功能。

## 1. 安装和配置

### 1.1 安装

```bash
# 使用 pip 安装
pip install python-gitlab
```

### 1.2 基本配置

```python
import gitlab

# 方式1：直接配置
gl = gitlab.Gitlab(
    url='https://gitlab.example.com',
    private_token='your_private_token'
)

# 方式2：从配置文件加载
# 配置文件位置：~/.python-gitlab.cfg
gl = gitlab.Gitlab.from_config('default')

# 验证连接
try:
    gl.auth()
except gitlab.exceptions.GitlabAuthenticationError:
    print("认证失败，请检查token")
```

## 2. 项目操作

### 2.1 获取项目

```python
# 获取所有项目
projects = gl.projects.list()

# 获取指定项目
project = gl.projects.get('group/project_name')
# 或使用项目ID
project = gl.projects.get(project_id)

# 搜索项目
projects = gl.projects.list(search='keyword')

# 获取自己的项目
projects = gl.projects.list(owned=True)
```

### 2.2 创建和修改项目

```python
# 创建新项目
project = gl.projects.create({
    'name': 'project_name',
    'description': '项目描述',
    'visibility': 'private'  # private, internal, public
})

# 修改项目设置
project.description = '新的描述'
project.save()

# 删除项目
project.delete()
```

## 3. 仓库操作

### 3.1 分支管理

```python
# 获取所有分支
branches = project.branches.list()

# 获取特定分支
branch = project.branches.get('branch-name')

# 创建新分支
branch = project.branches.create({
    'branch': 'new-branch',
    'ref': 'main'  # 基于哪个分支/标签创建
})

# 删除分支
project.branches.delete('branch-name')

# 批量删除分支
for branch in project.branches.list():
    if branch.name.startswith('feature/'):
        branch.delete()

# 分支保护
branch = project.branches.get('main')
branch.protect(developers_can_push=False, developers_can_merge=True)
branch.unprotect()  # 取消保护

# 合并分支
project.branches.create({
    'branch': 'source-branch',
    'ref': 'target-branch'
})
```

### 3.2 标签管理

```python
# 获取所有标签
tags = project.tags.list()

# 获取特定标签
tag = project.tags.get('v1.0.0')

# 创建标签
tag = project.tags.create({
    'tag_name': 'v1.0.0',
    'ref': 'main',  # 基于哪个分支/提交创建
    'message': '版本 1.0.0 发布'  # 标签信息
})

# 删除标签
project.tags.delete('v1.0.0')

# 创建带发布说明的标签
tag = project.tags.create({
    'tag_name': 'v1.1.0',
    'ref': 'main',
    'message': '版本 1.1.0 发布',
    'release_description': '''
    # 更新内容
    - 新增功能 A
    - 修复问题 B
    - 优化性能 C
    '''
})

# 获取标签的发布信息
release = tag.release
if release:
    print(f"发布说明: {release.description}")
```

### 3.3 构建产物（Artifacts）操作

```python
# 获取最新的构建产物
job = project.jobs.list(scope=['success'])[0]
artifacts = job.artifacts()

# 下载整个构建产物
with open('artifacts.zip', 'wb') as f:
    job.artifacts(streamed=True, action=f.write)

# 下载单个构建产物
artifact = job.artifact('path/to/file')
with open('file', 'wb') as f:
    f.write(artifact)

# 获取特定 pipeline 的构建产物
pipeline = project.pipelines.get(pipeline_id)
jobs = pipeline.jobs.list()
for job in jobs:
    if job.artifacts_file:
        print(f"Job {job.name} has artifacts")
        # 下载该 job 的构建产物
        with open(f'{job.name}_artifacts.zip', 'wb') as f:
            job.artifacts(streamed=True, action=f.write)

# 获取特定路径的构建产物
def download_artifact(job, artifact_path, local_path):
    try:
        artifact = job.artifact(artifact_path)
        with open(local_path, 'wb') as f:
            f.write(artifact)
        return True
    except Exception as e:
        print(f"下载失败: {e}")
        return False

# 使用示例
job = project.jobs.get(job_id)
download_artifact(job, 'dist/app.zip', 'app.zip')

# 处理构建产物的元数据
if job.artifacts_file:
    print(f"文件大小: {job.artifacts_size}")
    print(f"过期时间: {job.artifacts_expire_at}")

# 遍历并下载所有构建产物
def download_all_artifacts(project, pipeline_id, output_dir):
    pipeline = project.pipelines.get(pipeline_id)
    jobs = pipeline.jobs.list()
    
    for job in jobs:
        if job.artifacts_file:
            output_path = os.path.join(output_dir, f'{job.name}_artifacts.zip')
            with open(output_path, 'wb') as f:
                job.artifacts(streamed=True, action=f.write)
            print(f"已下载 {job.name} 的构建产物")

# 使用示例
os.makedirs('artifacts', exist_ok=True)
download_all_artifacts(project, pipeline_id, 'artifacts')
```

### 3.4 分支和标签的高级操作

```python
# 比较两个分支
comparison = project.repository_compare('main', 'feature-branch')
for commit in comparison['commits']:
    print(f"提交: {commit['id']}: {commit['title']}")
for diff in comparison['diffs']:
    print(f"文件变更: {diff['new_path']}")

# 获取分支的保护规则
protected_branches = project.protectedbranches.list()
for branch in protected_branches:
    print(f"分支: {branch.name}")
    print(f"推送权限: {branch.push_access_levels}")
    print(f"合并权限: {branch.merge_access_levels}")

# 设置复杂的分支保护规则
project.protectedbranches.create({
    'name': 'main',
    'push_access_level': gitlab.const.DEVELOPER_ACCESS,
    'merge_access_level': gitlab.const.MAINTAINER_ACCESS,
    'allow_force_push': False,
    'code_owner_approval_required': True
})

# 批量处理过期分支
stale_branches = []
for branch in project.branches.list():
    last_commit = branch.commit
    commit_date = datetime.strptime(last_commit['created_at'], '%Y-%m-%dT%H:%M:%S.%fZ')
    if (datetime.now() - commit_date).days > 90:  # 90天未更新的分支
        stale_branches.append(branch.name)
        
print(f"发现 {len(stale_branches)} 个过期分支")
```

## 4. 合并请求操作

### 4.1 管理合并请求

```python
# 获取所有合并请求
mrs = project.mergerequests.list()

# 创建合并请求
mr = project.mergerequests.create({
    'source_branch': 'feature-branch',
    'target_branch': 'main',
    'title': '新功能开发',
    'description': '详细描述'
})

# 接受合并请求
mr = project.mergerequests.get(mr_id)
mr.merge()

# 关闭合并请求
mr.state_event = 'close'
mr.save()
```

### 4.2 评审和评论

```python
# 添加评论
mr.notes.create({
    'body': '请修改这部分代码'
})

# 添加评审
mr.approvals.set_approvers([user_id])

# 获取评审状态
approvals = mr.approvals.get()
print(f"需要的评审数: {approvals.approvals_required}")
print(f"已获得的评审数: {approvals.approvals_left}")
```

## 5. Issue 管理

### 5.1 Issue 操作

```python
# 获取所有 issue
issues = project.issues.list()

# 创建 issue
issue = project.issues.create({
    'title': 'Bug报告',
    'description': '详细描述',
    'labels': ['bug', 'critical']
})

# 更新 issue
issue.labels = ['bug', 'fixed']
issue.save()

# 关闭 issue
issue.state_event = 'close'
issue.save()
```

### 5.2 Issue 查询

```python
# 按状态查询
open_issues = project.issues.list(state='opened')
closed_issues = project.issues.list(state='closed')

# 按标签查询
bug_issues = project.issues.list(labels=['bug'])

# 按指派人查询
my_issues = project.issues.list(assignee_id=user_id)
```

## 6. CI/CD 操作

### 6.1 Pipeline 管理

```python
# 获取所有 pipeline
pipelines = project.pipelines.list()

# 获取特定 pipeline
pipeline = project.pipelines.get(pipeline_id)

# 创建新的 pipeline
pipeline = project.pipelines.create({
    'ref': 'main'
})

# 取消 pipeline
pipeline.cancel()
```

### 6.2 Job 操作

```python
# 获取 pipeline 的 jobs
jobs = pipeline.jobs.list()

# 获取 job 日志
job = project.jobs.get(job_id)
log = job.trace()

# 重试失败的 job
job.retry()

# 取消正在运行的 job
job.cancel()
```

## 7. 用户和组管理

### 7.1 用户操作

```python
# 获取所有用户
users = gl.users.list()

# 创建用户
user = gl.users.create({
    'email': 'user@example.com',
    'password': 'password',
    'username': 'username',
    'name': 'User Name'
})

# 删除用户
gl.users.delete(user_id)
```

### 7.2 组操作

```python
# 获取所有组
groups = gl.groups.list()

# 创建组
group = gl.groups.create({
    'name': 'Group Name',
    'path': 'group-path'
})

# 添加成员
group.members.create({
    'user_id': user_id,
    'access_level': gitlab.const.DEVELOPER_ACCESS
})
```

## 注意事项

1. 保护好私人令牌，不要将其提交到代码仓库
2. 使用异常处理捕获 API 调用可能的错误
3. 注意 API 调用频率限制
4. 大量操作时考虑使用分页
5. 某些操作需要特定的权限级别

## 错误处理

```python
from gitlab.exceptions import GitlabError

try:
    project = gl.projects.get('nonexistent/project')
except gitlab.exceptions.GitlabGetError:
    print("项目不存在")
except gitlab.exceptions.GitlabAuthenticationError:
    print("认证失败")
except GitlabError as e:
    print(f"GitLab API 错误: {e}")
``` 