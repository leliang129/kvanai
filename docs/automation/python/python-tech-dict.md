---
title: Python-字典
sidebar_position: 10
---

# Python 字典使用指南

字典是 Python 中的可变映射类型，以键值对的形式存储数据。

## 1. 字典创建

```python
# 使用花括号创建
dict1 = {'name': '张三', 'age': 25}
dict2 = {'a': 1, 'b': 2, 'c': 3}

# 使用 dict() 函数创建
dict3 = dict(name='李四', age=30)
dict4 = dict([('a', 1), ('b', 2)])  # 从序列创建

# 使用字典推导式创建
dict5 = {x: x**2 for x in range(5)}
print(dict5)  # 输出: {0: 0, 1: 1, 2: 4, 3: 9, 4: 16}

# 创建空字典
empty_dict1 = {}
empty_dict2 = dict()
```

## 2. 字典操作

### 2.1 访问元素

```python
student = {'name': '张三', 'age': 25, 'city': '北京'}

# 使用键访问
print(student['name'])     # 输出: 张三

# 使用 get() 方法（推荐）
print(student.get('age'))  # 输出: 25
print(student.get('score', 0))  # 键不存在时返回默认值

# 获取所有键、值、键值对
print(student.keys())      # 获取所有键
print(student.values())    # 获取所有值
print(student.items())     # 获取所有键值对
```

### 2.2 修改和添加元素

```python
student = {'name': '张三', 'age': 25}

# 添加/修改单个元素
student['city'] = '北京'    # 添加新键值对
student['age'] = 26        # 修改已存在的值

# 批量更新
student.update({'score': 90, 'grade': 'A'})

# 设置默认值
student.setdefault('gender', '男')  # 如果键不存在则设置默认值
```

### 2.3 删除元素

```python
student = {'name': '张三', 'age': 25, 'city': '北京'}

# 删除指定键值对
del student['age']         # 使用 del 语句
city = student.pop('city') # 删除并返回值
last = student.popitem()   # 删除并返回最后一个键值对

# 清空字典
student.clear()            # 删除所有元素
```

## 3. 字典方法

### 3.1 常用方法

```python
student = {'name': '张三', 'age': 25}

# 复制字典
student_copy = student.copy()    # 浅拷贝
import copy
student_deep = copy.deepcopy(student)  # 深拷贝

# 合并字典
dict1 = {'a': 1, 'b': 2}
dict2 = {'c': 3, 'd': 4}
dict1.update(dict2)       # 将 dict2 合并到 dict1

# 检查键是否存在
print('name' in student)  # 使用 in 运算符
```

### 3.2 视图对象

```python
student = {'name': '张三', 'age': 25}

# 获取视图对象
keys = student.keys()      # 键视图
values = student.values()  # 值视图
items = student.items()    # 键值���视图

# 视图会随字典变化而变化
student['city'] = '北京'
print(keys)    # 包含新添加的键
```

## 4. 字典推导式

```python
# 基本字典推导式
squares = {x: x**2 for x in range(5)}

# 带条件的字典推导式
even_squares = {x: x**2 for x in range(10) if x % 2 == 0}

# 从两个列表创建字典
names = ['张三', '李四', '王五']
ages = [25, 30, 35]
name_age = {name: age for name, age in zip(names, ages)}

# 键值转换
dict1 = {'a': 1, 'b': 2, 'c': 3}
dict2 = {v: k for k, v in dict1.items()}  # 键值互换
```

## 5. 实用示例

### 5.1 数据统计

```python
# 词频统计
text = "hello world hello python hello world"
word_count = {}
for word in text.split():
    word_count[word] = word_count.get(word, 0) + 1
print(word_count)

# 分组统计
students = [
    {'name': '张三', 'class': '一班'},
    {'name': '李四', 'class': '二班'},
    {'name': '王五', 'class': '一班'}
]
class_students = {}
for student in students:
    class_name = student['class']
    class_students.setdefault(class_name, []).append(student['name'])
```

### 5.2 缓存实现

```python
# 简单的缓存装饰器
def cache_decorator(func):
    cache = {}
    def wrapper(*args):
        if args in cache:
            return cache[args]
        result = func(*args)
        cache[args] = result
        return result
    return wrapper

@cache_decorator
def fibonacci(n):
    if n < 2:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```

## 6. 性能考虑

```python
# 使用 dict.get() 而不是异常处理
# 好的方式
value = my_dict.get('key', default_value)

# 避免的方式
try:
    value = my_dict['key']
except KeyError:
    value = default_value

# 合并字典的高效方式
# Python 3.5+
dict3 = {**dict1, **dict2}

# 检查多个键
required_keys = {'name', 'age', 'city'}
has_all_keys = required_keys.issubset(student.keys())
```

## 注意事项

1. 字典键必须是可哈希的（不可变类型）
2. 字典是无序的（Python 3.7+ 保持插入顺序）
3. 使用 get() 方法避免键不存在时的异常
4. 注意深浅拷贝的区别
5. 字典推导式要保持简洁易读

## 常见错误处理

```python
# 键错误处理
try:
    value = student['score']  # 访问不存在的键
except KeyError:
    print("键不存在")

# 类型错误处理
try:
    d = {[1, 2]: 'value'}  # 使用不可哈希类型作为键
except TypeError:
    print("键必须是可哈希的")
``` 