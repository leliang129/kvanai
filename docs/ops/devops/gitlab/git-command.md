---
title: Git 命令简要说明
sidebar_position: 2
---

# Git 命令简要说明

本文按常见使用场景整理 Git 高频命令，适合作为日常速查。

## 1. 帮助、版本与初始化

```bash
# 帮助
git help <子命令>
git <子命令> --help
man git-<子命令>

# 版本
git version

# 初始化仓库
git init
git init --initial-branch=main
git init --bare

# 克隆
git clone <repository_url> [workdir]
git clone -b develop <repository_url>
git clone -b <tag> <repository_url>
```

说明：
- `git help <子命令>`：查看某个 Git 子命令的帮助文档。
- `git <子命令> --help`：与上面等价，常用写法。
- `man git-<子命令>`：通过系统 man 手册查看详细说明。
- `git version`：查看本机 Git 版本。
- `git init`：在当前目录初始化普通仓库。
- `git init --initial-branch=main`：初始化时指定默认分支名。
- `git init --bare`：创建裸仓库（通常作为远程仓库使用）。
- `git clone <repository_url> [workdir]`：克隆远程仓库到本地目录。
- `git clone -b develop <repository_url>`：克隆并直接检出 `develop` 分支。
- `git clone -b <tag> <repository_url>`：克隆后检出指定标签（常用于固定版本）。

## 2. 全局配置

```bash
git config --global user.name "your_name"
git config --global user.email "your_email@example.com"
git config --global color.ui true
git config --global core.editor vim
git config --global --list
git config --global -e
```

说明：
- `git config --global user.name`：设置全局提交用户名。
- `git config --global user.email`：设置全局提交邮箱。
- `git config --global color.ui true`：开启终端彩色输出，便于阅读。
- `git config --global core.editor vim`：设置默认编辑器（提交信息、rebase 等场景）。
- `git config --global --list`：查看全局配置项。
- `git config --global -e`：直接编辑全局配置文件。

## 3. 文件操作（工作区/暂存区）

```bash
# 添加到暂存区
git add <file>
git add .

# 重命名（已跟踪文件）
git mv <oldname> <newname>

# 删除
git rm --cached <file>   # 仅删暂存区
git rm <file>            # 删工作区+暂存区

# 恢复
git checkout <file>                  # 从暂存区恢复到工作区
git restore --staged <file>          # 撤销 add
git restore <file>                   # 撤销工作区变更
git restore -s <commit_id> <path>    # 从指定提交恢复文件

# 查看暂存文件与对象
git ls-files
git ls-files -s
git ls-files -o
git cat-file -p <blob_id>
```

说明：
- `git add <file>`：把单个文件加入暂存区。
- `git add .`：把当前目录下所有改动加入暂存区。
- `git mv <oldname> <newname>`：重命名已跟踪文件（等价于 mv + add/rm）。
- `git rm --cached <file>`：仅从暂存区移除文件，不删除工作区文件。
- `git rm <file>`：从暂存区和工作区都删除文件。
- `git checkout <file>`：用暂存区版本覆盖工作区文件（旧用法，仍常见）。
- `git restore --staged <file>`：撤销 `git add`，把文件移出暂存区。
- `git restore <file>`：丢弃工作区未暂存改动。
- `git restore -s <commit_id> <path>`：从指定提交恢复文件内容到工作区。
- `git ls-files`：查看已跟踪文件列表。
- `git ls-files -s`：查看暂存区条目及模式、对象 ID。
- `git ls-files -o`：查看未跟踪文件列表。
- `git cat-file -p <blob_id>`：查看 Git 对象（如 blob）的具体内容。

## 4. 差异对比

```bash
git diff [<path>...]
git diff --staged [<path>...]
git diff --cached <commit> [<path>...]
git diff [<commit>] [--] [<path>...]
git diff <commit1>...<commit2> [--] [<path>...]
```

说明：
- `git diff [<path>...]`：查看工作区相对暂存区的差异。
- `git diff --staged [<path>...]`：查看暂存区相对最近一次提交（HEAD）的差异。
- `git diff --cached <commit> [<path>...]`：对比暂存区与指定提交。
- `git diff [<commit>] [--] [<path>...]`：对比工作区与指定提交。
- `git diff <commit1>...<commit2> [--] [<path>...]`：比较两个提交范围的变更（常用于分支差异）。

