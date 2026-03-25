---
title: Python-函数应用实例
sidebar_position: 12
---

# Python 函数应用实例

本文档提供了一些实际的函数应用示例，展示函数的实际使用场景。

## 1. 数据处理函数

### 1.1 列表处理

```python
# 列表去重保持顺序
def deduplicate(lst):
    seen = set()
    return [x for x in lst if not (x in seen or seen.add(x))]

# 列表分组
def chunk_list(lst, size):
    """将列表分割为指定大小的子列表"""
    return [lst[i:i + size] for i in range(0, len(lst), size)]

# 列表扁平化
def flatten(lst):
    """将嵌套列表扁平化"""
    result = []
    for item in lst:
        if isinstance(item, list):
            result.extend(flatten(item))
        else:
            result.append(item)
    return result

# 使用示例
numbers = [1, 2, 2, 3, 3, 4, 5, 5]
print(deduplicate(numbers))  # [1, 2, 3, 4, 5]

data = [1, 2, 3, 4, 5, 6, 7, 8]
print(chunk_list(data, 3))  # [[1, 2, 3], [4, 5, 6], [7, 8]]

nested = [1, [2, 3, [4, 5]], 6]
print(flatten(nested))  # [1, 2, 3, 4, 5, 6]
```

### 1.2 字符串处理

```python
# 驼峰命名转下划线
def camel_to_snake(text):
    import re
    pattern = re.compile(r'(?<!^)(?=[A-Z])')
    return pattern.sub('_', text).lower()

# 下划线转驼峰
def snake_to_camel(text):
    components = text.split('_')
    return components[0] + ''.join(x.title() for x in components[1:])

# 文本截断
def truncate(text, length, suffix='...'):
    """截断文本到指定长度，添加后缀"""
    if len(text) <= length:
        return text
    return text[:length].rstrip() + suffix

# 使用示例
print(camel_to_snake('getUserName'))  # get_user_name
print(snake_to_camel('get_user_name'))  # getUserName
print(truncate('这是一个很长的句子', 6))  # '这是一个...'
```

## 2. 文件处理函数

### 2.1 文件操作

```python
import os
import shutil

def safe_mkdir(path):
    """安全创建目录"""
    if not os.path.exists(path):
        os.makedirs(path)
    return path

def get_file_info(file_path):
    """获取文件信息"""
    if not os.path.exists(file_path):
        return None
    
    stats = os.stat(file_path)
    return {
        'size': stats.st_size,
        'created': stats.st_ctime,
        'modified': stats.st_mtime,
        'extension': os.path.splitext(file_path)[1]
    }

def batch_rename_files(directory, pattern, replacement):
    """批量重命名文件"""
    count = 0
    for filename in os.listdir(directory):
        if pattern in filename:
            old_path = os.path.join(directory, filename)
            new_filename = filename.replace(pattern, replacement)
            new_path = os.path.join(directory, new_filename)
            os.rename(old_path, new_path)
            count += 1
    return count
```

### 2.2 文件监控

```python
import time
from datetime import datetime

def watch_directory(path, interval=1):
    """监控目录变化"""
    previous = set(os.listdir(path))
    
    while True:
        current = set(os.listdir(path))
        
        # 检查新增文件
        added = current - previous
        if added:
            print(f"新增文件: {added}")
            
        # 检查删除文件
        removed = previous - current
        if removed:
            print(f"删除文件: {removed}")
            
        previous = current
        time.sleep(interval)
```

## 3. 数据验证函数

### 3.1 输入验证

```python
# 验证邮箱格式
def is_valid_email(email):
    import re
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))

# 验证手机号
def is_valid_phone(phone):
    import re
    pattern = r'^1[3-9]\d{9}$'
    return bool(re.match(pattern, phone))

# 验证身份证
def is_valid_id_card(id_card):
    import re
    pattern = r'^\d{17}[\dXx]$'
    if not re.match(pattern, id_card):
        return False
    
    # 验证校验码（简化版本）
    factors = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
    checksum = sum(int(id_card[i]) * factors[i] for i in range(17))
    checkcode = '10X98765432'[checksum % 11]
    return id_card[-1].upper() == checkcode
```

### 3.2 数据验证

```python
# 范围验证
def validate_range(value, min_val, max_val, name='值'):
    """验证数值是否在指定范围内"""
    if not isinstance(value, (int, float)):
        raise TypeError(f"{name}必须是数字")
    if value < min_val or value > max_val:
        raise ValueError(f"{name}必须在{min_val}和{max_val}之间")
    return value

# 类型验证装饰器
def type_check(**expected_types):
    def decorator(func):
        def wrapper(*args, **kwargs):
            # 检查位置参数
            for arg, expected_type in zip(args, expected_types.values()):
                if not isinstance(arg, expected_type):
                    raise TypeError(f"参数类型错误: 期望 {expected_type}")
            # 检查关键字参数
            for key, value in kwargs.items():
                if key in expected_types and not isinstance(value, expected_types[key]):
                    raise TypeError(f"参数 {key} 类型错误")
            return func(*args, **kwargs)
        return wrapper
    return decorator
```

## 4. 性能优化函数

### 4.1 缓存装饰器

