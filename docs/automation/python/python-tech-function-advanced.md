---
title: Python-函数进阶
sidebar_position: 13
---

# Python 函数进阶使用指南

本文档介绍 Python 函数的高级特性和进阶用法。

## 1. 函数参数进阶

### 1.1 参数解包

```python
# 列表解包
def add(a, b, c):
    return a + b + c

numbers = [1, 2, 3]
result = add(*numbers)  # 等同于 add(1, 2, 3)

# 字典解包
def user_info(name, age, city):
    return f"{name} is {age} years old and lives in {city}"

data = {'name': '张三', 'age': 25, 'city': '北京'}
info = user_info(**data)  # 等同于 user_info(name='张三', age=25, city='北京')
```

### 1.2 参数类型注解

```python
from typing import List, Dict, Optional, Union

# 基本类型注解
def greet(name: str, age: int) -> str:
    return f"Hello, {name}! You are {age} years old."

# 复杂类型注解
def process_data(numbers: List[int],
                config: Dict[str, str],
                debug: bool = False) -> Optional[List[float]]:
    if not numbers:
        return None
    return [float(n) * 1.5 for n in numbers]

# 联合类型
def convert_value(value: Union[int, float, str]) -> float:
    return float(value)
```

## 2. 闭包和装饰器进阶

### 2.1 带参数的装饰器

```python
# 装饰器工厂
def repeat(times: int):
    def decorator(func):
        def wrapper(*args, **kwargs):
            results = []
            for _ in range(times):
                result = func(*args, **kwargs)
                results.append(result)
            return results
        return wrapper
    return decorator

# 使用装饰器工厂
@repeat(times=3)
def greet(name: str) -> str:
    return f"Hello, {name}!"

# 多个装饰器组合
def log_args(func):
    def wrapper(*args, **kwargs):
        print(f"调用 {func.__name__} 参数: {args}, {kwargs}")
        return func(*args, **kwargs)
    return wrapper

def validate_args(func):
    def wrapper(*args, **kwargs):
        if not args and not kwargs:
            raise ValueError("没有提供参数")
        return func(*args, **kwargs)
    return wrapper

@log_args
@validate_args
def process_data(*args, **kwargs):
    return "处理完成"
```

### 2.2 类装饰器

```python
# 类装饰器
class Singleton:
    def __init__(self, cls):
        self._cls = cls
        self._instance = None

    def __call__(self, *args, **kwargs):
        if self._instance is None:
            self._instance = self._cls(*args, **kwargs)
        return self._instance

@Singleton
class Database:
    def __init__(self):
        self.connected = False

    def connect(self):
        if not self.connected:
            print("建立数据库连接...")
            self.connected = True
```

## 3. 函数式编程特性

### 3.1 高阶函数

```python
# map 高级用法
def process_pair(x, y):
    return x * y

numbers1 = [1, 2, 3]
numbers2 = [4, 5, 6]
result = list(map(process_pair, numbers1, numbers2))

# reduce 高级用法
from functools import reduce

def merge_dicts(dict1, dict2):
    dict1.update(dict2)
    return dict1

dicts = [{'a': 1}, {'b': 2}, {'c': 3}]
result = reduce(merge_dicts, dicts)

# filter 高级用法
def is_valid_dict(d):
    return all(isinstance(v, (int, float)) for v in d.values())

dicts = [{'a': 1}, {'b': 'invalid'}, {'c': 3.14}]
valid_dicts = list(filter(is_valid_dict, dicts))
```

### 3.2 偏函数和柯里化

```python
from functools import partial

# 偏函数
def power(base, exponent):
    return base ** exponent

square = partial(power, exponent=2)
cube = partial(power, exponent=3)

# 柯里化
def curry_function(func):
    def curried(*args):
        if len(args) >= func.__code__.co_argcount:
            return func(*args)
        return lambda *args2: curried(*(args + args2))
    return curried

@curry_function
def add_three(a, b, c):
    return a + b + c

add_one = add_three(1)
add_two = add_one(2)
result = add_two(3)  # 6
```

## 4. 生成器和迭代器进阶

### 4.1 生成器表达式和yield from

```python
# 生成器表达式
def get_lengths(strings):
    return (len(s) for s in strings)

# yield from
def flatten(nested_list):
    for item in nested_list:
        if isinstance(item, list):
            yield from flatten(item)
        else:
            yield item

# 生成器管道
def read_data():
    for i in range(100):
        yield i

def filter_even(numbers):
    for num in numbers:
        if num % 2 == 0:
            yield num

def multiply_by_two(numbers):
    for num in numbers:
        yield num * 2

# 使用管道
pipeline = multiply_by_two(filter_even(read_data()))
```

### 4.2 自定义迭代器

```python
class CountDown:
    def __init__(self, start):
        self.start = start

    def __iter__(self):
        return self

    def __next__(self):
        if self.start <= 0:
            raise StopIteration
        self.start -= 1
        return self.start + 1

# 带状态的生成器
def stateful_generator():
    state = {'count': 0}
    
    while True:
        received = yield state['count']
        if received is not None:
            state['count'] += received
```

## 5. 异步函数

### 5.1 基本异步操作

```python
import asyncio

async def async_operation(delay: float, value: str) -> str:
    await asyncio.sleep(delay)
    return f"完成操作: {value}"

async def main():
    # 并发执行多个异步操作
    tasks = [
        async_operation(1.0, "A"),
        async_operation(2.0, "B"),
        async_operation(0.5, "C")
    ]
    results = await asyncio.gather(*tasks)
    return results

# 运行异步函数
asyncio.run(main())
```

### 5.2 异步上下文管理器

```python
class AsyncResource:
    async def __aenter__(self):
        print("获取资源")
        await asyncio.sleep(1)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        print("释放资源")
        await asyncio.sleep(0.5)

async def use_resource():
    async with AsyncResource() as resource:
        print("使用资源")
        await asyncio.sleep(1)
```

## 注意事项

1. 使用类型注解时要注意性能影响
2. 装饰器会改变函数的元数据，使用 `functools.wraps` 保留原函数信息
3. 生成器表达式比列表推导式更节省内存
4. 异步函数中不要使用阻塞操作
5. 注意闭包中变量的作用域和生命周期

## 最佳实践

1. 合理使用类型��解提高代码可读性
2. 装饰器链的顺序会影响执行顺序
3. 优先使用生成器处理大数据集
4. 异步函数应该是"真正的"异步
5. 使用 `functools` 模块提供的工具函数 