## 5. 提交与日志

```bash
# 提交
git commit -m "comment"
git commit -am "comment"
git commit --amend --no-edit
git commit --amend -m "comment"
git show [HEAD]

# 日志
git status
git log
git log --oneline
git log --oneline -N
git log --pretty=oneline
git log --pretty=raw
git log --stats
git log -p [commit_id]
git log --author="<author-name-pattern>"
git log <file-pattern>
git log origin/main
git reflog
```

说明：
- `git commit -m "comment"`：提交暂存区内容并附带提交说明。
- `git commit -am "comment"`：对已跟踪文件自动 add 后提交（不包含新文件）。
- `git commit --amend --no-edit`：修改最后一次提交内容，不改提交信息。
- `git commit --amend -m "comment"`：修改最后一次提交并重写提交信息。
- `git show [HEAD]`：查看某个提交的详情（默认最近一次提交）。
- `git status`：查看工作区、暂存区、分支状态。
- `git log`：按时间倒序查看提交历史。
- `git log --oneline`：以简短单行格式查看历史。
- `git log --oneline -N`：查看最近 N 条单行提交记录。
- `git log --pretty=oneline`：自定义为 oneline 展示。
- `git log --pretty=raw`：查看原始提交信息格式。
- `git log --stats`：查看每次提交的文件变更统计。
- `git log -p [commit_id]`：查看某次提交（或范围）的详细 patch。
- `git log --author="<author-name-pattern>"`：按作者筛选提交。
- `git log <file-pattern>`：查看某文件的提交历史。
- `git log origin/main`：查看远程主分支历史。
- `git reflog`：查看 HEAD/分支引用变动记录（误操作恢复常用）。

## 6. 回滚（reset）

```bash
git reset --hard HEAD^^
git reset --soft HEAD~n
git reset --mixed HEAD~n
git reset --hard <commit_id>
git reset --hard <tagname>
```

说明：
- `HEAD^` / `HEAD^^`：按父提交回退。
- `HEAD~n`：回退 n 个提交。
- `--hard` 会重置工作区与暂存区，执行前确认。
- `git reset --hard HEAD^^`：回退到上上个父提交并丢弃本地改动。
- `git reset --soft HEAD~n`：回退提交但保留改动在暂存区。
- `git reset --mixed HEAD~n`：回退提交并把改动放回工作区（默认模式）。
- `git reset --hard <commit_id>`：强制回退到指定提交。
- `git reset --hard <tagname>`：强制回退到指定标签版本。

## 7. 分支、切换与合并

```bash
# 分支
git branch
git branch -av
git branch <branch>
git branch <branch> <commit_id>
git branch -d <branch>
git branch -m dev develop
git branch -M main
git branch -r

# checkout / switch
git checkout <branch>
git checkout <tag>
git checkout -b <branch>
git checkout -b <branch> origin/<branch>
git checkout [<commit>] -- <file>...

git switch <branch>
git switch -c <new-branch>

# merge
git merge master -m "<message>"
git merge origin/<branch>
git merge --abort
```

说明：
- `git branch`：查看本地分支。
- `git branch -av`：查看本地与远程分支及最后一次提交信息。
- `git branch <branch>`：创建新分支。
- `git branch <branch> <commit_id>`：基于指定提交创建分支。
- `git branch -d <branch>`：删除已合并分支。
- `git branch -m dev develop`：重命名分支。
- `git branch -M main`：强制重命名当前分支为 `main`。
- `git branch -r`：查看远程分支。
- `git checkout <branch>`：切换到指定分支。
- `git checkout <tag>`：切换到指定标签（通常进入 detached HEAD）。
- `git checkout -b <branch>`：创建并切换到新分支。
- `git checkout -b <branch> origin/<branch>`：基于远程分支创建本地跟踪分支。
- `git checkout [<commit>] -- <file>...`：从某提交恢复指定文件。
- `git switch <branch>`：切换分支（新语义，推荐）。
- `git switch -c <new-branch>`：创建并切换新分支（新语义，推荐）。
- `git merge master -m "<message>"`：把 `master` 合并到当前分支并指定合并信息。
- `git merge origin/<branch>`：直接合并远程分支到当前分支。
- `git merge --abort`：终止当前冲突中的合并流程。

