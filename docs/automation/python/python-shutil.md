---
title: Python-shutil模块
---

# Python shutil 模块使用指南

shutil（shell utilities）模块提供了一系列用于文件和文件集合的高级操作，包括文件的复制、移动、删除和管理。它是对 os 模块的补充，提供了更高级的文件操作接口。

## 1. 文件操作

### 1.1 复制文件

```python
import shutil

# 复制文件（目标不存在）
shutil.copy('source.txt', 'dest.txt')      # 复制文件
shutil.copy2('source.txt', 'dest.txt')     # 复制文件及元数据

# 复制文件（保留所有元数据）
shutil.copyfile('source.txt', 'dest.txt')  # 仅复制内容
shutil.copymode('source.txt', 'dest.txt')  # 仅复制权限
shutil.copystat('source.txt', 'dest.txt')  # 仅复制状态信息

# 复制文件对象
with open('source.txt', 'rb') as src, open('dest.txt', 'wb') as dst:
    shutil.copyfileobj(src, dst)
```

### 1.2 移动文件

```python
# 移动文件或目录
shutil.move('source.txt', 'dest/source.txt')

# 移动到目录
shutil.move('source.txt', 'dest_directory')
```

## 2. 目录操作

### 2.1 复制目录

```python
# 复制整个目录树
shutil.copytree('source_dir', 'dest_dir')

# 复制目录树（带忽略模式）
def ignore_patterns(path, names):
    return [name for name in names if name.endswith('.pyc')]

shutil.copytree('source_dir', 'dest_dir', ignore=ignore_patterns)

# 复制目录树（保留符号链接）
shutil.copytree('source_dir', 'dest_dir', symlinks=True)
```

### 2.2 删除目录

```python
# 删除整个目录树
shutil.rmtree('directory_path')

# 安全删除（忽略错误）
shutil.rmtree('directory_path', ignore_errors=True)

# 自定义错误处理
def error_handler(func, path, exc_info):
    print(f"Error handling {path}: {exc_info[1]}")

shutil.rmtree('directory_path', onerror=error_handler)
```

## 3. 归档操作

### 3.1 创建归档

```python
# 创建 ZIP 文件
shutil.make_archive('archive_name', 'zip', 'source_dir')

# 创建不同格式的归档
shutil.make_archive('archive_name', 'tar', 'source_dir')      # TAR
shutil.make_archive('archive_name', 'gztar', 'source_dir')    # TAR.GZ
shutil.make_archive('archive_name', 'bztar', 'source_dir')    # TAR.BZ2
```

### 3.2 解压归档

```python
# 解压归档文件
shutil.unpack_archive('archive.zip', 'extract_dir')

# 根据文件扩展名自动选择格式
shutil.unpack_archive('archive.tar.gz')
```

## 4. 磁盘操作

### 4.1 磁盘空间

```python
# 获取磁盘使用情况
total, used, free = shutil.disk_usage('/')
print(f"总空间: {total // (2**30)} GiB")
print(f"已使用: {used // (2**30)} GiB")
print(f"可用空间: {free // (2**30)} GiB")
```

### 4.2 查找命令

```python
# 查找可执行文件路径
python_path = shutil.which('python')
print(f"Python 路径: {python_path}")
```

## 5. 权限和所有权

### 5.1 权限复制

```python
# 复制权限
shutil.copymode('source.txt', 'dest.txt')

# 复制所有元数据
shutil.copystat('source.txt', 'dest.txt')
```

### 5.2 修改所有权

```python
# 修改文件所有者（需要权限）
shutil.chown('file.txt', user='newuser', group='newgroup')
```

## 6. 实用示例

### 6.1 备份目录

```python
import os
from datetime import datetime

def backup_directory(source_dir, backup_dir):
    # 创建带时间戳的备份目录名
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_name = f'backup_{timestamp}'
    backup_path = os.path.join(backup_dir, backup_name)
    
    # 复制目录树
    shutil.copytree(source_dir, backup_path)
    
    # 创建压缩归档
    archive_name = shutil.make_archive(
        os.path.join(backup_dir, f'backup_{timestamp}'),
        'zip',
        backup_path
    )
    
    # 删除临时目录
    shutil.rmtree(backup_path)
    
    return archive_name

# 使用示例
backup_file = backup_directory('my_project', 'backups')
print(f"备份已创建: {backup_file}")
```

### 6.2 文件同步

```python
def sync_directories(source_dir, dest_dir):
    """同步两个目录的内容"""
    if not os.path.exists(dest_dir):
        shutil.copytree(source_dir, dest_dir)
        return
    
    for item in os.listdir(source_dir):
        source_path = os.path.join(source_dir, item)
        dest_path = os.path.join(dest_dir, item)
        
        if os.path.isfile(source_path):
            if not os.path.exists(dest_path) or \
               os.path.getmtime(source_path) > os.path.getmtime(dest_path):
                shutil.copy2(source_path, dest_path)
        elif os.path.isdir(source_path):
            sync_directories(source_path, dest_path)

# 使用示例
sync_directories('source_folder', 'backup_folder')
```

