---
title: python脚本
sidebar_position: 1
---

# python常用脚本

## 备份文件到远程服务器

下面这个脚本用于自动处理历史日志备份，适合部署在应用服务器或日志节点上定时执行。

实现功能：

- 查找指定目录下 7 天前的 `.log` 日志文件。
- 将匹配到的日志文件打包成一个 `tar.gz` 压缩包。
- 压缩包上传到远程备份服务器。
- 上传成功后删除原始日志文件。
- 任务结束后发送通知报告。

说明：

- 为了避免数据丢失，脚本会在“压缩包创建成功且上传成功”之后再删除原始日志文件。
- 通知部分默认使用 Webhook，可以按企业微信、飞书、钉钉、Slack 的要求调整消息体格式。

### 安装依赖

```bash
pip install paramiko requests
```

### 脚本代码

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import glob
import tarfile
import time
import subprocess
import requests
from datetime import datetime, timedelta

# ------------------- 1. 配置参数 -------------------
LOG_DIR = "/data/logs"  # 日志目录
BACKUP_SERVER = "backup-server.com"  # 远程备份服务器
REMOTE_DIR = "/backup/logs"  # 远程存放路径
WEBHOOK_URL = "https://dingtalk-webhook-url"  # 钉钉/企业微信 Webhook
DAYS_BEFORE = 7  # 7天前

# ------------------- 2. 核心工具函数 -------------------
def send_notification(status, msg):
    """发送通知到钉钉/企业微信"""
    headers = {"Content-Type": "application/json"}
    text = f"### 日志备份任务执行报告\n> **状态**: {status}\n> **时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n> **详情**: {msg}"
    payload = {"msgtype": "markdown", "markdown": {"title": "日志备份报告", "text": text}}
    try:
        requests.post(WEBHOOK_URL, json=payload, headers=headers, timeout=10)
    except Exception as e:
        print(f"通知发送失败: {e}")

def clean_and_package_logs():
    """
    步骤1-3: 查找7天前日志 -> 打包 -> 清理原文件
    返回: 打包后的文件路径
    """
    cutoff = time.time() - DAYS_BEFORE * 86400
    tar_filename = f"logs_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.tar.gz"
    tar_path = os.path.join("/tmp", tar_filename)

    print(f"查找 {LOG_DIR} 下 {DAYS_BEFORE}天前的 .log 文件...")
    # 查找所有.log文件
    log_files = glob.glob(os.path.join(LOG_DIR, "**/*.log"), recursive=True)
    old_logs = [f for f in log_files if os.path.getmtime(f) < cutoff]

    if not old_logs:
        print("未找到需要备份的日志文件。")
        send_notification("✅ 成功", "未找到7天前的日志文件，无需备份。")
        return None

    # 打包
    with tarfile.open(tar_path, "w:gz") as tar:
        for log in old_logs:
            print(f"添加文件: {log}")
            tar.add(log, arcname=os.path.relpath(log, LOG_DIR))
    
    # 清理原文件 (保留压缩包)
    for log in old_logs:
        try:
            os.remove(log)
            print(f"已删除: {log}")
        except OSError as e:
            print(f"删除失败 {log}: {e}")
    
    print(f"打包完成: {tar_path}")
    return tar_path

