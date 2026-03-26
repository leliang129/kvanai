---
sidebar_position: 13
title: 开发环境
---

# 12 开发环境

## Git

常用初始化：

```bash
git config --global user.name "your-name"       # 设置提交记录中的用户名
git config --global user.email "you@example.com" # 设置提交记录中的邮箱
git config --global init.defaultBranch main     # 设置 git init 后默认分支名
```

查看配置：

```bash
git config --list --global      # 查看当前用户级 Git 配置
git config --global core.editor vim # 指定 Git 默认编辑器
git config --global color.ui auto   # 终端支持时自动启用彩色输出
```

新仓库初始化：

```bash
mkdir demo && cd demo
git init                                  # 初始化当前目录为 Git 仓库
touch README.md                           # 创建示例文件
git add README.md                         # 加入暂存区
git commit -m "chore: init repository"    # 生成第一次提交
```

高频操作：

```bash
git clone <repo>                              # 从远程仓库拉取代码到本地
git checkout -b feature/linux-docs            # 创建并切换到新分支
git status                                    # 查看工作区和暂存区状态
git add .                                     # 把当前目录下变更加入暂存区
git commit -m "docs: add linux learning path" # 提交本次修改
git push origin feature/linux-docs            # 推送本地分支到远程仓库
```

查看状态与历史：

```bash
git status                               # 查看工作区、暂存区状态
git diff                                 # 查看工作区相对暂存区的差异
git diff --cached                        # 查看已暂存但未提交的内容
git log --oneline --graph --decorate -10 # 查看最近 10 条提交和分支关系
git blame <file>                         # 查看文件每一行最后由谁修改
```

分支操作：

```bash
git branch                         # 查看本地分支
git branch -a                      # 查看本地和远程全部分支
git switch main                    # 切换到已有分支
git switch -c feature/nginx-tuning # 创建并切换到新分支
git merge feature/nginx-tuning     # 把目标分支合并到当前分支
git branch -d feature/nginx-tuning # 删除已合并的本地分支
```

同步远程仓库：

```bash
git remote -v                           # 查看远程仓库地址
git fetch origin                        # 只同步远程数据，不改当前工作区
git pull --rebase origin main           # 抓取远程更新并把本地提交变基到最新 main 后
git push -u origin feature/nginx-tuning # 首次推送并建立跟踪关系
```

暂存与恢复：

```bash
git stash push -m "wip: update linux docs" # 临时保存当前未提交修改
git stash list                             # 查看暂存列表
git stash pop                              # 恢复最近一次暂存并从列表移除
git restore <file>                         # 撤销工作区中某个文件的未提交修改
git restore --staged <file>                # 把文件从暂存区移出，但保留工作区修改
```

回退与撤销：

```bash
git commit --amend       # 修改最近一次提交的内容或提交信息
git reset --soft HEAD~1  # 回退最近一次提交，但保留改动在暂存区
git revert <commit-id>   # 用一个反向提交来撤销指定提交
```

说明：

- `git pull --rebase` 适合保持提交历史更线性。
- `git restore` 用于撤销工作区或暂存区修改，比旧的 `checkout -- <file>` 更清晰。
- 已推送到共享分支的提交，优先使用 `git revert`，不要直接改写公共历史。

忽略文件示例（`.gitignore`）：

```gitignore
.idea/ # IDE 生成的工程配置
*.log  # 日志文件
dist/  # 构建产物目录
.env   # 本地环境变量文件，通常包含敏感信息
```

## 编译工具（`gcc/make`）

安装（Ubuntu）：

```bash
sudo apt update                    # 刷新软件包索引
sudo apt install -y build-essential # 安装 GCC、G++、Make 等常用工具链
```

验证：

```bash
gcc --version  # 确认 GCC 是否安装成功及其版本
make --version # 确认 Make 是否安装成功及其版本
```

典型流程：

```bash
./configure        # 检测系统环境并生成编译配置
make -j$(nproc)    # 按 CPU 核心数并行编译
sudo make install  # 把编译产物安装到系统目录
```

## 环境变量

查看与设置：

```bash
env | sort          # 查看当前环境变量并排序，方便排查
export APP_ENV=prod # 设置当前 shell 会话中的环境变量
echo "$APP_ENV"     # 验证变量是否生效
```

持久化建议：

- 用户级：`~/.bashrc`、`~/.zshrc`
- 系统级：`/etc/environment`、`/etc/profile.d/*.sh`

更新 PATH：

```bash
export PATH="$HOME/.local/bin:$PATH" # 把用户目录下的可执行文件加入 PATH
```

## 包管理（`apt/yum/dnf`）

Ubuntu / Debian 常用操作：

```bash
sudo apt update                 # 更新本地软件源索引
sudo apt install -y curl vim git # 安装指定软件包
sudo apt upgrade -y             # 升级已安装软件到可用新版本
sudo apt remove <pkg>           # 卸载指定软件包
sudo apt autoremove -y          # 删除不再需要的依赖包
```

查询与排查（Ubuntu / Debian）：

```bash
apt list --installed | grep <pkg> # 检查某个包是否已安装
apt search <pkg>                  # 搜索软件包
apt show <pkg>                    # 查看软件包详情
sudo apt-cache policy <pkg>       # 查看已安装版本、候选版本和来源仓库
sudo apt-cache madison <pkg>      # 列出仓库中可用版本
dpkg -l | grep <pkg>              # 从底层包数据库查看安装状态
```

指定版本安装（Ubuntu / Debian）：

```bash
sudo apt install -y <pkg>=<version> # 安装指定版本的软件包
sudo apt-mark hold <pkg>            # 锁定软件包版本，避免后续升级
sudo apt-mark unhold <pkg>          # 取消版本锁定
```

RHEL / CentOS 常用操作：

```bash
sudo yum install -y curl vim git # 安装指定软件包
sudo yum update -y               # 更新已安装软件包
sudo yum remove <pkg>            # 删除指定软件包
sudo yum autoremove -y           # 删除无用依赖
sudo yum info <pkg>              # 查看软件包详细信息
sudo yum list installed          # 列出当前已安装软件包
```

`dnf`（新版发行版更常见）：

```bash
sudo dnf install -y curl vim git # 安装指定软件包
sudo dnf update -y               # 更新已安装软件包
sudo dnf remove <pkg>            # 删除指定软件包
sudo dnf info <pkg>              # 查看软件包详情
sudo dnf list installed          # 查看已安装软件列表
sudo dnf repoquery <pkg>         # 查询仓库中包的来源与可用信息
```

说明：

- `dnf` 是 `yum` 的后继工具，常见于较新的 Fedora、RHEL、Rocky、AlmaLinux。

版本锁定（RHEL / CentOS）：

```bash
sudo yum versionlock <pkg>        # 锁定指定包版本
sudo yum versionlock delete <pkg> # 取消 yum 的版本锁定
sudo dnf versionlock add <pkg>    # 为 dnf 添加版本锁定
sudo dnf versionlock delete <pkg> # 删除 dnf 版本锁定规则
```

缓存清理：

```bash
sudo apt clean     # 清理 APT 下载缓存
sudo yum clean all # 清理 YUM 元数据和缓存
sudo dnf clean all # 清理 DNF 元数据和缓存
```

运维建议：

- 先 `update` 软件索引，再安装软件，避免包信息过旧。
- 关键组件需要可回滚时，先确认可用版本：`apt-cache madison`、`yum list --showduplicates`、`dnf --showduplicates list`。
- 生产环境尽量锁定关键依赖版本，避免自动升级引入兼容性问题。
- 新增第三方仓库前，确认来源可信、GPG 签名有效，并记录仓库变更。
