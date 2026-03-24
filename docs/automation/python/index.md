---
sidebar_position: 1
---

# Python 自动化概览

Python 更适合把脚本做成“可维护的小工具”：重试、并发、配置化、测试与可观测性都更容易落地。

## 推荐基建

- 参数解析：`argparse`（或在需要时用 `typer`）
- 日志：`logging` + 结构化字段（任务/集群/namespace）
- 重试：指数退避 + 抖动（对外部 API / DB）
- 并发：I/O 用 `asyncio`，CPU 用 `multiprocessing`

## 工程化小清单

- 配置与密钥分离：ENV / 文件 / Secret 管理
- 失败可定位：打印关键信息 + exit code
- 输出可复用：JSON / CSV，避免只打印人类可读文本

