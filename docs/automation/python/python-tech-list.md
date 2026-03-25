---
title: Python-列表
sidebar_position: 7
---

# Python 列表使用指南

列表是 Python 中最常用的数据结构之一，可以存储任意类型的数据序列。

## 1. 列表创建

```python
# 基本创建方式
list1 = [1, 2, 3, 4, 5]
list2 = ['apple', 'banana', 'orange']
list3 = [1, 'hello', True, 3.14]  # 可以包含不同类型的元素

# 使用 list() 函数创建
list4 = list('Hello')  # 将字符串转换为列表
print(list4)  # 输出: ['H', 'e', 'l', 'l', 'o']

# 列表推导式创建
squares = [x**2 for x in range(5)]  # [0, 1, 4, 9, 16]

# 创建空列表
empty_list1 = []
empty_list2 = list()
```

## 2. 列表操作

### 2.1 访问元素

```python
fruits = ['apple', 'banana', 'orange', 'grape']

# 索引访问
print(fruits[0])     # 第一个元素: apple
print(fruits[-1])    # 最后一个元素: grape

# 切片操作
print(fruits[1:3])   # ['banana', 'orange']
print(fruits[:2])    # ['apple', 'banana']
print(fruits[2:])    # ['orange', 'grape']
print(fruits[::2])   # ['apple', 'orange']
```

### 2.2 修改元素

```python
numbers = [1, 2, 3, 4, 5]

# 修改单个元素
numbers[0] = 10

# 修改多个元素（切片赋值）
numbers[1:4] = [20, 30, 40]

# 插入元素
numbers.insert(2, 25)  # 在索引2处插入25

# 追加元素
numbers.append(6)      # 在末尾添加元素
numbers.extend([7, 8]) # 扩展列表

# 删除元素
del numbers[0]        # 删除指定索引的元素
numbers.remove(5)     # 删除第一个值为5的元素
last = numbers.pop()  # 删除并返回最后一个元素
numbers.pop(1)        # 删除并返回指定索引的元素
```

### 2.3 列表方法

```python
fruits = ['apple', 'banana', 'orange']

# 添加元素
fruits.append('grape')       # 在末尾添加元素
fruits.insert(1, 'mango')   # 在指定位置插入元素
fruits.extend(['pear', 'kiwi'])  # 扩展列表

# 删除元素
fruits.remove('banana')      # 删除指定元素
fruits.pop()                # 删除并返回最后一个元素
fruits.clear()              # 清空列表

# 查找元素
index = fruits.index('apple')  # 获取元素索引
count = fruits.count('apple')  # 统计元素出现次数

# 排序
fruits.sort()                # 升序排序
fruits.sort(reverse=True)    # 降序排序
fruits.reverse()            # 反转列表
```

## 3. 列表操作符

```python
# 连接操作
list1 = [1, 2, 3]
list2 = [4, 5, 6]
combined = list1 + list2    # [1, 2, 3, 4, 5, 6]

# 重复操作
repeated = list1 * 3        # [1, 2, 3, 1, 2, 3, 1, 2, 3]

# 成员检测
print(1 in list1)          # True
print(4 not in list1)      # True

# 比较操作
print([1, 2] < [2, 1])     # True
print([1, 2] == [1, 2])    # True
```

## 4. 列表推导式

```python
# 基本列表推导式
squares = [x**2 for x in range(5)]

# 带条件的列表推导式
even_squares = [x**2 for x in range(10) if x % 2 == 0]

# 多重循环的列表推导式
matrix = [[i+j for j in range(3)] for i in range(3)]

# 带if-else的列表推导式
numbers = [x if x > 0 else 0 for x in [-2, -1, 0, 1, 2]]
```

## 5. 实用示例

### 5.1 列表过滤

```python
# 过滤列表中的负数
numbers = [-4, -2, 0, 2, 4]
positive = [num for num in numbers if num > 0]

# 过滤列表中的空字符串
words = ['', 'hello', '', 'world', '  ']
non_empty = [word for word in words if word.strip()]

# 使用filter函数
def is_positive(num):
    return num > 0
positive = list(filter(is_positive, numbers))
```

### 5.2 列表转换

```python
# 字符串列表转整数列表
str_nums = ['1', '2', '3', '4']
int_nums = [int(num) for num in str_nums]

# 列表元素类型转换
mixed = [1, '2', 3, '4']
numbers = [int(x) if isinstance(x, str) else x for x in mixed]

# 展平嵌套列表
nested = [[1, 2], [3, 4], [5, 6]]
flattened = [num for sublist in nested for num in sublist]
```

## 注意事项

1. 列表是可变类型，修改会影响原列表
2. 使用切片创建副本避免意外修改
3. 列表推导式要保持简洁，过于复杂时使用循环
4. 注意列表的内存使用，特别是处理大量数据时
5. 适当使用生成器表达式代替列表推导式节省内存

## 常见错误处理

```python
# 索引错误处理
try:
    numbers = [1, 2, 3]
    print(numbers[5])
except IndexError:
    print("索引超出范围")

# 类型错误处理
try:
    mixed = [1, '2', 'three']
    result = sum(mixed)
except TypeError:
    print("列表包含不可相加的类型")
``` 