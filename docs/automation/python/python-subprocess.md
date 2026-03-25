---
title: Python-subprocess模块
---

# Python subprocess 模块使用

subprocess 模块是 Python 中用于创建和管理子进程的标准库，提供了执行外部命令和脚本的功能。

## 1. 基本用法

### 1.1 运行命令

```python
import subprocess

# 最简单的命令执行
subprocess.run(['ls', '-l'])  # Unix/Linux
subprocess.run(['dir'], shell=True)  # Windows

# 带返回值的命令执行
result = subprocess.run(['echo', 'Hello World'], 
                       capture_output=True,  # 捕获输出
                       text=True)           # 文本模式
print(result.stdout)  # 输出: Hello World
```

### 1.2 检查返回码

```python
# 检查命令是否成功执行
try:
    subprocess.run(['ls', 'non_existent_file'], check=True)
except subprocess.CalledProcessError as e:
    print(f"命令执行失败: {e}")
    print(f"返回码: {e.returncode}")
```

## 2. 高级特性

### 2.1 输入输出重定向

```python
# 重定向标准输出和错误输出
result = subprocess.run(['python', 'script.py'],
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE,
                       text=True)

print('标准输出:', result.stdout)
print('错误输出:', result.stderr)

# 提供输入数据
process = subprocess.run(['python'],
                        input='print("Hello from Python")',
                        text=True,
                        capture_output=True)
print(process.stdout)
```

### 2.2 管道和流

```python
# 使用管道连接命令
p1 = subprocess.Popen(['ls'], stdout=subprocess.PIPE)
p2 = subprocess.Popen(['grep', '.py'], 
                     stdin=p1.stdout,
                     stdout=subprocess.PIPE,
                     text=True)
p1.stdout.close()  # 允许 p1 在 p2 读取完毕后退出
output = p2.communicate()[0]
```

## 3. 进程控制

### 3.1 Popen 类使用

```python
# 创建进程
process = subprocess.Popen(['python', '-c', 
                          'import time; time.sleep(2); print("Done")'],
                         stdout=subprocess.PIPE,
                         text=True)

# 等待进程完成
print("等待进程...")
process.wait()
print("进程完成")

# 检查进程是否在运行
print("进程是否在运行:", process.poll() is None)

# 获取进程输出
output, error = process.communicate()
print("输出:", output)
```

### 3.2 超时控制

```python
try:
    # 设置超时时间
    process = subprocess.run(['sleep', '10'],
                           timeout=5)
except subprocess.TimeoutExpired:
    print("命令执行超时")
```

## 4. 环境和工作目录

### 4.1 设置环境变量

```python
import os

# 使用自定义环境变量
env = os.environ.copy()  # 复制当前环境变量
env['CUSTOM_VAR'] = 'custom_value'

process = subprocess.run(['python', '-c', 
                         'import os; print(os.environ["CUSTOM_VAR"])'],
                        env=env,
                        capture_output=True,
                        text=True)
print(process.stdout)
```

### 4.2 更改工作目录

```python
# 在指定目录下执行命令
subprocess.run(['ls'], cwd='/path/to/directory')
```

## 5. 实用示例

### 5.1 执行系统命令

```python
def execute_command(command, timeout=None):
    """执行系统命令并返回结果"""
    try:
        result = subprocess.run(command,
                              shell=True,
                              capture_output=True,
                              text=True,
                              timeout=timeout)
        if result.returncode == 0:
            return True, result.stdout
        else:
            return False, result.stderr
    except subprocess.TimeoutExpired:
        return False, "命令执行超时"
    except Exception as e:
        return False, str(e)

# 使用示例
success, output = execute_command('ping -c 4 google.com', timeout=10)
if success:
    print("命令执行成功:", output)
else:
    print("命令执行失败:", output)
```

### 5.2 后台进程管理

```python
def run_background_process(command):
    """运行后台进程"""
    # 创建无输出的后台进程
    process = subprocess.Popen(command,
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL,
                             shell=True)
    return process

# 启动多个后台进程
processes = []
commands = [
    'python long_running_script1.py',
    'python long_running_script2.py'
]

for cmd in commands:
    proc = run_background_process(cmd)
    processes.append(proc)

# 检查进程状态
for proc in processes:
    if proc.poll() is None:
        print("进程仍在运行")
    else:
        print("进程已结束，返回码:", proc.returncode)
```

## 6. 安全注意事项

### 6.1 命令注入防护

```python
# 不安全的方式（容易受到命令注入攻击）
user_input = "file.txt; rm -rf /"
subprocess.run(f"cat {user_input}", shell=True)  # 危险！

# 安全的方式
subprocess.run(['cat', user_input])  # 参数作为列表传递
```

### 6.2 错误处理

```python
def safe_execute(command):
    """安全地执行命令"""
    try:
        result = subprocess.run(command,
                              capture_output=True,
                              text=True,
                              check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"命令执行失败: {e}")
        print(f"错误输出: {e.stderr}")
    except subprocess.TimeoutExpired as e:
        print(f"命令执行超时: {e}")
    except Exception as e:
        print(f"发生错误: {e}")
    return None
```

## 注意事项

1. 避免使用 `shell=True`，除非必要
2. 始终处理命令执行的返回码
3. 注意处理子进程的输出缓冲
4. 合理设置超时时间
5. 正确关闭和清理子进程
6. 注意跨平台兼容性问题

## 常见错误处理

```python
try:
    # 执行命令
    result = subprocess.run(['non_existent_command'],
                          capture_output=True,
                          text=True)
except FileNotFoundError:
    print("命令不存在")
except subprocess.SubprocessError as e:
    print(f"子进程错误: {e}")
except Exception as e:
    print(f"其他错误: {e}")
``` 