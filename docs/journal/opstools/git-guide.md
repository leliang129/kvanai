---
title: Git使用指南
sidebar_position: 4
---

>本文梳理 Git 在日常项目中的常用操作、冲突排查思路以及合并与清理命令，便于快速查阅。

## 常规工作流

- **配置身份**：
  ```bash
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  ```
- **获取代码**：
  ```bash
  git clone <repo-url>
  git pull --rebase
  ```
- **查看状态**：
  ```bash
  git status
  ```
- **提交改动**：
  ```bash
  git add <file|.>
  git commit -m "feat: message"
  git push origin <branch>
  ```
- **忽略文件**：
  ```bash
  git status --ignored
  ```

## 分支与合并

- **创建分支**：
  ```bash
  git switch -c feature/login
  git checkout -b feature/login
  ```
- **切换分支**：
  ```bash
  git switch develop
  ```
- **查看分支**：
  ```bash
  git branch -vv
  git branch -r
  ```
- **合并分支**：
  ```bash
  git switch develop
  git merge --no-ff feature/login
  ```
  `--no-ff` 能保留合并记录；如不需要，省略即可。
- **删除分支**：
  ```bash
  git branch -d feature/login
  git branch -D feature/login
  ```
- **删除远程分支**：
  ```bash
  git push origin --delete feature/login
  ```

## 查看历史与回滚

- **提交历史**：
  ```bash
  git log --oneline --graph --decorate
  ```
- **查看差异**：
  ```bash
  git diff
  git diff --cached
  git show <commit>
  ```
- **撤销提交**：
  ```bash
  git revert <commit>
  git reset --soft <commit>
  git reset --hard <commit>
  ```
  `git revert` 会生成新的提交以撤销改动；`git reset` 仅在本地回退，其中 `--hard` 会丢弃工作区与暂存区改动。
- **暂存现场**：
  ```bash
  git stash push -m "wip"
  git stash pop
  ```

## 解决冲突的流程

1. **识别冲突文件**：
   ```bash
   git status
   ```
2. **查看差异**：
   ```bash
   git diff
   git diff --theirs <file>
   git diff --ours <file>
   git mergetool
   ```
3. **编辑文件**：手动合并 `<<<<<<<`, `=======`, `>>>>>>>` 标记处的内容，确保逻辑正确。
4. **验证**：运行测试或构建，确认合并结果正确。
5. **标记解决**：
   ```bash
   git add <conflicted-file>
   ```
6. **继续流程**：
   ```bash
   git commit               # 合并场景
   git merge --continue     # 合并手动中断后继续
   git rebase --continue    # Rebase 场景
   ```

### 冲突处理常用命令

- 放弃当前合并：
  ```bash
  git merge --abort
  ```
- 放弃当前 rebase：
  ```bash
  git rebase --abort
  ```
- 选择某一侧改动：
  ```bash
  git checkout --theirs <file>
  git restore --source=MERGE_HEAD <file>
  git checkout --ours <file>
  git restore --source=HEAD <file>
  ```

## 合并策略与注意事项

- **保持同步**：
  ```bash
  git fetch origin
  git pull --rebase
  ```
- **原子提交**：一个提交只包含一项逻辑修改，冲突时更易定位。
- **提交信息规范**：遵循团队约定（如 Conventional Commits），便于历史检索。
- **提交前检查**：
  ```bash
  git status
  git diff
  ```

## 清理与维护

- **删除未跟踪文件**：
  ```bash
  git clean -fd
  git clean -fdn
  ```
- **修剪远程引用**：
  ```bash
  git remote prune origin
  ```
- **压缩提交**：
  ```bash
  git rebase -i <base-commit>
  ```
- **查看贡献统计**：
  ```bash
  git shortlog -sn
  git blame <file>
  ```

## 常见命令速查

- 更新远程地址：
  ```bash
  git remote set-url origin <new-url>
  ```
- 查看远程：
  ```bash
  git remote -v
  ```
- 仅拉取不合并：
  ```bash
  git fetch origin main
  ```
- 推送标签：
  ```bash
  git push origin v1.2.3
  git push origin :refs/tags/v1.2.3
  ```
- 创建标签：
  ```bash
  git tag v1.2.3
  git tag -a v1.2.3 -m "Release"
  ```

## 处理推送被拒：远程已有新提交

```bash
git push origin main
# error: failed to push some refs (non-fast-forward)

# 推荐流程：拉取后重放
git pull --rebase origin main
git push origin main

# 或：先 fetch 再手动 rebase
git fetch origin
git rebase origin/main
git push origin main

# 若 rebase 冲突
git status
git add <file>
git rebase --continue
git push origin main

# 放弃 rebase
git rebase --abort
```

:::info
根据团队规范选择合适的合并策略（Merge、Squash、Rebase），并在冲突时保持冷静，逐步定位问题即可确保仓库历史整洁可靠。
:::