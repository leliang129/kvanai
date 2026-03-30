---
title: Python uv 安装与使用
sidebar_position: 2
tags: [python, uv, pip, venv, package, toolchain]
---

本篇记录 `uv` 的安装、虚拟环境管理、依赖安装、项目初始化与常见运维使用方式。`uv` 是一个由 Astral 推出的 Python 工具链，目标是替代一部分 `pip`、`venv`、`pip-tools`、`poetry` 的常见场景，特点是：

- 安装速度快
- 依赖解析快
- 可以统一管理 Python 版本、虚拟环境与依赖
- 命令风格更适合脚本化和工程化场景

如果你平时会写 Python 自动化脚本、临时工具或小型服务，`uv` 是非常值得统一使用的一套工具。

> 官方文档：`https://docs.astral.sh/uv/`

## 1. uv 是什么

`uv` 可以理解成一个更现代的 Python 包与环境管理工具，常见用途包括：

- 创建虚拟环境
- 安装第三方依赖
- 管理项目依赖文件
- 直接运行 Python 脚本
- 安装命令行工具
- 管理 Python 解释器版本

你可以把它粗略理解为：

- `pip` + `venv` + 一部分 `poetry` / `pip-tools` 能力的整合
- 更适合自动化脚本、CI/CD、开发机初始化

---

## 2. 安装 uv

### 2.1 Linux / macOS（官方脚本）

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

如果没有 `curl`，也可以用：

```bash
wget -qO- https://astral.sh/uv/install.sh | sh
```

安装完成后，重新打开终端，或者让当前 shell 重新加载配置文件。

### 2.2 通过 pip 安装

如果你的环境里已经有 Python 和 pip，也可以直接安装：

```bash
pip install uv
```

不过更推荐使用官方安装脚本，这样管理更清晰。

### 2.3 Windows

Windows 推荐参考官方文档安装，或使用：

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

---

## 3. 验证安装

```bash
uv --version
which uv
```

Windows PowerShell：

```powershell
uv --version
Get-Command uv
```

如果能正常输出版本号，说明安装成功。

---

## 4. 创建虚拟环境

### 4.1 在当前目录创建 `.venv`

```bash
uv venv
```

默认会在当前目录下生成一个 `.venv` 虚拟环境目录。

### 4.2 指定 Python 版本创建虚拟环境

```bash
uv venv --python 3.12
```

### 4.3 激活虚拟环境

Linux / macOS：

```bash
source .venv/bin/activate
```

Windows PowerShell：

```powershell
.venv\Scripts\Activate.ps1
```

Windows CMD：

```bat
.venv\Scripts\activate.bat
```

### 4.4 删除虚拟环境

```bash
rm -rf .venv
```

Windows：

```powershell
Remove-Item -Recurse -Force .venv
```

---

## 5. 安装依赖

### 5.1 安装单个依赖

```bash
uv add requests
```

### 5.2 安装多个依赖

```bash
uv add requests pyyaml pandas
```

### 5.3 安装开发依赖

```bash
uv add --dev pytest ruff black
```

### 5.4 删除依赖

```bash
uv remove requests
```

### 5.5 同步依赖

当项目里已有 `pyproject.toml` / 锁文件时，可以用：

```bash
uv sync
```

这条命令很适合：

- 新机器拉项目后恢复依赖
- CI 环境中安装依赖
- 保证环境与锁文件一致

---

## 6. 初始化一个项目

### 6.1 创建新项目

```bash
uv init demo-project
cd demo-project
```

也可以在当前目录初始化：

```bash
uv init
```

初始化后通常会生成：

- `pyproject.toml`
- 示例代码文件
- 项目基础结构

### 6.2 安装项目依赖

```bash
uv sync
```

### 6.3 运行项目

```bash
uv run python main.py
```

或者：

```bash
uv run pytest
uv run ruff check .
```

`uv run` 的好处是：

- 不一定要手动 `source .venv/bin/activate`
- 更适合脚本和 CI 里直接调用

---

## 7. 运行单文件脚本

这是 `uv` 很适合运维场景的一个点。

### 7.1 直接运行本地脚本

```bash
uv run python script.py
```

### 7.2 给脚本临时加依赖

```bash
uv run --with requests --with pyyaml python script.py
```

这个场景非常适合：

- 写一次性巡检脚本
- 快速验证 API 请求
- 不想手动建 venv 也不想污染系统 Python