```python
# 简单的内存缓存装饰器
def memoize(func):
    cache = {}
    def wrapper(*args, **kwargs):
        key = str(args) + str(kwargs)
        if key not in cache:
            cache[key] = func(*args, **kwargs)
        return cache[key]
    return wrapper

# 带过期时间的缓存装饰器
def cache_with_timeout(timeout=60):
    def decorator(func):
        cache = {}
        def wrapper(*args, **kwargs):
            key = str(args) + str(kwargs)
            now = time.time()
            if key in cache:
                result, timestamp = cache[key]
                if now - timestamp < timeout:
                    return result
            result = func(*args, **kwargs)
            cache[key] = (result, now)
            return result
        return wrapper
    return decorator
```

### 4.2 性能计时装饰器

```python
import time
import functools

def timer(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        end = time.perf_counter()
        print(f"{func.__name__} 执行时间: {end - start:.4f} 秒")
        return result
    return wrapper

# 使用示例
@timer
def slow_function():
    time.sleep(1)
    return "完成"
```

## 5. 实用工具函数

### 5.1 重试机制

```python
def retry(max_attempts=3, delay=1):
    def decorator(func):
        def wrapper(*args, **kwargs):
            attempts = 0
            while attempts < max_attempts:
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    attempts += 1
                    if attempts == max_attempts:
                        raise e
                    time.sleep(delay)
            return None
        return wrapper
    return decorator

# 使用示例
@retry(max_attempts=3, delay=1)
def unstable_function():
    import random
    if random.random() < 0.7:
        raise Exception("随机错误")
    return "成功"
```

### 5.2 日志装饰器

```python
import logging
import functools

def log_function(logger=None):
    if logger is None:
        logger = logging.getLogger(__name__)
        
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            logger.info(f"调用函数 {func.__name__}")
            try:
                result = func(*args, **kwargs)
                logger.info(f"函数 {func.__name__} 返回: {result}")
                return result
            except Exception as e:
                logger.error(f"函数 {func.__name__} 错误: {str(e)}")
                raise
        return wrapper
    return decorator
```

## 6. 验证码生成器

```python
# 导入所需模块
import random
import string

# 生成数字验证码
def generate_numeric_code(length=6):
    """生成指定长度的数字验证码"""
    # 生成随机数字
    code = ''.join(random.choices('0123456789', k=length))
    return code

# 生成字母验证码
def generate_letter_code(length=6):
    """生成指定长度的字母验证码"""
    # 使用大写字母
    letters = string.ascii_uppercase
    code = ''.join(random.choices(letters, k=length))
    return code

# 生成数字字母混合验证码
def generate_mixed_code(length=6):
    """生成指定长度的数字字母混合验证码"""
    # 数字和字母的组合
    characters = string.digits + string.ascii_letters
    code = ''.join(random.choices(characters, k=length))
    return code

# 生成自定义验证码
def generate_custom_code(length=6, use_digits=True, use_uppercase=True, 
                        use_lowercase=False, use_punctuation=False):
    """
    生成自定义验证码
    :param length: 验证码长度
    :param use_digits: 是否使用数字
    :param use_uppercase: 是否使用大写字母
    :param use_lowercase: 是否使用小写字母
    :param use_punctuation: 是否使用特殊字符
    :return: 生成的验证码
    """
    # 构建字符池
    char_pool = ''
    if use_digits:
        char_pool += string.digits
    if use_uppercase:
        char_pool += string.ascii_uppercase
    if use_lowercase:
        char_pool += string.ascii_lowercase
    if use_punctuation:
        char_pool += string.punctuation
    
    # 确保字符池不为空
    if not char_pool:
        raise ValueError("至少需要选择一种字符类型")
    
    # 生成验证码
    code = ''.join(random.choices(char_pool, k=length))
    return code

# 使用示例
print("数字验证码：")
print(generate_numeric_code())          # 默认6位
print(generate_numeric_code(4))         # 4位数字验证码

print("\n字母验证码：")
print(generate_letter_code())           # 默认6位
print(generate_letter_code(8))          # 8位字母验证码

print("\n混合验证码：")
print(generate_mixed_code())            # 默认6位
print(generate_mixed_code(10))          # 10位混合验证码

print("\n自定义验证码：")
# 生成8位数字和大写字母的验证码
print(generate_custom_code(8, use_digits=True, use_uppercase=True))
# 生成6位包含数字、大小写字母和特殊字符的验证码
print(generate_custom_code(6, use_digits=True, use_uppercase=True, 
                         use_lowercase=True, use_punctuation=True))
```

输出示例：
```
数字验证码：
847591
4721

字母验证码：
KXMQPL
NBTWHKJR

混合验证码：
Kj2Nm9
4kPx7vJnL2

自定义验证码：
12BKPQ5N
$Kj2@n
```

这个验证码生成器提供了以下功能：
1. 可以生成纯数字验证码
2. 可以生成纯字母验证码
3. 可以生成数字字母混合验证码
4. 可以生成自定义字符组合的验证码
5. 支持设置验证码长度

注意事项：
1. 验证码长度建议4-8位，过长会影响用户体验
2. 建议使用易识别的字符，避免使用容易混淆的字符（如0和O、1和l）
3. 实际应用中应该考虑验证码的有效期
4. 可以结合图片生成功能，制作图形验证码
5. 注意验证码的安全性，避免使用可预测的生成方式

## 注意事项

1. 函数应该遵循单一职责原则
2. 适当使用类型提示和文档字符串
3. 处理好异常情况
4. 注意函数的性能影响
5. 合理使用装饰器简化代码

## 最佳实践

1. 使用有意义的函数名和参数名
2. 添加适当的注释和文档
3. 进行充分的错误处理
4. 考虑函数的复用性
5. 注意函数的副作用