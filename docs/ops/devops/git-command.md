---
title: Git 命令简要说明
sidebar_position: 2
---

# Git 命令简要说明

本文是 Git 常用命令的精简速查版，按日常开发流程整理，优先覆盖高频场景。

## 1. 初始化与克隆

```bash
# 初始化本地仓库
git init

# 克隆远程仓库
git clone <repo-url>
```

- `git init`：把当前目录变成 Git 仓库。
- `git clone`：下载远程仓库并自动配置 `origin`。

## 2. 基础状态查看

```bash
# 查看工作区状态
git status

# 查看提交历史（单行）
git log --oneline --graph --decorate -20

# 查看当前分支
git branch --show-current
```

- `git status`：最常用，先看状态再操作。
- `git log --oneline`：快速看提交链路。

## 3. 添加与提交

```bash
# 添加单个文件
git add <file>

# 添加所有变更
git add .

# 提交
git commit -m "feat: add xxx"
```

- `git add`：把变更放入暂存区。
- `git commit`：生成一次提交记录。

## 4. 分支管理

```bash
# 新建并切换分支
git switch -c feature/login

# 切换分支
git switch main

# 查看分支
git branch -a

# 删除本地分支
git branch -d feature/login
```

- 建议每个功能一个分支，避免直接在 `main` 开发。

## 5. 同步远程

```bash
# 拉取并合并
git pull

# 拉取但不自动合并
git fetch

# 推送当前分支
git push origin <branch>

# 首次推送并设置上游
git push -u origin <branch>
```

- `git pull` = `fetch + merge`。
- 更稳妥的方式是先 `fetch` 再手动处理合并。

## 6. 差异与回退

```bash
# 查看工作区差异
git diff

# 查看暂存区差异
git diff --cached

# 撤销工作区修改（未 add）
git restore <file>

# 取消暂存（已 add）
git restore --staged <file>

# 回退到上一个提交（保留变更在工作区）
git reset --soft HEAD~1
```

- `restore` 用于文件级撤销。
- `reset --soft` 常用于“改错提交信息/合并提交”。

## 7. HEAD 常用命令

```bash
# 查看当前 HEAD 指向的提交
git rev-parse --short HEAD
git log -1
git show --name-status HEAD

# 查看 HEAD 当前所在分支（非 detached HEAD）
git symbolic-ref --short HEAD
```

```bash
# 相对引用：前 1 个 / 前 2 个提交
HEAD~1
HEAD~2

# 父提交（merge commit 常用）
HEAD^
HEAD^1
HEAD^2
```

```bash
# 基于 HEAD 对比差异
git diff HEAD~1 HEAD
git diff HEAD -- <file>
```

```bash
# 基于 HEAD 回退
git reset --soft HEAD~1
git reset --mixed HEAD~1
git reset --hard HEAD
```

- `HEAD~n`：沿第一父提交链向前 n 次。
- `HEAD^2`：只在 merge commit 下有意义，表示第二父提交。
- `git reset --hard` 会丢弃未提交改动，执行前请确认。

## 8. 临时保存：stash

```bash
# 暂存当前改动
git stash

# 查看 stash 列表
git stash list

# 恢复最近一次 stash
git stash pop
```

- 适合切分支处理紧急任务时临时保存现场。

## 9. 常用协作流程（推荐）

```bash
# 1) 基于 main 创建功能分支
git switch main
git pull
git switch -c feature/xxx

# 2) 开发并提交
git add .
git commit -m "feat: xxx"

# 3) 推送并发起 PR
git push -u origin feature/xxx
```

## 10. 提交信息建议

推荐使用约定式提交（Conventional Commits）：

- `feat:` 新功能
- `fix:` 修复问题
- `docs:` 文档更新
- `refactor:` 重构
- `chore:` 杂项维护

示例：

```text
feat: add login api
fix: handle nil pointer in user service
docs: update git command guide
```
