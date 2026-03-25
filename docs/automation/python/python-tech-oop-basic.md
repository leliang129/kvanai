---
title: Python-面向对象基础
sidebar_position: 15
---

# Python 面向对象编程基础

面向对象编程（OOP）是一种程序设计范式，Python 作为一种面向对象的语言，提供了完整的面向对象编程支持。

## 1. 类的基本概念

### 1.1 类的定义和实例化

```python
class Student:
    # 类属性
    school = "Python大学"
    
    # 初始化方法
    def __init__(self, name, age):
        # 实例属性
        self.name = name
        self.age = age
    
    # 实例方法
    def introduce(self):
        return f"我叫{self.name}，今年{self.age}岁"

# 创建实例
student1 = Student("张三", 20)
student2 = Student("李四", 22)

# 访问属性和方法
print(student1.name)           # 输出: 张三
print(student1.introduce())    # 输出: 我叫张三，今年20岁
print(Student.school)          # 输出: Python大学
```

### 1.2 属性和方法

```python
class Rectangle:
    def __init__(self, width, height):
        self.width = width    # 公有属性
        self._height = height  # 受保护属性（约定）
        self.__area = None    # 私有属性
    
    # 实例方法
    def calculate_area(self):
        self.__area = self.width * self._height
        return self.__area
    
    # 静态方法
    @staticmethod
    def is_valid_dimensions(width, height):
        return width > 0 and height > 0
    
    # 类方法
    @classmethod
    def create_square(cls, side_length):
        return cls(side_length, side_length)

# 使用示例
rect = Rectangle(5, 3)
print(rect.calculate_area())  # 输出: 15

# 创建正方形
square = Rectangle.create_square(4)
print(square.calculate_area())  # 输出: 16
```

## 2. 封装

### 2.1 访问控制

```python
class BankAccount:
    def __init__(self, account_number, balance):
        self.__account_number = account_number  # 私有属性
        self.__balance = balance
    
    # getter 方法
    def get_balance(self):
        return self.__balance
    
    # setter 方法
    def set_balance(self, amount):
        if amount >= 0:
            self.__balance = amount
        else:
            raise ValueError("余额不能为负数")
    
    # 对外公开的方法
    def deposit(self, amount):
        if amount > 0:
            self.__balance += amount
            return True
        return False
    
    def withdraw(self, amount):
        if 0 < amount <= self.__balance:
            self.__balance -= amount
            return True
        return False

# 使用示例
account = BankAccount("1001", 1000)
account.deposit(500)
print(account.get_balance())  # 输出: 1500
```

### 2.2 属性装饰器

```python
class Person:
    def __init__(self, name, age):
        self._name = name
        self._age = age
    
    # 使用 property 装饰器
    @property
    def name(self):
        return self._name
    
    @name.setter
    def name(self, value):
        if not isinstance(value, str):
            raise TypeError("名字必须是字符串")
        self._name = value
    
    @property
    def age(self):
        return self._age
    
    @age.setter
    def age(self, value):
        if not isinstance(value, int):
            raise TypeError("年龄必须是整数")
        if value < 0 or value > 150:
            raise ValueError("年龄必须在0-150之间")
        self._age = value

# 使用示例
person = Person("张三", 25)
print(person.name)  # 输出: 张三
person.age = 30     # 使用 setter
print(person.age)   # 输出: 30
```

## 3. 继承

### 3.1 基本继承

```python
class Animal:
    def __init__(self, name):
        self.name = name
    
    def speak(self):
        pass

class Dog(Animal):
    def speak(self):
        return f"{self.name}说：汪汪！"

class Cat(Animal):
    def speak(self):
        return f"{self.name}说：��喵！"

# 使用示例
dog = Dog("旺财")
cat = Cat("咪咪")
print(dog.speak())  # 输出: 旺财说：汪汪！
print(cat.speak())  # 输出: 咪咪说：喵喵！
```

### 3.2 多重继承

```python
class Flyable:
    def fly(self):
        return "我可以飞！"

class Swimmable:
    def swim(self):
        return "我可以游泳！"

class Duck(Animal, Flyable, Swimmable):
    def speak(self):
        return f"{self.name}说：嘎嘎！"

# 使用示例
duck = Duck("唐老鸭")
print(duck.speak())  # 输出: 唐老鸭说：嘎嘎！
print(duck.fly())    # 输出: 我可以飞！
print(duck.swim())   # 输出: 我可以游泳！
```

## 4. 实用示例

### 4.1 简单游戏角色

```python
class GameCharacter:
    def __init__(self, name, health=100, level=1):
        self.name = name
        self._health = health
        self._level = level
        self._experience = 0
    
    @property
    def health(self):
        return self._health
    
    def take_damage(self, damage):
        self._health = max(0, self._health - damage)
        if self._health == 0:
            print(f"{self.name} 已阵亡！")
    
    def heal(self, amount):
        self._health = min(100, self._health + amount)
    
    def gain_experience(self, amount):
        self._experience += amount
        while self._experience >= 100:
            self._level_up()
            self._experience -= 100
    
    def _level_up(self):
        self._level += 1
        print(f"{self.name} 升级了！当前等级：{self._level}")

# 使用示例
player = GameCharacter("勇者")
player.take_damage(30)
print(f"当前生命值：{player.health}")  # 输出: 当前生命值：70
player.gain_experience(150)  # 会触发升级
```

## 注意事项

1. 类名通常使用驼峰命名法（CamelCase）
2. 实例方法的第一个参数总是 self
3. 私有属性和方法以双下划线开头
4. 使用 property 装饰器来控制属性访问
5. 合理使用继承，避免过深的继承层次

## 最佳实践

1. 遵循单一职责原则，每个类只负责一个功能
2. 优先使用组合而不是继承
3. 使用属性装饰器而不是直接访问私有属性
4. 为类编写清晰的文档字符串
5. 合理使用访问控制来保护数据 