def upload_to_remote(local_file):
    """
    步骤4: 使用SCP上传到远程服务器 (假设已配置SSH免密)
    """
    if not local_file or not os.path.exists(local_file):
        return False
    
    remote_path = f"{BACKUP_SERVER}:{REMOTE_DIR}/"
    print(f"开始上传 {local_file} 到 {remote_path}")
    
    # 使用 subprocess 调用系统 scp 命令 (更稳定高效)
    try:
        result = subprocess.run(
            ["scp", local_file, remote_path],
            check=True,
            capture_output=True,
            text=True
        )
        print("上传成功!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"上传失败: {e.stderr}")
        return False

# ------------------- 3. 主程序 -------------------
if __name__ == "__main__":
    try:
        # 执行备份流程
        tar_file = clean_and_package_logs()
        
        if tar_file:
            upload_success = upload_to_remote(tar_file)
            
            # 发送最终报告
            if upload_success:
                send_notification("✅ 成功", f"日志已成功打包并上传至 {REMOTE_DIR}。")
            else:
                send_notification("❌ 失败", f"日志打包成功，但上传远程服务器失败。")
        
        # 即使无文件也已在函数内通知，此处无需重复操作

    except Exception as e:
        error_msg = f"脚本执行发生异常: {str(e)}"
        print(error_msg)
        send_notification("❌ 异常", error_msg)
```

### 使用示例

```bash
python3 log_backup.py \
  --log-dir /var/log/myapp \
  --days 7 \
  --remote-host 192.168.1.50 \
  --remote-port 22 \
  --remote-user backup \
  --remote-password 'YourPassword' \
  --remote-dir /data/backup/myapp \
  --webhook-url https://example.com/webhook/log-backup
```

### 建议配合定时任务使用

```bash
crontab -e
```

```cron
30 2 * * * /usr/bin/python3 /opt/scripts/log_backup.py --log-dir /var/log/myapp --days 7 --remote-host 192.168.1.50 --remote-user backup --remote-password 'YourPassword' --remote-dir /data/backup/myapp --webhook-url https://example.com/webhook/log-backup >> /var/log/log_backup.log 2>&1
```

### 可继续优化的方向

- 把远程密码改为 SSH 私钥认证，避免命令行暴露密码。
- 把通知封装成企业微信、飞书、钉钉专用消息格式。
- 增加 `--dry-run` 参数，先只打印待处理文件，不真正删除和上传。
- 增加失败重试机制和归档校验，例如比较文件大小或校验和。

## GitLab脚本

### 安装依赖

```bash
pip install python-gitlab
pip install pandas openpyxl
```

### 环境变量

```bash
cat /etc/profile.d/gitlab.sh

GITLAB_URL=https://gitlab.example.com
GITLAB_TOKEN=---
```

## GitLab创建tag

```python
import gitlab


class ManagerTag:
    def __init__(self, gitlab_url, gitlab_token, project_name, branch, tag):
        """
        初始化Gitlab连接和项目信息

        参数:
        gitlab_url: str - Gitlab的URL地址
        gitlab_token: str - 访问Gitlab的个人访问令牌
        project_name: str - Gitlab上的项目名称或ID
        branch: str - 代码分支名称
        tag: str - 代码标签名称
        """
        self.gl = gitlab.Gitlab(gitlab_url, private_token=gitlab_token)
        self.project_name = project_name
        self.branch = branch
        self.tag = tag

    def create_tag(self):
        project = self.gl.projects.get(self.project_name)
        commit = project.commits.get(self.branch)
        project.tags.create({"tag_name": self.tag, "ref": commit.id})
        print(f"标签：{self.tag} 创建成功。")


if __name__ == "__main__":
    gitlab_url = "https://gitlab.examples.com"
    access_token = "xxxxxxxxxxxxx"
    project = "216"
    branch = "main"
    tag = "v0.0.1"

    create_tag_obj = ManagerTag(
        gitlab_url=gitlab_url,
        gitlab_token=access_token,
        project_name=project,
        branch=branch,
        tag=tag,
    )
    create_tag_obj.create_tag()
```

## 删除GitLab所有标签

```python
import gitlab

GITLAB_URL = "https://gitlab.examples.com"
PRIVATE_TOKEN = "---"
PROJECT_ID = "216"

gl = gitlab.Gitlab(GITLAB_URL, private_token=PRIVATE_TOKEN)
project = gl.projects.get(PROJECT_ID)
tags = project.tags.list(all=True)

for tag in tags:
    print(f"Deleting tag: {tag.name}")
    tag.delete()

print("All tags have been deleted successfully.")
```

## 删除GitLab指定标签

```python
import gitlab

GITLAB_URL = "https://gitlab.examples.com"
PRIVATE_TOKEN = "---"
PROJECT_ID = "216"
TAG_NAME = "v0.0.1"

gl = gitlab.Gitlab(GITLAB_URL, private_token=PRIVATE_TOKEN)
project = gl.projects.get(PROJECT_ID)

try:
    tag = project.tags.get(TAG_NAME)
    tag.delete()
    print(f"Tag {TAG_NAME} has been deleted successfully.")
except gitlab.exceptions.GitlabGetError:
    print(f"Tag {TAG_NAME} does not exist.")
```

## 下载GitLab Artifacts制品

```python
import gitlab
import os
from typing import Optional, List
from datetime import datetime


class GitlabClient:
    def __init__(self, url: str, private_token: str):
        self.gl = gitlab.Gitlab(url=url, private_token=private_token)
        self.token = private_token

    def get_project(self, project_id: int):
        try:
            return self.gl.projects.get(project_id)
        except gitlab.exceptions.GitlabGetError:
            print(f"错误: 未找到ID为 {project_id} 的项目")
            return None

    def get_job_artifacts(
        self,
        project_id: int,
        job_id: Optional[int] = None,
        pipeline_id: Optional[int] = None,
        ref: str = "main",
        download_path: str = "artifacts",
    ) -> List[str]:
        project = self.get_project(project_id)
        if not project:
            return []

        downloaded_files = []

        try:
            if job_id:
                job = project.jobs.get(job_id)
                file_path = self._download_artifact(project, job, download_path)
                if file_path:
                    downloaded_files.append(file_path)
            elif pipeline_id:
                pipeline = project.pipelines.get(pipeline_id)
                jobs = pipeline.jobs.list(all=True)
                for job in jobs:
                    if job.artifacts:
                        file_path = self._download_artifact(project, job, download_path)
                        if file_path:
                            downloaded_files.append(file_path)
            else:
                pipelines = project.pipelines.list(ref=ref, status="success")
                if pipelines:
                    latest_pipeline = pipelines[0]
                    jobs = latest_pipeline.jobs.list(all=True)
                    for job in jobs:
                        if job.artifacts:
                            file_path = self._download_artifact(project, job, download_path)
                            if file_path:
                                downloaded_files.append(file_path)
        except Exception as e:
            print(f"下载制品时发生错误: {str(e)}")

        return downloaded_files

    def _download_artifact(self, project, job, download_path: str) -> Optional[str]:
        try:
            os.makedirs(download_path, exist_ok=True)

            try:
                if isinstance(job.finished_at, str):
                    finished_time = datetime.strptime(job.finished_at, "%Y-%m-%dT%H:%M:%S.%fZ")
                else:
                    finished_time = datetime.fromtimestamp(job.finished_at)

                timestamp = finished_time.strftime("%Y%m%d_%H%M%S")
            except (TypeError, ValueError):
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

            filename = f"{project.path}_{job.name}_{timestamp}.zip"
            file_path = os.path.join(download_path, filename)

            with open(file_path, "wb") as f:
                job.artifacts(streamed=True, action=f.write)

            print(f"成功下载制品: {file_path}")
            return file_path
        except Exception as e:
            print(f"下载制品 {job.name} 时发生错误: {str(e)}")
            return None

    def get_latest_job_artifacts(self, project_id: int, download_path: str = "artifacts") -> List[str]:
        project = self.get_project(project_id)
        if not project:
            return []

        downloaded_files = []

        try:
            jobs = project.jobs.list(all=False, order_by="id", sort="desc")

            if not jobs:
                print(f"项目 {project_id} 没有找到任何job")
                return []

            latest_job_with_artifacts = None
            for job in jobs:
                if job.artifacts:
                    latest_job_with_artifacts = job
                    break

            if latest_job_with_artifacts:
                print(f"找到最近的job: {latest_job_with_artifacts.name} (ID: {latest_job_with_artifacts.id})")
                file_path = self._download_artifact(project, latest_job_with_artifacts, download_path)
                if file_path:
                    downloaded_files.append(file_path)
            else:
                print(f"项目 {project_id} 没有找到任何制品")
        except Exception as e:
            print(f"获取最近制品时发生错误: {str(e)}")

        return downloaded_files


def main():
    import argparse

    parser = argparse.ArgumentParser(description="GitLab制品下载工具")
    parser.add_argument("--project-id", type=int, required=True, help="项目ID")
    parser.add_argument("--job-id", type=int, help="指定的任务ID")
    parser.add_argument("--pipeline-id", type=int, help="指定的流水线ID")
    parser.add_argument("--ref", default="main", help="分支名称，默认为main")
    parser.add_argument("--path", default="artifacts", help="下载保存路径，默认为artifacts")
    parser.add_argument("--latest", action="store_true", help="获取最近一次运行的job制品")
    args = parser.parse_args()

    gitlab_url = os.getenv("GITLAB_URL", "https://gitlab.example.com")
    gitlab_token = os.getenv("GITLAB_TOKEN")

    if not gitlab_token:
        raise ValueError("请设置GITLAB_TOKEN环境变量")

    client = GitlabClient(gitlab_url, gitlab_token)

    if args.latest:
        downloaded_files = client.get_latest_job_artifacts(
            project_id=args.project_id,
            download_path=args.path,
        )
    else:
        downloaded_files = client.get_job_artifacts(
            project_id=args.project_id,
            job_id=args.job_id,
            pipeline_id=args.pipeline_id,
            ref=args.ref,
            download_path=args.path,
        )

    if downloaded_files:
        print(f"\n成功下载 {len(downloaded_files)} 个制品:")
        for file_path in downloaded_files:
            print(f"- {file_path}")
    else:
        print("未找到可下载的制品")


if __name__ == "__main__":
    main()
```

使用示例：

```bash
python3 gitlab_download_artifacts.py --project-id 123 --job-id 456 --path ./artifacts
```

## 获取GitLab项目并导出Excel

```python
import gitlab
import os
from typing import List, Dict
import pandas as pd
from datetime import datetime


class GitLabClient:
    def __init__(self, url: str, private_token: str):
        self.gl = gitlab.Gitlab(url=url, private_token=private_token)

    def get_group_path(self, project) -> tuple:
        path_parts = project.path_with_namespace.split("/")
        if len(path_parts) == 1:
            return ("", "", "")
        if len(path_parts) == 2:
            return (path_parts[0], "", "")
        if len(path_parts) == 3:
            return (path_parts[0], path_parts[1], "")
        return (path_parts[0], path_parts[1], "/".join(path_parts[2:-1]))

    def get_projects(self) -> List[Dict]:
        projects = self.gl.projects.list(all=True)
        project_list = []

        for project in projects:
            group, subgroup1, subgroup2 = self.get_group_path(project)

            if group.lower() == "sdkdemo":
                project_info = {
                    "group": group,
                    "subgroup1": subgroup1,
                    "subgroup2": subgroup2,
                    "name": project.name,
                    "description": project.description or "",
                    "maintainer": self.get_project_maintainer(project),
                    "is_delivered": "",
                    "dependencies": "",
                }
                project_list.append(project_info)

        project_list.sort(key=lambda x: (x["subgroup2"] or "", x["subgroup1"] or "", x["name"]))
        return project_list

    def get_project_maintainer(self, project) -> str:
        try:
            members = project.members.list(all=True)
            maintainers = [member.username for member in members if member.access_level >= 40]
            return ", ".join(maintainers) if maintainers else ""
        except Exception:
            return ""

    @staticmethod
    def read_projects_from_excel(file_path: str) -> None:
        try:
            df = pd.read_excel(file_path)
            print(f"从文件 {file_path} 中读取到 {len(df)} 个项目:")

            projects = df.to_dict("records")
            for project in projects:
                print(f"\n组: {project['组']}")
                print(f"一级子组: {project['一级子组']}")
                print(f"二级子组: {project['二级子组']}")
                print(f"项目名称: {project['项目名称']}")
                print(f"项目描述: {project['项目描述']}")
                print(f"主程序员: {project['主程序员']}")
                print(f"是否交付: {project['是否交付']}")
                print(f"依赖工程: {project['依赖工程']}")
        except FileNotFoundError:
            print(f"错误: 文件 {file_path} 不存在")
        except Exception as e:
            print(f"读取文件时发生错误: {str(e)}")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="GitLab项目信息处理工具")
    parser.add_argument("--read-excel", type=str, help="从指定的Excel文件读取项目信息")
    args = parser.parse_args()

    if args.read_excel:
        GitLabClient.read_projects_from_excel(args.read_excel)
    else:
        gitlab_url = os.getenv("GITLAB_URL", "https://gitlab.example.com")
        gitlab_token = os.getenv("GITLAB_TOKEN")

        if not gitlab_token:
            raise ValueError("请设置GITLAB_TOKEN环境变量")

        client = GitLabClient(gitlab_url, gitlab_token)
        projects = client.get_projects()

        df = pd.DataFrame(projects)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file = f"sdkdemo_projects_{timestamp}.xlsx"

        column_mapping = {
            "group": "组",
            "subgroup1": "一级子组",
            "subgroup2": "二级子组",
            "name": "项目名称",
            "description": "项目描述",
            "maintainer": "主程序员",
            "is_delivered": "是否交付",
            "dependencies": "依赖工程",
        }

        df = df[column_mapping.keys()]
        df.rename(columns=column_mapping, inplace=True)

        with pd.ExcelWriter(output_file, engine="openpyxl") as writer:
            df.to_excel(writer, index=False, sheet_name="GitLab项目列表")
            worksheet = writer.sheets["GitLab项目列表"]

            for column in worksheet.columns:
                max_length = 0
                column_letter = column[0].column_letter
                for cell in column:
                    try:
                        if len(str(cell.value)) > max_length:
                            max_length = len(str(cell.value))
                    except Exception:
                        pass
                worksheet.column_dimensions[column_letter].width = max_length + 2

        print(f"\n数据已导出到文件: {output_file}")

        current_subgroup2 = None
        for project in projects:
            if project["subgroup2"] != current_subgroup2:
                current_subgroup2 = project["subgroup2"]
                print(f"\n\n=== 二级子组: {current_subgroup2 or '无'} ===")

            print(f"\n项目名称: {project['name']}")
            print(f"一级子组: {project['subgroup1']}")
            print(f"项目描述: {project['description']}")
            print(f"主程序员: {project['maintainer']}")


if __name__ == "__main__":
    main()
```
