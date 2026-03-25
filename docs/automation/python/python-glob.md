---
title: Python-glob模块
---

# Python glob 模块使用

glob 是 Python 标准库中用于按通配符模式查找文件和目录的模块，适合批量匹配日志、配置文件、图片、备份文件等场景。

常见用途：

- 查找某个目录下所有 `.log` 文件。
- 递归查找多级目录中的 `.py`、`.yaml`、`.json` 文件。
- 批量收集待处理文件列表，例如图片压缩、日志归档、配置扫描。

## 1. 基本导入

```python
import glob
```

## 2. 基本匹配

### 2.1 匹配当前目录文件

```python
import glob

# 匹配当前目录下所有 txt 文件
files = glob.glob("*.txt")
print(files)
```

说明：

- `glob.glob()` 返回一个列表。
- `*.txt` 表示匹配当前目录下所有以 `.txt` 结尾的文件。
- 默认不会递归子目录。

### 2.2 匹配指定目录

```python
import glob

# 匹配 logs 目录下所有日志文件
log_files = glob.glob("logs/*.log")
print(log_files)
```

## 3. 常见通配符

```python
import glob

glob.glob("*.py")        # 匹配所有 .py 文件
glob.glob("data-?.csv")  # ? 匹配单个字符，如 data-1.csv
glob.glob("img[0-9].png") # 匹配 img0.png 到 img9.png
glob.glob("test_[ab].txt") # 匹配 test_a.txt 和 test_b.txt
```

常见规则：

- `*`：匹配任意多个字符。
- `?`：匹配任意单个字符。
- `[abc]`：匹配括号中的任一字符。
- `[0-9]`：匹配指定范围内的字符。

## 4. 递归匹配

### 4.1 使用 `**` 递归查找

```python
import glob

# 递归查找当前目录及子目录下所有 Python 文件
py_files = glob.glob("**/*.py", recursive=True)
print(py_files)
```

说明：

- `**` 表示匹配任意层级目录。
- 必须加 `recursive=True` 才会递归生效。

### 4.2 查找多级目录中的配置文件

```python
import glob

yaml_files = glob.glob("configs/**/*.yaml", recursive=True)
json_files = glob.glob("configs/**/*.json", recursive=True)

print("yaml:", yaml_files)
print("json:", json_files)
```

## 5. 使用 `iglob`

`glob.iglob()` 返回一个迭代器，适合大目录场景，避免一次性把所有结果加载到内存中。

```python
import glob

for file_path in glob.iglob("logs/**/*.log", recursive=True):
    print(file_path)
```

适用场景：

- 匹配结果很多时，边遍历边处理。
- 做批量扫描、归档、上传时减少内存占用。

## 6. 只匹配目录或文件

`glob` 只负责模式匹配，如果要区分文件和目录，通常结合 `os.path` 使用。

```python
import glob
import os

paths = glob.glob("data/*")

files = [p for p in paths if os.path.isfile(p)]
dirs = [p for p in paths if os.path.isdir(p)]

print("files:", files)
print("dirs:", dirs)
```

## 7. 排序与稳定输出

`glob.glob()` 返回结果通常依赖文件系统顺序。若希望输出稳定，建议手动排序。

```python
import glob

files = sorted(glob.glob("logs/*.log"))
print(files)
```

建议：

- 做批量处理时先 `sorted()`，避免不同环境下顺序不一致。
- 需要按修改时间排序时，可结合 `os.path.getmtime()`。

```python
import glob
import os

files = glob.glob("logs/*.log")
files = sorted(files, key=os.path.getmtime)
print(files)
```

## 8. 常见实战示例

### 8.1 批量读取日志文件

```python
import glob

for file_path in sorted(glob.glob("logs/*.log")):
    with open(file_path, "r", encoding="utf-8") as f:
        print(f"=== {file_path} ===")
        print(f.readline().strip())
```

### 8.2 查找最近生成的备份文件

```python
import glob
import os

backup_files = glob.glob("backup/*.tar.gz")

if backup_files:
    latest_file = max(backup_files, key=os.path.getmtime)
    print("最新备份文件:", latest_file)
else:
    print("没有找到备份文件")
```

### 8.3 批量删除临时文件

```python
import glob
import os

for file_path in glob.glob("tmp/*.tmp"):
    os.remove(file_path)
    print("已删除:", file_path)
```

注意：

- 删除类操作建议先只打印匹配结果，确认无误后再执行。
- 生产环境批量删除时，优先保留日志或做备份。

## 9. 与 `pathlib.Path.glob()` 的区别

`glob` 是传统标准库方式，`pathlib` 提供了更现代的面向对象路径接口。

```python
from pathlib import Path

for path in Path("logs").glob("*.log"):
    print(path)

for path in Path(".").rglob("*.py"):
    print(path)
```

区别：

- `glob.glob()` 返回字符串路径列表。
- `Path.glob()` 返回 `Path` 对象迭代器。
- 如果项目大量使用 `pathlib`，通常直接用 `Path.glob()` 更自然。

## 10. 常见坑

- `glob("*.txt")` 只匹配当前目录，不会自动进入子目录。
- 使用 `**` 时必须配合 `recursive=True`。
- 返回结果顺序不一定固定，依赖顺序的场景要主动排序。
- 匹配不到文件时返回空列表，不会报错。
- `glob` 是文件系统模式匹配，不是正则表达式匹配。

## 11. 小结

`glob` 适合做“按文件名模式查找文件”这类任务，语法简单，适合快速批量处理文件。

推荐记住这几种写法：

```python
glob.glob("*.txt")                      # 当前目录匹配
glob.glob("logs/*.log")                 # 指定目录匹配
glob.glob("**/*.py", recursive=True)    # 递归匹配
glob.iglob("**/*.py", recursive=True)   # 迭代器方式递归匹配
```
