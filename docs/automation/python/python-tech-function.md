---
title: Python-函数
sidebar_position: 11
---

# Python 函数使用指南

函数是 Python 中代码复用的基本单位，用于封装特定功能的代码块。

## 1. 函数定义

### 1.1 基本语法

```python
# 基本函数定义
def greet(name):
    """简单的问候函数"""
    return f"Hello, {name}!"

# 带默认参数的函数
def greet_with_title(name, title="Mr."):
    return f"Hello, {title} {name}!"

# 多个返回值
def get_user_info():
    name = "张三"
    age = 25
    return name, age  # 返回元组
```

### 1.2 参数类型

```python
# 位置参数
def add(x, y):
    return x + y

# 关键字参数
def greet(first_name, last_name):
    return f"Hello, {first_name} {last_name}!"

# 默认参数
def connect(host="localhost", port=3306):
    return f"Connecting to {host}:{port}"

# 可变参数 (*args)
def sum_numbers(*numbers):
    return sum(numbers)

# 关键字可变参数 (**kwargs)
def print_info(**info):
    for key, value in info.items():
        print(f"{key}: {value}")
```

## 2. 函数调用

```python
# 基本调用
result = add(1, 2)

# 使用关键字参数
greet(last_name="Zhang", first_name="San")

# 混合使用位置参数和关键字参数
connect("127.0.0.1", port=8080)

# 使用可变参数
sum_numbers(1, 2, 3, 4, 5)

# 使用关键字可变参数
print_info(name="张三", age=25, city="北京")
```

## 3. 高级特性

### 3.1 装饰器

```python
# 简单装饰器
def log_function(func):
    def wrapper(*args, **kwargs):
        print(f"调用函数: {func.__name__}")
        result = func(*args, **kwargs)
        print(f"函数返回: {result}")
        return result
    return wrapper

# 使用装饰器
@log_function
def add(x, y):
    return x + y

# 带参数的装饰器
def repeat(times):
    def decorator(func):
        def wrapper(*args, **kwargs):
            for _ in range(times):
                result = func(*args, **kwargs)
            return result
        return wrapper
    return decorator

@repeat(3)
def greet(name):
    print(f"Hello, {name}!")
```

### 3.2 闭包

```python
def counter():
    count = 0
    def increment():
        nonlocal count
        count += 1
        return count
    return increment

# 使用闭包
my_counter = counter()
print(my_counter())  # 1
print(my_counter())  # 2
```

### 3.3 lambda 函数

```python
# 简单的 lambda 函数
square = lambda x: x**2

# 在排序中使用
students = [("张三", 85), ("李四", 92), ("王五", 78)]
sorted_students = sorted(students, key=lambda x: x[1], reverse=True)

# 在函数式编程中使用
numbers = [1, 2, 3, 4, 5]
squares = list(map(lambda x: x**2, numbers))
evens = list(filter(lambda x: x % 2 == 0, numbers))
```

## 4. 作用域和命名空间

```python
# 全局变量和局部变量
global_var = 100

def func():
    local_var = 200
    print(global_var)    # 可以访问全局变量
    print(local_var)     # 局部变量

# 使用 global 关键字
def modify_global():
    global global_var
    global_var = 300

# 使用 nonlocal 关键字
def outer():
    x = 100
    def inner():
        nonlocal x
        x = 200
    inner()
    return x
```

## 5. 函数式编程

```python
# map 函数
numbers = [1, 2, 3, 4, 5]
squares = list(map(lambda x: x**2, numbers))

# filter 函数
evens = list(filter(lambda x: x % 2 == 0, numbers))

# reduce 函数
from functools import reduce
sum_all = reduce(lambda x, y: x + y, numbers)

# 列表推导式替代
squares = [x**2 for x in numbers]
evens = [x for x in numbers if x % 2 == 0]
```

## 6. 实用示例

### 6.1 缓存装饰器

```python
from functools import lru_cache

@lru_cache(maxsize=None)
def fibonacci(n):
    if n < 2:
        return n
    return fibonacci(n-1) + fibonacci(n-2)

# 自定义缓存装饰器
def cache_decorator(func):
    cache = {}
    def wrapper(*args):
        if args in cache:
            return cache[args]
        result = func(*args)
        cache[args] = result
        return result
    return wrapper
```

### 6.2 参数验证

```python
def validate_params(func):
    def wrapper(*args, **kwargs):
        # 验证参数
        if len(args) < 1:
            raise ValueError("缺少必要参数")
        # 类型检查
        if not isinstance(args[0], (int, float)):
            raise TypeError("参数类型错误")
        return func(*args, **kwargs)
    return wrapper

@validate_params
def calculate_square(number):
    return number ** 2
```

## 注意事项

1. 函数名应该清晰地表明其功能
2. 遵循单一职责原则，一个函数只做一件事
3. 适当使用文档字符串说明函数功能
4. 注意参数的默认值是在函数定义时计算的
5. 避免修改可变类型的默认参数

## 常见错误处理

```python
# 参数错误处理
def divide(x, y):
    try:
        return x / y
    except ZeroDivisionError:
        print("除数不能为零")
        return None
    except TypeError:
        print("参数类型错误")
        return None

# 参数验证
def process_age(age):
    if not isinstance(age, int):
        raise TypeError("年龄必须是整数")
    if age < 0 or age > 150:
        raise ValueError("年龄超出有效范围")
    return age
``` 