---
title: Python-循环结构
sidebar_position: 4
---

# Python 循环结构使用指南

循环结构是程序中进行重复操作的重要控制结构，Python 提供了 for 和 while 两种循环语句。

## 1. for 循环

### 1.1 基本用法

```python
# 遍历列表
fruits = ['apple', 'banana', 'orange']
for fruit in fruits:
    print(fruit)

# 遍历字符串
for char in "Python":
    print(char)

# 使用 range()
for i in range(5):    # 0 到 4
    print(i)

for i in range(2, 5): # 2 到 4
    print(i)

for i in range(0, 10, 2): # 0,2,4,6,8 (步长为2)
    print(i)
```

### 1.2 高级用法

```python
# enumerate() 同时获取索引和值
fruits = ['apple', 'banana', 'orange']
for index, fruit in enumerate(fruits):
    print(f"索引 {index}: {fruit}")

# zip() 同时遍历多个序列
names = ['张三', '李四', '王五']
ages = [20, 25, 30]
for name, age in zip(names, ages):
    print(f"{name} 今年 {age} 岁")

# 字典遍历
student = {'name': '张三', 'age': 20, 'city': '北京'}
for key in student:           # 遍历键
    print(key)
for value in student.values(): # 遍历值
    print(value)
for key, value in student.items(): # 遍历键值对
    print(f"{key}: {value}")
```

### 1.3 range 详解

```python
# range() 函数的三种用法

# 1. range(stop)：从0开始，步长为1
for i in range(5):
    print(i)  # 输出: 0, 1, 2, 3, 4

# 2. range(start, stop)：指定起始值和结束值
for i in range(2, 6):
    print(i)  # 输出: 2, 3, 4, 5

# 3. range(start, stop, step)：指定起始值、结束值和步长
for i in range(1, 10, 2):
    print(i)  # 输出: 1, 3, 5, 7, 9

# 负步长：倒序遍历
for i in range(10, 0, -1):
    print(i)  # 输出: 10, 9, 8, 7, 6, 5, 4, 3, 2, 1

# 常见应用场景
# 1. 遍历列表索引
fruits = ['apple', 'banana', 'orange']
for i in range(len(fruits)):
    print(f"索引 {i}: {fruits[i]}")

# 2. 生成数字序列
even_numbers = list(range(0, 11, 2))  # [0, 2, 4, 6, 8, 10]

# 3. 指定循环次数
for _ in range(3):  # 当不需要使用索引值时，可用_代替
    print("重复三次")
```

## 2. while 循环

### 2.1 基本用法

```python
# 基本 while 循环
count = 0
while count < 5:
    print(count)
    count += 1

# 无限循环
while True:
    user_input = input("请输入(q退出)：")
    if user_input == 'q':
        break
    print(f"你输入了：{user_input}")
```

### 2.2 条件控制

```python
# break 语句：跳出循环
for i in range(5):
    if i == 3:
        break
    print(i)  # 输出 0,1,2

# continue 语句：跳过当前迭代
for i in range(5):
    if i == 3:
        continue
    print(i)  # 输出 0,1,2,4

# else 子句：循环正常完成时执行
for i in range(3):
    print(i)
else:
    print("循环正常结束")  # 循环没有被 break 时执行
```

## 3. 循环技巧

### 3.1 列表推导式

```python
# 基本列表推导式
squares = [x**2 for x in range(5)]  # [0, 1, 4, 9, 16]

# 带条件的列表推导式
even_squares = [x**2 for x in range(10) if x % 2 == 0]  # [0, 4, 16, 36, 64]

# 嵌套循环的列表推导式
matrix = [[i+j for j in range(3)] for i in range(3)]
# [[0,1,2], [1,2,3], [2,3,4]]

# 字典推导式
squares_dict = {x: x**2 for x in range(5)}
# {0: 0, 1: 1, 2: 4, 3: 9, 4: 16}

# 集合推导式
squares_set = {x**2 for x in range(5)}
# {0, 1, 4, 9, 16}
```

### 3.2 生成器表达式

```python
# 生成器表达式（节省内存）
squares_gen = (x**2 for x in range(5))
for square in squares_gen:
    print(square)

# 生成器函数
def fibonacci(n):
    a, b = 0, 1
    for _ in range(n):
        yield a
        a, b = b, a + b

for num in fibonacci(5):
    print(num)  # 输出斐波那契数列前5个数
```

## 4. 实用示例

### 4.1 嵌套循环

```python
# 打印乘法表
for i in range(1, 10):
    for j in range(1, i+1):
        print(f"{j}×{i}={i*j}", end='\t')
    print()  # 换行

# 遍历二维列表
matrix = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
]
for row in matrix:
    for num in row:
        print(num, end=' ')
    print()
```

### 4.2 循环应用

```python
def find_prime_numbers(n):
    """找出n以内的所有质数"""
    primes = []
    for num in range(2, n + 1):
        for i in range(2, int(num ** 0.5) + 1):
            if num % i == 0:
                break
        else:
            primes.append(num)
    return primes

# 冒泡排序
def bubble_sort(arr):
    n = len(arr)
    for i in range(n):
        for j in range(0, n-i-1):
            if arr[j] > arr[j+1]:
                arr[j], arr[j+1] = arr[j+1], arr[j]
    return arr
```

## 5. 性能优化

### 5.1 循环优化技巧

```python
# 在循环外定义变量
size = len(array)  # 避免在循环中重复计算
for i in range(size):
    # 处理数组

# 使用 join 而不是 += 连接字符串
parts = []
for item in items:
    parts.append(str(item))
result = ''.join(parts)  # 比循环中使用 += 更高效

# 使用生成器处理大数据
def process_large_file(filename):
    with open(filename) as f:
        for line in f:  # 逐行读取，节省内存
            yield line.strip()
```

### 5.2 避免常见陷阱

```python
# 避免在循环中修改列表
# 错误方式
items = [1, 2, 3, 4, 5]
for item in items:
    if item % 2 == 0:
        items.remove(item)  # 可能跳过元素

# 正确方式
items = [item for item in items if item % 2 != 0]

# 避免在循环中频繁分配内存
# 错误方式
result = ''
for item in items:
    result += str(item)  # 每次都创建新字符串

# 正确方式
result = ''.join(str(item) for item in items)
```

## 注意事项

1. 选择合适的循环类型（for 用于已知迭代次数，while 用于条件控制）
2. 注意循环的终止条件，避免无限循环
3. 合理使用 break 和 continue
4. 列表推导式要保持简洁，过于复杂时应使用常规循环
5. 处理大数据时考虑使用生成器
6. 避免在循环中修改正在迭代的序列

## 常见错误处理

```python
# 处理可能的异常
try:
    for i in range(5):
        result = 10 / (2 - i)  # 可能发生除零错误
        print(result)
except ZeroDivisionError:
    print("除数不能为零")

# 循环中的类型错误
try:
    numbers = [1, '2', 3, 'four', 5]
    for num in numbers:
        print(int(num))
except ValueError:
    print("无法转换为整数")
``` 