---
title: Python-面向对象高级
sidebar_position: 17
---

# Python 面向对象高级特性

本文档介绍 Python 面向对象编程的高级特性和设计模式。

## 1. 元类编程

### 1.1 自定义元类

```python
class MetaLogger(type):
    def __new__(cls, name, bases, attrs):
        # 为每个方法添加日志功能
        for key, value in attrs.items():
            if callable(value) and not key.startswith('__'):
                attrs[key] = cls.log_decorator(value)
        return super().__new__(cls, name, bases, attrs)
    
    @staticmethod
    def log_decorator(func):
        def wrapper(*args, **kwargs):
            print(f"调用方法: {func.__name__}")
            result = func(*args, **kwargs)
            print(f"方法返回: {result}")
            return result
        return wrapper

class MyClass(metaclass=MetaLogger):
    def hello(self):
        return "Hello, World!"

# 使用示例
obj = MyClass()
obj.hello()  # 自动记录日志
```

### 1.2 抽象基类

```python
from abc import ABC, abstractmethod

class Shape(ABC):
    @abstractmethod
    def area(self):
        """计算面积"""
        pass
    
    @abstractmethod
    def perimeter(self):
        """计算周长"""
        pass
    
    @property
    @abstractmethod
    def name(self):
        """形状名称"""
        pass

class Circle(Shape):
    def __init__(self, radius):
        self._radius = radius
    
    def area(self):
        return 3.14 * self._radius ** 2
    
    def perimeter(self):
        return 2 * 3.14 * self._radius
    
    @property
    def name(self):
        return "圆形"
```

## 2. 描述符

### 2.1 数据描述符

```python
class TypedProperty:
    def __init__(self, name, type_):
        self.name = name
        self.type_ = type_
    
    def __get__(self, instance, owner):
        if instance is None:
            return self
        return instance.__dict__.get(self.name)
    
    def __set__(self, instance, value):
        if not isinstance(value, self.type_):
            raise TypeError(f"{self.name} 必须是 {self.type_} 类型")
        instance.__dict__[self.name] = value

class Person:
    name = TypedProperty('name', str)
    age = TypedProperty('age', int)
    
    def __init__(self, name, age):
        self.name = name
        self.age = age

# 使用示例
person = Person("张三", 25)
try:
    person.age = "invalid"  # 引发 TypeError
except TypeError as e:
    print(e)
```

### 2.2 非数据描述符

```python
class LazyProperty:
    def __init__(self, func):
        self.func = func
        self.__doc__ = func.__doc__
    
    def __get__(self, instance, owner):
        if instance is None:
            return self
        value = self.func(instance)
        setattr(instance, self.func.__name__, value)
        return value

class Circle:
    def __init__(self, radius):
        self.radius = radius
    
    @LazyProperty
    def area(self):
        print("计算面积...")
        return 3.14 * self.radius ** 2

# 使用示例
circle = Circle(5)
print(circle.area)  # 第一次计算
print(circle.area)  # 直接返回缓存值
```

## 3. 设计模式

### 3.1 单例模式

```python
class Singleton(type):
    _instances = {}
    
    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super().__call__(*args, **kwargs)
        return cls._instances[cls]

class Database(metaclass=Singleton):
    def __init__(self):
        print("初始化数据库连接...")
        self.connected = True
    
    def query(self, sql):
        if self.connected:
            return f"执行查询: {sql}"

# 使用示例
db1 = Database()
db2 = Database()
print(db1 is db2)  # 输出: True
```

### 3.2 工厂模式

```python
class Animal:
    def speak(self):
        pass

class Dog(Animal):
    def speak(self):
        return "汪汪!"

class Cat(Animal):
    def speak(self):
        return "喵喵!"

class AnimalFactory:
    @staticmethod
    def create_animal(animal_type):
        if animal_type == "dog":
            return Dog()
        elif animal_type == "cat":
            return Cat()
        raise ValueError("未知的动物类型")

# 使用示例
factory = AnimalFactory()
dog = factory.create_animal("dog")
cat = factory.create_animal("cat")
print(dog.speak())  # 输出: 汪汪!
print(cat.speak())  # 输出: 喵喵!
```

## 4. 高级特性

### 4.1 上下文管理器

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
        if exc_type is not None:
            # 处理异常
            print(f"发生异常: {exc_val}")
        return True  # 抑制异常

# 使用示例
with FileManager('test.txt', 'w') as f:
    f.write('Hello, World!')
```

### 4.2 属性访问控制

```python
class ProtectedAttributes:
    def __init__(self):
        self._internal = 0
    
    def __getattribute__(self, name):
        print(f"访问属性: {name}")
        return super().__getattribute__(name)
    
    def __setattr__(self, name, value):
        print(f"设置属性: {name} = {value}")
        super().__setattr__(name, value)
    
    def __delattr__(self, name):
        print(f"删除属性: {name}")
        super().__delattr__(name)

# 使用示例
obj = ProtectedAttributes()
obj._internal = 42
print(obj._internal)
del obj._internal
```

## 5. 最佳实践

### 5.1 多重继承

```python
class LoggerMixin:
    def log(self, message):
        print(f"[{self.__class__.__name__}] {message}")

class SaverMixin:
    def save(self):
        print(f"保存 {self.__class__.__name__} 的状态")

class User(LoggerMixin, SaverMixin):
    def __init__(self, name):
        self.name = name
    
    def update(self):
        self.log(f"更新用户: {self.name}")
        self.save()

# 使用示例
user = User("张三")
user.update()
```

### 5.2 属性验证

```python
class ValidatedProperty:
    def __init__(self, validator):
        self.validator = validator
        self.name = None
    
    def __set_name__(self, owner, name):
        self.name = name
    
    def __get__(self, instance, owner):
        if instance is None:
            return self
        return instance.__dict__.get(self.name)
    
    def __set__(self, instance, value):
        if self.validator(value):
            instance.__dict__[self.name] = value
        else:
            raise ValueError(f"Invalid value for {self.name}")

class User:
    name = ValidatedProperty(lambda x: isinstance(x, str) and len(x) >= 3)
    age = ValidatedProperty(lambda x: isinstance(x, int) and 0 <= x <= 150)

# 使用示例
user = User()
user.name = "张三"  # 有效
try:
    user.age = -1   # 无效
except ValueError:
    print("年龄无效")
```

## 注意事项

1. 元类编程要谨慎使用，避免过度复杂化
2. 描述符应该是类级别的属性
3. 单例模式要考虑线程安全问题
4. 多重继承要注意方法解析顺序（MRO）
5. 属性访问控制要考虑性能影响

## 最佳实践

1. 优先使用组合而不是继承
2. 使用描述符实现可重用的属性验证
3. 合理使用混入类（Mixin）来增加功能
4. 遵循开闭原则，对扩展开放，对修改关闭
5. 使用抽象基类定义接口规范 