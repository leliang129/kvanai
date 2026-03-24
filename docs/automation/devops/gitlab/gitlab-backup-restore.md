---
title: GitLab 备份与恢复
sidebar_position: 4
---

# GitLab 备份与恢复


官方参考：

- [GitLab 备份与恢复官方文档](https://docs.gitlab.com/ee/raketasks/backup_restore.html)

## 3.6.1 备份相关配置文件

除项目数据外，GitLab 的关键配置必须单独备份，尤其是：

- `/etc/gitlab/gitlab.rb`
- `/etc/gitlab/gitlab-secrets.json`（2FA、加密密钥等依赖此文件）

配置备份命令：

```bash
# 备份配置到默认目录 /etc/gitlab/config_backup/
gitlab-ctl backup-etc

# 指定备份目录
gitlab-ctl backup-etc --backup-path <DIRECTORY>
```

说明：

- 不指定 `--backup-path` 时，默认保存到 `/etc/gitlab/config_backup/`。
- 配置包通常为 `gitlab_config_<timestamp>_<date>.tar` 格式。
- 恢复到新机器时，`gitlab-secrets.json` 非常关键，丢失会导致部分历史数据无法解密。

## 3.6.2 手动备份数据

按版本使用不同命令：

```bash
# GitLab 12.2 及之后
gitlab-backup create

# GitLab 12.1 及之前
gitlab-rake gitlab:backup:create
```

备份参数可在 `/etc/gitlab/gitlab.rb` 调整：

```ruby
# 备份目录
gitlab_rails['backup_path'] = "/var/opt/gitlab/backups"

# 备份文件权限
gitlab_rails['backup_archive_permissions'] = 0644

# 备份保留时长（秒），默认 7 天 = 604800
gitlab_rails['backup_keep_time'] = 604800
```

配置修改后执行：

```bash
gitlab-ctl reconfigure
```

常见结果文件示例：

- `/var/opt/gitlab/backups/1627268555_2021_07_26_14.1.0_gitlab_backup.tar`

## 3.6.5 执行恢复

恢复前提：

- 备份与恢复使用的 GitLab 版本必须一致。
- 建议先还原配置文件（尤其 `gitlab-secrets.json`），再恢复数据。

新版本恢复步骤：

```bash
# 先停写入相关服务
gitlab-ctl stop puma
gitlab-ctl stop sidekiq

# 恢复时只填备份文件名前缀（不含 .tar）
gitlab-backup restore BACKUP=<备份时间戳_日期_版本>

# 恢复后重新加载并重启
gitlab-ctl reconfigure
gitlab-ctl restart
```

旧版本恢复命令：

```bash
gitlab-ctl stop unicorn
gitlab-ctl stop sidekiq
gitlab-rake gitlab:backup:restore BACKUP=<备份时间戳_日期_版本>
gitlab-ctl reconfigure
gitlab-ctl restart
```

可选校验命令：

```bash
gitlab-rake gitlab:check SANITIZE=true
gitlab-rake gitlab:doctor:secrets
gitlab-ctl tail
```

## 3.6.6 确保还原完成

恢复完成后建议检查：

- `gitlab-ctl status` 全部核心组件已恢复运行。
- Web 页面可访问，用户、组、项目数据与预期一致。
- 如页面短时不可访问，通常等待一段时间后可恢复。
- 若之前手动停止过服务，可显式启动：

```bash
gitlab-ctl start sidekiq
gitlab-ctl start unicorn
# 或统一重启
gitlab-ctl restart
```

## 3.6.7 远程备份（S3）

GitLab 支持把备份自动上传到对象存储（S3 或 S3 兼容服务，如 MinIO）。

在 `/etc/gitlab/gitlab.rb` 增加示例配置：

```ruby
# 远程备份：S3
gitlab_rails['backup_upload_connection'] = {
  'provider' => 'AWS',
  'region' => 'ap-southeast-1',
  'aws_access_key_id' => 'AKIAxxxxxxxx',
  'aws_secret_access_key' => 'xxxxxxxx'
}
gitlab_rails['backup_upload_remote_directory'] = 'gitlab-backup-bucket'

# 可选：仅使用实例角色（不写 AK/SK）
# gitlab_rails['backup_upload_connection'] = {
#   'provider' => 'AWS',
#   'region' => 'ap-southeast-1',
#   'use_iam_profile' => true
# }
```

S3 兼容存储（如 MinIO）可补充 endpoint：

```ruby
gitlab_rails['backup_upload_connection'] = {
  'provider' => 'AWS',
  'region' => 'us-east-1',
  'aws_access_key_id' => 'minioadmin',
  'aws_secret_access_key' => 'minioadmin',
  'endpoint' => 'http://minio.example.com:9000',
  'path_style' => true
}
gitlab_rails['backup_upload_remote_directory'] = 'gitlab-backups'
```

应用配置并执行备份：

```bash
gitlab-ctl reconfigure
gitlab-backup create
```

说明：

- `gitlab-backup create` 会先在本地生成备份，再上传到远程桶。
- 建议同时保留本地备份，并对配置文件执行 `gitlab-ctl backup-etc`。
- 如需只做本地备份（跳过远程上传），可用：`gitlab-backup create SKIP=remote`。
