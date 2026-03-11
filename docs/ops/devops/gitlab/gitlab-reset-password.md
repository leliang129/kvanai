---
title: GitLab 重置忘记的密码
sidebar_position: 7
---

# GitLab 重置忘记的密码


官方参考：

- [GitLab 官方重置密码文档](https://docs.gitlab.com/ee/security/reset_user_password.html#reset-the-root-password)

## 3.10.1 进入 GitLab Rails 控制台

```bash
gitlab-rails console -e production
```

说明：

- 启动控制台可能较慢，等待环境加载完成后再执行后续命令。

## 3.10.2 查找 root 用户

可使用任一方式：

```ruby
user = User.find_by_username 'root'
```

或：

```ruby
user = User.where(id: 1).first
```

## 3.10.3 重置密码并保存

```ruby
user.password = "NewStrongPassword"
user.password_confirmation = "NewStrongPassword"
user.save
```

退出控制台：

```ruby
quit
```

## 3.10.4 验证登录

- 使用新密码重新登录 GitLab。
- 建议使用 `external_url` 对应的标准访问地址登录（与配置保持一致）。
- 新密码应满足复杂度要求（至少 8 位并包含足够复杂度）。
