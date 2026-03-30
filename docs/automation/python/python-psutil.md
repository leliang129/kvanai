---
title: Python-psutil模块
sidebar_position: 29
---

# Python psutil 模块使用

`psutil` 是 Python 中一个非常常用的系统信息与进程管理模块，可以获取 CPU、内存、磁盘、网络、进程等运行状态，常用于：

- 主机巡检脚本
- 资源监控采集
- 运维自动化告警
- 进程排障与分析

如果你需要用 Python 写一个轻量级的系统监控脚本，`psutil` 基本是首选。

## 1. 安装模块

```bash
pip install psutil
```

验证是否安装成功：

```bash
python -c "import psutil; print(psutil.__version__)"
```

---

## 2. 获取 CPU 信息

### 2.1 CPU 使用率

```python
import psutil

# 整体 CPU 使用率
print(psutil.cpu_percent(interval=1))

# 每个核心的 CPU 使用率
print(psutil.cpu_percent(interval=1, percpu=True))
```

说明：

- `interval=1` 表示采样 1 秒后再返回结果
- `percpu=True` 会返回每个 CPU 核心的使用率列表

### 2.2 CPU 核心数

```python
import psutil

print('逻辑核心数:', psutil.cpu_count())
print('物理核心数:', psutil.cpu_count(logical=False))
```

---

## 3. 获取内存信息

### 3.1 物理内存

```python
import psutil

memory = psutil.virtual_memory()
print(memory)
print('总内存:', memory.total)
print('已使用:', memory.used)
print('可用内存:', memory.available)
print('使用率:', memory.percent)
```

### 3.2 交换分区

```python
import psutil

swap = psutil.swap_memory()
print('Swap 总量:', swap.total)
print('Swap 已使用:', swap.used)
print('Swap 使用率:', swap.percent)
```

---

## 4. 获取磁盘信息

### 4.1 磁盘分区

```python
import psutil

partitions = psutil.disk_partitions()
for partition in partitions:
    print(partition.device, partition.mountpoint, partition.fstype)
```

### 4.2 磁盘使用率

```python
import psutil

usage = psutil.disk_usage('/')
print('总空间:', usage.total)
print('已使用:', usage.used)
print('剩余空间:', usage.free)
print('使用率:', usage.percent)
```

### 4.3 磁盘 IO

```python
import psutil

io_stat = psutil.disk_io_counters()
print('读次数:', io_stat.read_count)
print('写次数:', io_stat.write_count)
print('读字节:', io_stat.read_bytes)
print('写字节:', io_stat.write_bytes)
```

---

## 5. 获取网络信息

### 5.1 网络 IO 统计

```python
import psutil

net = psutil.net_io_counters()
print('发送字节:', net.bytes_sent)
print('接收字节:', net.bytes_recv)
print('发送包数:', net.packets_sent)
print('接收包数:', net.packets_recv)
```

### 5.2 网卡地址信息

```python
import psutil

addrs = psutil.net_if_addrs()
for nic_name, addr_list in addrs.items():
    print(f'网卡: {nic_name}')
    for addr in addr_list:
        print('  地址族:', addr.family)
        print('  地址:', addr.address)
```
```

### 5.3 网卡状态

```python
import psutil

stats = psutil.net_if_stats()
for nic_name, stat in stats.items():
    print(nic_name, stat.isup, stat.speed)
```

---

## 6. 获取进程信息

### 6.1 查看所有进程

```python
import psutil

for proc in psutil.process_iter(['pid', 'name', 'username']):
    print(proc.info)
```

### 6.2 根据 PID 获取进程详情

```python
import psutil

pid = 1
proc = psutil.Process(pid)

print('进程名:', proc.name())
print('执行路径:', proc.exe())
print('启动命令:', proc.cmdline())
print('状态:', proc.status())
print('创建时间:', proc.create_time())
print('CPU 使用率:', proc.cpu_percent(interval=1))
print('内存使用率:', proc.memory_percent())
```

### 6.3 杀掉某个进程

```python
import psutil

