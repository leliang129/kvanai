---
title: Python-os模块
---

# Python os 模块使用

os 模块是 Python 中与操作系统交互的核心模块，提供了许多系统级操作的功能。

## 1. 基本路径操作

### 1.1 获取当前工作目录

```python
import os

# 获取当前工作目录
current_dir = os.getcwd()
print(current_dir)  # 输出: /Users/username/projects
```

### 1.2 路径拼接

```python
# 使用 os.path.join() 拼接路径
path = os.path.join('folder', 'subfolder', 'file.txt')
print(path)  # 输出: folder/subfolder/file.txt (Unix) 或 folder\subfolder\file.txt (Windows)
```

## 2. 文件和目录操作

### 2.1 创建目录

```python
# 创建单个目录
os.mkdir('new_folder')

# 创建多级目录
os.makedirs('folder/subfolder/subsubfolder')
```

### 2.2 删除操作

```python
# 删除文件
os.remove('file.txt')

# 删除空目录
os.rmdir('empty_folder')

# 删除目录及其内容
import shutil
shutil.rmtree('folder_with_contents')
```

### 2.3 文件重命名

```python
# 重命名文件或目录
os.rename('old_name.txt', 'new_name.txt')
```

## 3. 路径处理

### 3.1 路径分割

```python
path = '/home/user/documents/file.txt'

# 分割路径和文件名
dirname = os.path.dirname(path)
filename = os.path.basename(path)
print(dirname)   # 输出: /home/user/documents
print(filename)  # 输出: file.txt

# 分割文件名和扩展名
name, ext = os.path.splitext('file.txt')
print(name)  # 输出: file
print(ext)   # 输出: .txt
```

## 4. 系统信息

### 4.1 环境变量

```python
# 获取环境变量
home = os.environ.get('HOME')
print(home)  # 输出: /home/username

home = os.getenv('HOME')
print(home)  # 输出: /home/username

# 设置环境变量
os.environ['MY_VAR'] = 'my_value'
```

### 4.2 系统相关

```python
# 获取系统名称
print(os.name)  # 输出: 'posix' (Unix/Linux/Mac) 或 'nt' (Windows)

# 获取系统路径分隔符
print(os.sep)  # 输出: '/' (Unix) 或 '\' (Windows)
```

## 5. 文件信息

### 5.1 检查文件/目录

```python
# 检查路径是否存在
print(os.path.exists('file.txt'))  # 输出: True 或 False

# 检查是否为文件
print(os.path.isfile('file.txt'))  # 输出: True 或 False

# 检查是否为目录
print(os.path.isdir('folder'))     # 输出: True 或 False
```

### 5.2 文件属性

```python
# 获取文件大小（字节）
size = os.path.getsize('file.txt')
print(size)  # 输出: 1234

# 获取文件修改时间
mtime = os.path.getmtime('file.txt')
print(mtime)  # 输出: 1621234567.89
```

## 6. 目录遍历

### 6.1 列出目录内容

```python
# 列出目录中的文件和子目录
print(os.listdir('.'))  # 输出: ['file1.txt', 'file2.txt', 'folder1']

# 使用 walk 遍历目录树
for root, dirs, files in os.walk('.'):
    print(f'当前目录: {root}')
    print(f'子目录: {dirs}')
    print(f'文件: {files}')
```

## 注意事项

1. 在处理路径时，建议使用 `os.path.join()` 而不是手动拼接字符串，以确保跨平台兼容性
2. 删除文件或目录前应当先检查是否存在，避免抛出异常
3. 使用 `os.makedirs()` 时可以添加 `exist_ok=True` 参数，避免目录已存在时报错
4. 在处理文件路径时，推荐使用原始字符串（r'path\to\file'）或正斜杠（'path/to/file'）

## 实用示例

### 批量重命名文件

```python
import os

def batch_rename(directory, old_ext, new_ext):
    for filename in os.listdir(directory):
        # 检查文件扩展名
        if filename.endswith(old_ext):
            # 构建新旧文件路径
            old_path = os.path.join(directory, filename)
            new_filename = filename.replace(old_ext, new_ext)
            new_path = os.path.join(directory, new_filename)
            # 重命名文件
            os.rename(old_path, new_path)
            print(f'已将 {filename} 重命名为 {new_filename}')

# 使用示例
batch_rename('./images', '.jpg', '.png')
```