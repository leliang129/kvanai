---
title: Python-函数高级应用
sidebar_position: 14
---

# Python 函数高级应用

本文档介绍 Python 函数的高级应用，包括装饰器模式、上下文管理器等高级特性。

## 1. 装饰器进阶

### 1.1 带参数的装饰器

```python
import functools
import time

# 带参数的计时装饰器
def timer(prefix=''):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            start = time.time()
            result = func(*args, **kwargs)
            end = time.time()
            print(f"{prefix} 函数 {func.__name__} 执行时间: {end - start:.4f}秒")
            return result
        return wrapper
    return decorator

# 使用示例
@timer(prefix="DEBUG:")
def slow_function():
    time.sleep(1)
    return "完成"
```

### 1.2 多重装饰器

```python
def bold(func):
    @functools.wraps(func)
    def wrapper():
        return f"<b>{func()}</b>"
    return wrapper

def italic(func):
    @functools.wraps(func)
    def wrapper():
        return f"<i>{func()}</i>"
    return wrapper

@bold
@italic
def hello():
    return "Hello, World!"

print(hello())  # 输出: <b><i>Hello, World!</i></b>
```

### 1.3 类装饰器

```python
class Singleton:
    """单例模式装饰器"""
    def __init__(self, cls):
        self._cls = cls
        self._instance = None

    def __call__(self, *args, **kwargs):
        if self._instance is None:
            self._instance = self._cls(*args, **kwargs)
        return self._instance

@Singleton
class Database:
    def __init__(self, url):
        self.url = url
        print(f"连接到数据库: {url}")

# 使用示例
db1 = Database("localhost:5432")
db2 = Database("localhost:5432")
print(db1 is db2)  # 输出: True
```

### 1.4 内置装饰器

```python
class Calculator:
    # 静态方法装饰器
    # 不需要实例即可调用，也不需要传入 self 或 cls 参数
    @staticmethod
    def add(x, y):
        return x + y
    
    # 类方法装饰器
    # 第一个参数是类本身，通常命名为 cls
    @classmethod
    def from_string(cls, expression):
        x, op, y = expression.split()
        return cls(int(x), int(y))
    
    # 属性装饰器
    # 将方法转换为属性
    @property
    def value(self):
        return self._value
    
    # 设置器装饰器
    @value.setter
    def value(self, new_value):
        if new_value < 0:
            raise ValueError("Value cannot be negative")
        self._value = new_value

# 使用示例
# 静态方法调用
result = Calculator.add(1, 2)  # 不需要创建实例

# 类方法调用
calc = Calculator.from_string("1 + 2")

# 属性访问
calc = Calculator()
calc.value = 10  # 使用 setter
print(calc.value)  # 使用 getter
```

这些内置装饰器的主要用途：

1. `@staticmethod`
   - 不需要访问类或实例的方法
   - 纯功能性的方法，与类的状态无关
   - 可以直接通过类名调用

2. `@classmethod`
   - 需要访问类属性但不需要实例的方法
   - 常用于替代构造函数，提供额外的实例化方式
   - 第一个参数是类本身（cls）

3. `@property`
   - 将方法转换为只读属性
   - 提供对属性的受控访问
   - 可以添加验证和计算逻辑

4. `@属性名.setter`
   - 为属性提供设置方法
   - 可以在设置值时进行验证
   - 与 @property 配合使用

## 2. 上下文管理器

### 2.1 基于类的上下文管理器

```python
class FileManager:
    def __init__(self, filename, mode='r'):
        self.filename = filename
        self.mode = mode
        self.file = None

    def __enter__(self):
        self.file = open(self.filename, self.mode)
        return self.file

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.file:
            self.file.close()
        # 返回 True 表示异常已处理
        return True

# 使用示例
with FileManager('test.txt', 'w') as f:
    f.write('Hello, World!')
```

### 2.2 基于生成器的上下文管理器