## 8. 标签（tag）

```bash
# 创建
git tag <tagname>
git tag <tagname> <commit_id>
git tag -a <tagname> -m "<message>"
git tag -a <tagname> -m "<message>" <commit_id>

# 查看
git tag
git tag -l [<pattern>]
git show <tagname>

# 删除
git tag -d <tagname>
```

说明：
- `git tag <tagname>`：在当前提交创建轻量标签。
- `git tag <tagname> <commit_id>`：在指定提交创建轻量标签。
- `git tag -a <tagname> -m "<message>"`：创建附注标签（推荐发布版本使用）。
- `git tag -a <tagname> -m "<message>" <commit_id>`：在指定提交创建附注标签。
- `git tag`：列出全部标签。
- `git tag -l [<pattern>]`：按模式筛选标签。
- `git show <tagname>`：查看标签及其指向提交内容。
- `git tag -d <tagname>`：删除本地标签。

## 9. 远程仓库（remote）

```bash
git remote -v
git remote show <remote_name>
git remote add <remote_name> <url>
git remote rename origin new-origin
git remote remove origin
```

说明：
- `git remote -v`：查看远程仓库别名与 URL。
- `git remote show <remote_name>`：查看某远程仓库详细信息（跟踪分支、推拉策略等）。
- `git remote add <remote_name> <url>`：添加远程仓库。
- `git remote rename origin new-origin`：重命名远程别名。
- `git remote remove origin`：移除远程仓库配置。

## 10. 推送 / 拉取 / 抓取

```bash
# push
git push
git push <remote_name> <branch_name>
git push origin master
git push origin dev
git push -u origin master
git push origin main:dev
git push origin :dev
git push <remote_name> --all
git push -u origin --all
git push origin <tagname>
git push origin --tags
git push --delete origin <tagname>

# pull / fetch
git pull
git pull <remote_name>
git pull origin dev
git fetch <remote_name>
git fetch <remote_name> <branch_name>
git fetch origin master
```

说明：
- `git push`：推送当前分支到其上游分支。
- `git push <remote_name> <branch_name>`：推送指定分支到指定远程。
- `git push origin master`：推送本地 `master` 到 `origin/master`。
- `git push origin dev`：推送本地 `dev` 到 `origin/dev`。
- `git push -u origin master`：首次推送并建立上游跟踪关系。
- `git push origin main:dev`：把本地 `main` 推到远程 `dev` 分支。
- `git push origin :dev`：删除远程 `dev` 分支。
- `git push <remote_name> --all`：推送所有本地分支到远程。
- `git push -u origin --all`：推送所有本地分支并建立上游关系。
- `git push origin <tagname>`：推送指定标签。
- `git push origin --tags`：推送所有本地标签。
- `git push --delete origin <tagname>`：删除远程标签。
- `git pull`：拉取并合并当前分支对应的远程分支。
- `git pull <remote_name>`：从指定远程拉取并合并当前分支默认对应分支。
- `git pull origin dev`：拉取远程 `dev` 并合并到当前分支。
- `git fetch <remote_name>`：仅抓取远程更新，不自动合并。
- `git fetch <remote_name> <branch_name>`：仅抓取指定远程分支。
- `git fetch origin master`：抓取 `origin/master` 最新提交到远程跟踪分支。

## 11. 忽略文件与日志格式化

```bash
# 定义忽略文件
vim .gitignore

# 图形化日志
git log --graph --pretty=format:'<format>'
```

说明：
- `vim .gitignore`：编辑忽略规则文件，避免临时文件、构建产物被提交。
- `git log --graph --pretty=format:'<format>'`：以图形化分支结构输出自定义日志格式。

`--pretty=format` 常见占位符：
- `%H` / `%h`：完整 / 短 commit hash
- `%T` / `%t`：完整 / 短 tree hash
- `%P` / `%p`：完整 / 短 parent hash
- `%an` `%ae`：作者名 / 作者邮箱
- `%cn` `%ce`：提交者名 / 提交者邮箱
- `%ad` `%ar` `%ai`：作者日期（不同格式）
- `%cd` `%cr` `%ci`：提交日期（不同格式）
- `%s` `%b`：提交标题 / 提交正文
- `%d`：引用名称（分支/标签）
- `%C(...)`：颜色控制