pid = 12345
proc = psutil.Process(pid)
proc.terminate()  # 优雅终止
# proc.kill()     # 强制终止
```

> 运维脚本里执行 kill/terminate 时一定要加保护条件，避免误杀关键进程。

---

## 7. 常见运维场景示例

### 7.1 编写一个简单主机状态巡检脚本

```python
import psutil

print('==== 主机巡检信息 ====')
print('CPU 使用率:', psutil.cpu_percent(interval=1), '%')
print('内存使用率:', psutil.virtual_memory().percent, '%')
print('磁盘使用率:', psutil.disk_usage('/').percent, '%')
print('网络发送字节:', psutil.net_io_counters().bytes_sent)
print('网络接收字节:', psutil.net_io_counters().bytes_recv)
```

### 7.2 找出内存占用最高的前 5 个进程

```python
import psutil

processes = []
for proc in psutil.process_iter(['pid', 'name', 'memory_percent']):
    try:
        processes.append(proc.info)
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        pass

processes = sorted(processes, key=lambda item: item['memory_percent'] or 0, reverse=True)

for proc in processes[:5]:
    print(proc)
```

### 7.3 找出 CPU 占用高的进程

```python
import psutil
import time

processes = []
for proc in psutil.process_iter(['pid', 'name']):
    try:
        proc.cpu_percent(interval=None)
        processes.append(proc)
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        pass

time.sleep(1)

cpu_list = []
for proc in processes:
    try:
        cpu_list.append({
            'pid': proc.pid,
            'name': proc.name(),
            'cpu_percent': proc.cpu_percent(interval=None),
        })
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        pass

cpu_list = sorted(cpu_list, key=lambda item: item['cpu_percent'], reverse=True)
for item in cpu_list[:5]:
    print(item)
```

---

## 8. 异常处理

使用 `psutil` 读取进程时，最常见的问题是：

- 进程已经退出：`psutil.NoSuchProcess`
- 权限不足：`psutil.AccessDenied`
- 某些状态异常：`psutil.ZombieProcess`

建议统一加异常处理：

```python
import psutil

try:
    proc = psutil.Process(1000)
    print(proc.name())
except psutil.NoSuchProcess:
    print('进程不存在')
except psutil.AccessDenied:
    print('没有权限访问该进程')
except psutil.ZombieProcess:
    print('僵尸进程')
```

---

## 9. 注意事项

1. `cpu_percent()` 第一次调用可能返回 0，需要结合时间间隔再采样一次。
2. 进程遍历时要做好异常处理，否则脚本容易因为瞬时进程退出而报错。
3. 单位通常是字节，展示给用户时建议转换成 MB / GB。
4. 高并发或频繁采集时，要注意采样开销，不建议毫秒级轮询。
5. 在容器环境中，某些系统指标可能受到 cgroup 限制影响。

---

## 10. 一个更实用的格式化示例

```python
import psutil


def bytes_to_gb(value):
    return round(value / 1024 / 1024 / 1024, 2)


memory = psutil.virtual_memory()
disk = psutil.disk_usage('/')

print(f'CPU 使用率: {psutil.cpu_percent(interval=1)}%')
print(f'内存: {bytes_to_gb(memory.used)}GB / {bytes_to_gb(memory.total)}GB ({memory.percent}%)')
print(f'磁盘: {bytes_to_gb(disk.used)}GB / {bytes_to_gb(disk.total)}GB ({disk.percent}%)')
```

这个写法更适合直接用于巡检输出、告警消息或日志记录。

---

## 11. 总结

`psutil` 非常适合做系统巡检和轻量级监控脚本，常见用途包括：

- 采集 CPU / 内存 / 磁盘 / 网络指标
- 查看与分析进程状态
- 快速写一个主机巡检工具
- 给运维脚本补充系统资源判断逻辑

如果你后续要把脚本进一步工程化，可以把 `psutil` 和下面这些模块结合起来使用：

- `subprocess`：执行系统命令
- `requests`：上报告警或发送 webhook
- `yaml` / `json`：读取配置文件
- `pandas`：分析历史监控数据