```python
from contextlib import contextmanager

@contextmanager
def timer_context(name):
    start = time.time()
    yield
    end = time.time()
    print(f"{name} 执行时间: {end - start:.4f}秒")

# 使用示例
with timer_context("操作"):
    time.sleep(1)
```

## 3. 函数缓存

### 3.1 使用装饰器实现缓存

```python
def memoize(func):
    cache = {}
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        # 创建可哈希的键
        key = str(args) + str(sorted(kwargs.items()))
        if key not in cache:
            cache[key] = func(*args, **kwargs)
        return cache[key]
    return wrapper

@memoize
def fibonacci(n):
    if n < 2:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```

### 3.2 使用 lru_cache

```python
from functools import lru_cache

@lru_cache(maxsize=128)
def expensive_function(n):
    time.sleep(0.1)
    return n * n

# 查看缓存信息
print(expensive_function.cache_info())
```

## 4. 函数工厂

### 4.1 动态创建函数

```python
def create_power_func(power):
    def power_func(x):
        return x ** power
    return power_func

# 创建具体函数
square = create_power_func(2)
cube = create_power_func(3)

print(square(4))  # 输出: 16
print(cube(4))    # 输出: 64
```

### 4.2 参数预设

```python
def create_greeting(prefix):
    def greeting(name):
        return f"{prefix}, {name}!"
    return greeting

# 创建特定的问候函数
say_hello = create_greeting("Hello")
say_hi = create_greeting("Hi")

print(say_hello("Alice"))  # 输出: Hello, Alice!
print(say_hi("Bob"))      # 输出: Hi, Bob!
```

## 5. 高级回调模式

### 5.1 事件处理器

```python
class EventHandler:
    def __init__(self):
        self._handlers = []

    def add_handler(self, handler):
        self._handlers.append(handler)
        return handler  # 允许用作装饰器

    def remove_handler(self, handler):
        self._handlers.remove(handler)

    def fire(self, *args, **kwargs):
        for handler in self._handlers:
            handler(*args, **kwargs)

# 使用示例
event = EventHandler()

@event.add_handler
def on_event(message):
    print(f"处理事件: {message}")

event.fire("Something happened!")
```

### 5.2 中间件模式

```python
class MiddlewareManager:
    def __init__(self):
        self.middlewares = []

    def add_middleware(self, middleware):
        self.middlewares.append(middleware)

    def process(self, data):
        def execute(index, current_data):
            if index >= len(self.middlewares):
                return current_data
            return self.middlewares[index](current_data, 
                   lambda d: execute(index + 1, d))
        return execute(0, data)

# 使用示例
def logging_middleware(data, next_middleware):
    print(f"处理数据: {data}")
    result = next_middleware(data)
    print(f"处理完成: {result}")
    return result

def uppercase_middleware(data, next_middleware):
    if isinstance(data, str):
        return next_middleware(data.upper())
    return next_middleware(data)

manager = MiddlewareManager()
manager.add_middleware(logging_middleware)
manager.add_middleware(uppercase_middleware)

result = manager.process("hello")
```

## 6. 函数注解和类型提示

```python
from typing import List, Dict, Optional, Union, Callable

def process_data(
    data: List[int],
    callback: Callable[[int], int],
    config: Optional[Dict[str, str]] = None
) -> Union[List[int], None]:
    """处理数字列表并返回结果"""
    if not data:
        return None
    return [callback(x) for x in data]

# 使用示例
def double(x: int) -> int:
    return x * 2

numbers = [1, 2, 3, 4, 5]
result = process_data(numbers, double)
```

## 注意事项

1. 装饰器会改变函数的元数据，使用 `functools.wraps` 保留原函数信息
2. 缓存装饰器要注意内存使用
3. 上下文管理器要确保资源正确释放
4. 回调函数要考虑异常处理
5. 类型提示主要用于文档和静态检查，不影响运行时行为

## 最佳实践

1. 合理使用装饰器简化代码
2. 使用 `contextlib` 简化上下文管理器的创建
3. 适当使用函数缓存提高性能
4. 使用类型提示提高代码可读性
5. 注意函数的副作用和纯函数设计 