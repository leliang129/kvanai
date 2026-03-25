---
title: Python-面向对象进阶
sidebar_position: 16
---

# Python 面向对象编程进阶

本文档介绍 Python 面向对象编程的进阶特性和高级用法。

## 1. 特殊方法（魔术方法）

### 1.1 基本特殊方法

```python
class Vector:
    def __init__(self, x, y):
        self.x = x
        self.y = y
    
    # 字符串表示
    def __str__(self):
        return f"Vector({self.x}, {self.y})"
    
    def __repr__(self):
        return f"Vector(x={self.x}, y={self.y})"
    
    # 运算符重载
    def __add__(self, other):
        return Vector(self.x + other.x, self.y + other.y)
    
    def __sub__(self, other):
        return Vector(self.x - other.x, self.y - other.y)
    
    # 比较运算
    def __eq__(self, other):
        return self.x == other.x and self.y == other.y
    
    def __lt__(self, other):
        return (self.x**2 + self.y**2) < (other.x**2 + other.y**2)

# 使用示例
v1 = Vector(1, 2)
v2 = Vector(3, 4)
print(v1)           # 输出: Vector(1, 2)
print(v1 + v2)      # 输出: Vector(4, 6)
print(v1 < v2)      # 输出: True
```

### 1.2 容器类特殊方法

```python
class MyList:
    def __init__(self, items):
        self.items = list(items)
    
    # 长度
    def __len__(self):
        return len(self.items)
    
    # 索引访问
    def __getitem__(self, index):
        return self.items[index]
    
    def __setitem__(self, index, value):
        self.items[index] = value
    
    # 成员检查
    def __contains__(self, item):
        return item in self.items
    
    # 迭代器
    def __iter__(self):
        return iter(self.items)

# 使用示例
my_list = MyList([1, 2, 3, 4, 5])
print(len(my_list))     # 输出: 5
print(my_list[0])       # 输出: 1
print(3 in my_list)     # 输出: True
for item in my_list:    # 迭代
    print(item)
```

## 2. 属性管理

### 2.1 描述符

```python
class Validator:
    def __init__(self, min_value=None, max_value=None):
        self.min_value = min_value
        self.max_value = max_value
    
    def __set_name__(self, owner, name):
        self.name = name
    
    def __get__(self, instance, owner):
        if instance is None:
            return self
        return instance.__dict__.get(self.name)
    
    def __set__(self, instance, value):
        if not isinstance(value, (int, float)):
            raise TypeError(f"{self.name} must be a number")
        if self.min_value is not None and value < self.min_value:
            raise ValueError(f"{self.name} cannot be less than {self.min_value}")
        if self.max_value is not None and value > self.max_value:
            raise ValueError(f"{self.name} cannot be greater than {self.max_value}")
        instance.__dict__[self.name] = value

class Person:
    age = Validator(min_value=0, max_value=150)
    height = Validator(min_value=0, max_value=300)
    
    def __init__(self, name, age, height):
        self.name = name
        self.age = age
        self.height = height

# 使用示例
person = Person("张三", 25, 175)
try:
    person.age = -1  # 引发 ValueError
except ValueError as e:
    print(e)
```

### 2.2 属性访问控制

```python
class PrivateAttrMixin:
    def __setattr__(self, name, value):
        if name.startswith('_'):
            raise AttributeError(f"Cannot set private attribute {name}")
        super().__setattr__(name, value)
    
    def __getattr__(self, name):
        if name.startswith('_'):
            raise AttributeError(f"Cannot access private attribute {name}")
        return super().__getattr__(name)

class User(PrivateAttrMixin):
    def __init__(self, name):
        self.name = name
        self._password = "secret"  # 这会引发错误

# 使用示例
user = User("张三")
try:
    print(user._password)  # 引发 AttributeError
except AttributeError as e:
    print(e)
```

## 3. 元类编程

### 3.1 基本元类

```python
class MetaLogger(type):
    def __new__(cls, name, bases, attrs):
        # 添加日志方法
        def log_method(self, message):
            print(f"[{self.__class__.__name__}] {message}")
        
        attrs['log'] = log_method
        return super().__new__(cls, name, bases, attrs)

class MyClass(metaclass=MetaLogger):
    def __init__(self, name):
        self.name = name

# 使用示例
obj = MyClass("test")
obj.log("This is a test message")  # 输出: [MyClass] This is a test message
```

### 3.2 类装饰器

```python
def singleton(cls):
    instances = {}
    def get_instance(*args, **kwargs):
        if cls not in instances:
            instances[cls] = cls(*args, **kwargs)
        return instances[cls]
    return get_instance

@singleton
class Database:
    def __init__(self, url):
        self.url = url
        print(f"Connecting to {url}")

# 使用示例
db1 = Database("localhost:5432")
db2 = Database("localhost:5432")
print(db1 is db2)  # 输出: True
```

## 4. 高级特性

### 4.1 抽象基类

```python
from abc import ABC, abstractmethod

class Shape(ABC):
    @abstractmethod
    def area(self):
        pass
    
    @abstractmethod
    def perimeter(self):
        pass

class Rectangle(Shape):
    def __init__(self, width, height):
        self.width = width
        self.height = height
    
    def area(self):
        return self.width * self.height
    
    def perimeter(self):
        return 2 * (self.width + self.height)

# 使用示例
# shape = Shape()  # 这会引发错误
rect = Rectangle(5, 3)
print(rect.area())      # 输出: 15
print(rect.perimeter()) # 输出: 16
```

### 4.2 混入类（Mixins）

```python
class SerializeMixin:
    def to_dict(self):
        return {
            key: value for key, value in self.__dict__.items()
            if not key.startswith('_')
        }
    
    def to_json(self):
        import json
        return json.dumps(self.to_dict())

class ValidateMixin:
    def validate(self):
        for key, value in self.__dict__.items():
            if value is None:
                raise ValueError(f"{key} cannot be None")

class User(SerializeMixin, ValidateMixin):
    def __init__(self, name, email):
        self.name = name
        self.email = email

# 使用示例
user = User("张三", "zhangsan@example.com")
print(user.to_dict())
print(user.to_json())
user.validate()
```

## 注意事项

1. 特殊方法应该返回适当的类型和值
2. 描述符在处理属性访问时要考虑性能影响
3. 元类编程要谨慎使用，避免过度复杂化
4. 混入类应该只提供额外的功能，不应该包含状态
5. 抽象基类应该清晰定义接口规范

## 最佳实践

1. 合理使用特殊方法来增强类的功能
2. 使用描述符来实现属性的验证和转换
3. 使用元类来实现框架级别的功能
4. 使用混入类来实现代码复用
5. 使用抽象基类来定义接口规范 