例如：

```bash
uv run --with requests python - <<'PY'
import requests
print(requests.get('https://httpbin.org/get', timeout=5).status_code)
PY
```

---

## 8. 安装命令行工具

如果你要装一些 Python CLI 工具，可以用：

```bash
uv tool install httpie
uv tool install pre-commit
uv tool install ruff
```

查看已安装的工具：

```bash
uv tool list
```

卸载工具：

```bash
uv tool uninstall httpie
```

这个功能很适合替代：

- `pip install --user xxx`
- 全局乱装 Python CLI 工具

---

## 9. Python 版本管理

`uv` 还可以帮助安装和使用 Python 解释器。

### 9.1 安装 Python

```bash
uv python install 3.12
```

### 9.2 查看可用 Python

```bash
uv python list
```

### 9.3 指定解释器创建虚拟环境

```bash
uv venv --python 3.12
```

这对于一台机器上同时维护多个 Python 版本非常方便。

---

## 10. 常见工作流示例

### 10.1 自动化脚本项目

适合：运维脚本、接口巡检脚本、小工具。

```bash
mkdir api-check
cd api-check
uv init
uv add requests pyyaml
uv add --dev ruff pytest
uv run python main.py
```

### 10.2 新机器恢复项目环境

```bash
git clone <repo-url>
cd <repo>
uv sync
uv run python main.py
```

### 10.3 CI 里跑测试

```bash
uv sync --frozen
uv run pytest
```

如果你的锁文件已经确定，`--frozen` 很适合 CI，避免环境漂移。

---

## 11. 与 pip / venv 的对应关系

| 传统做法 | uv 做法 |
|---|---|
| `python -m venv .venv` | `uv venv` |
| `source .venv/bin/activate` | 可选，很多场景直接 `uv run` |
| `pip install requests` | `uv add requests` |
| `pip uninstall requests` | `uv remove requests` |
| `pip install -r requirements.txt` | `uv sync` |
| `python main.py` | `uv run python main.py` |

如果你以前已经习惯 `pip + venv`，迁移成本其实不高。

---

## 12. 常见问题

### 12.1 `uv: command not found`

先确认安装路径是否已经加入 PATH。

Linux / macOS 可以检查：

```bash
echo $PATH
ls ~/.local/bin
```

如果 `uv` 在 `~/.local/bin` 下，但 PATH 没带上，可以在 `~/.bashrc` 或 `~/.zshrc` 里补：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

然后执行：

```bash
source ~/.bashrc 2>/dev/null || true
source ~/.zshrc 2>/dev/null || true
```

### 12.2 项目依赖装了但运行找不到

优先使用：

```bash
uv run python main.py
```

而不是直接：

```bash
python main.py
```

否则你可能运行的是系统 Python，而不是项目虚拟环境里的解释器。

### 12.3 国内网络安装慢

如果拉取 Python 或依赖较慢，优先确认：

- 网络是否正常
- 是否需要公司代理
- 是否需要配合内网 PyPI 镜像

如有企业内网镜像，也可以把 `uv` 统一接到你的 Python 包镜像源。

### 12.4 什么时候用 `uv run --with`？

适合：

- 一次性脚本
- 临时调试
- 不想在项目里正式引入依赖

不太适合：

- 长期维护的正式项目
- 需要锁版本和可复现环境的应用

这类项目还是建议 `uv init + uv add + uv sync`。

---

## 13. 推荐实践

1. **项目统一使用 `uv` 管理依赖**，不要同时混用太多套工具。
2. **优先使用 `uv run`**，降低“忘记激活虚拟环境”的概率。
3. **开发依赖和运行依赖分开**，例如 `pytest`、`ruff` 放到 `--dev`。
4. **CI 用 `uv sync --frozen`**，保证依赖可复现。
5. **临时脚本优先用 `uv run --with`**，减少污染全局环境。

---

## 14. 总结

`uv` 非常适合下面这些场景：

- Python 自动化脚本
- 运维小工具
- 本地开发环境统一化
- CI/CD 依赖安装与执行
- 需要快速创建/销毁虚拟环境的项目

如果你的日常工作经常在：

- `pip install`
- `python -m venv`
- `source .venv/bin/activate`
- `pip install -r requirements.txt`

这几件事之间来回切换，那么可以考虑逐步统一到 `uv`，会更省心。