## 7. 系统资源监控

### 7.1 进程资源监控

```python
import os
import psutil  # 需要额外安装：pip install psutil
from datetime import datetime

def monitor_process_resources():
    """监控当前进程的资源使用情况"""
    # 获取当前进程
    process = psutil.Process(os.getpid())
    
    # CPU 使用情况
    cpu_percent = process.cpu_percent(interval=1)
    
    # 内存使用情况
    memory_info = process.memory_info()
    memory_mb = memory_info.rss / (1024 * 1024)  # 转换为MB
    
    # 打开的文件数
    open_files = process.open_files()
    
    print(f"进程 CPU 使用率: {cpu_percent}%")
    print(f"进程内存使用: {memory_mb:.2f} MB")
    print(f"打开的文件数: {len(open_files)}")
    
    return cpu_percent, memory_mb, len(open_files)
```

### 7.2 文件操作监控

```python
class FileOperationMonitor:
    def __init__(self, log_file="file_operations.log"):
        self.log_file = log_file
    
    def log_operation(self, operation, source, destination=None, size=None):
        """记录文件操作"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(self.log_file, "a") as f:
            log_entry = f"{timestamp} - {operation}: {source}"
            if destination:
                log_entry += f" -> {destination}"
            if size:
                log_entry += f" (Size: {size/1024/1024:.2f} MB)"
            f.write(log_entry + "\n")
    
    def monitor_copy(self, source, destination):
        """监控文件复制操作"""
        try:
            # 记录开始操作
            size = os.path.getsize(source)
            self.log_operation("COPY_START", source, destination, size)
            
            # 执行复制
            shutil.copy2(source, destination)
            
            # 记录完成操作
            self.log_operation("COPY_COMPLETE", source, destination, size)
            
        except Exception as e:
            self.log_operation("COPY_ERROR", source, destination, error=str(e))
            raise

# 使用示例
monitor = FileOperationMonitor()

def safe_copy_with_monitoring(source, destination):
    """带监控的安全文件复制"""
    try:
        # 检查源文件
        if not os.path.exists(source):
            raise FileNotFoundError(f"源文件不存在: {source}")
        
        # 检查目标路径
        dest_dir = os.path.dirname(destination)
        if not os.path.exists(dest_dir):
            os.makedirs(dest_dir)
        
        # 执行带监控的复制
        monitor.monitor_copy(source, destination)
        
    except Exception as e:
        print(f"复制失败: {e}")
        raise
```

### 7.3 资源使用报告

```python
class ResourceReport:
    def __init__(self):
        self.operations = []
    
    def add_operation(self, operation_type, source, destination=None, 
                     size=None, duration=None):
        """添加操作记录"""
        self.operations.append({
            'timestamp': datetime.now(),
            'type': operation_type,
            'source': source,
            'destination': destination,
            'size': size,
            'duration': duration
        })
    
    def generate_report(self):
        """生成资源使用报告"""
        report = "文件操作资源使用报告\n"
        report += "=" * 50 + "\n"
        
        total_size = 0
        total_duration = 0
        
        for op in self.operations:
            report += f"\n操作类型: {op['type']}\n"
            report += f"时间: {op['timestamp']}\n"
            report += f"源路径: {op['source']}\n"
            
            if op['destination']:
                report += f"目标路径: {op['destination']}\n"
            
            if op['size']:
                size_mb = op['size'] / (1024 * 1024)
                report += f"文件大小: {size_mb:.2f} MB\n"
                total_size += op['size']
            
            if op['duration']:
                report += f"耗时: {op['duration']:.2f} 秒\n"
                total_duration += op['duration']
        
        report += "\n" + "=" * 50 + "\n"
        report += f"总计大小: {total_size/(1024*1024):.2f} MB\n"
        report += f"总计耗时: {total_duration:.2f} 秒\n"
        
        return report

# 使用示例
report = ResourceReport()

def copy_with_report(source, destination):
    """带报告的文件复制"""
    start_time = time.time()
    size = os.path.getsize(source)
    
    try:
        shutil.copy2(source, destination)
        duration = time.time() - start_time
        report.add_operation('COPY', source, destination, size, duration)
        
    except Exception as e:
        report.add_operation('COPY_ERROR', source, destination, size, 
                           time.time() - start_time)
        raise

# 生成报告
print(report.generate_report())
```

## 注意事项

1. 使用 `rmtree` 时要特别小心，它会递归删除所有内容
2. 复制和移动操作可能会覆盖现有文件
3. 某些操作可能需要特殊权限
4. 处理大文件时注意内存使用
5. 在跨平台操作时注意路径分隔符的使用

## 错误处理

```python
import errno

def safe_remove_tree(directory):
    try:
        shutil.rmtree(directory)
    except FileNotFoundError:
        print(f"目录不存在: {directory}")
    except PermissionError:
        print(f"权限不足: {directory}")
    except OSError as e:
        if e.errno == errno.ENOTEMPTY:
            print(f"目录不为空: {directory}")
        else:
            print(f"删除失败: {e}")
```
