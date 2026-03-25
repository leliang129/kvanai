---
title: Python-运算符
sidebar_position: 2
---

# Python 运算符使用指南

Python 提供了丰富的运算符，用于执行各种运算操作。

## 1. 算术运算符

```python
# 基本算术运算符
a = 10
b = 3

print(a + b)    # 加法: 13
print(a - b)    # 减法: 7
print(a * b)    # 乘法: 30
print(a / b)    # 除法: 3.3333...
print(a // b)   # 整除: 3
print(a % b)    # 取余: 1
print(a ** b)   # 幂运算: 1000

# 复合赋值运算符
x = 5
x += 3         # 等同于 x = x + 3
x -= 2         # 等同于 x = x - 2
x *= 4         # 等同于 x = x * 4
x /= 2         # 等同于 x = x / 2
x //= 2        # 等同于 x = x // 2
x %= 3         # 等同于 x = x % 3
x **= 2        # 等同于 x = x ** 2
```

## 2. 比较运算符

```python
a = 10
b = 5

print(a == b)    # 等于: False
print(a != b)    # 不等于: True
print(a > b)     # 大于: True
print(a < b)     # 小于: False
print(a >= b)    # 大于等于: True
print(a <= b)    # 小于等于: False

# 链式比较
x = 5
print(1 < x < 10)    # True
print(10 > x > 1)    # True
```

## 3. 逻辑运算符

```python
# and 运算符
print(True and True)     # True
print(True and False)    # False
print(False and True)    # False
print(False and False)   # False

# or 运算符
print(True or True)      # True
print(True or False)     # True
print(False or True)     # True
print(False or False)    # False

# not 运算符
print(not True)          # False
print(not False)         # True

# 短路运算
a = 5
b = 0
result = a > 0 and b != 0    # False（b != 0 不会被执行）
result = a > 0 or b != 0     # True（b != 0 不会被执行）
```

## 4. 位运算符

```python
a = 60            # 二进制: 0011 1100
b = 13            # 二进制: 0000 1101

print(a & b)      # 按位与: 12 (0000 1100)
print(a | b)      # 按位或: 61 (0011 1101)
print(a ^ b)      # 按位异或: 49 (0011 0001)
print(~a)         # 按位取反: -61
print(a << 2)     # 左移: 240 (1111 0000)
print(a >> 2)     # 右移: 15 (0000 1111)
```

## 5. 成员运算符

```python
# in 运算符
list1 = [1, 2, 3, 4, 5]
print(3 in list1)        # True
print(6 in list1)        # False

# not in 运算符
print(3 not in list1)    # False
print(6 not in list1)    # True

# 字符串成员运算
str1 = "Hello World"
print('H' in str1)       # True
print('hello' in str1)   # False（区分大小写）
```

## 6. 身份运算符

```python
# is 运算符
a = [1, 2, 3]
b = [1, 2, 3]
c = a

print(a is b)        # False（不同对象）
print(a is c)        # True（同一对象）
print(a is not b)    # True
print(a is not c)    # False

# 特殊情况
x = 256
y = 256
print(x is y)        # True（小整数池）

m = 257
n = 257
print(m is n)        # False
```

## 7. 运算符优先级

```python
# 优先级从高到低
'''
1. ** (幂运算)
2. ~, +, - (按位取反，正号，负号)
3. *, /, //, %
4. +, -
5. >>, <<
6. &
7. ^, |
8. ==, !=, >, >=, <, <=
9. is, is not
10. in, not in
11. not
12. and
13. or
'''

# 示例
result = 2 + 3 * 4    # 14 (而不是 20)
result = (2 + 3) * 4  # 20 (使用括号改变优先级)
```

## 8. 实用示例

### 8.1 条件判断

```python
# 使用比较和逻辑运算符
age = 25
has_id = True

if age >= 18 and has_id:
    print("可以进入")
else:
    print("不能进入")

# 使用 in 运算符检查范围
score = 85
if score in range(60, 101):
    print("及格")
```

### 8.2 数值处理

```python
# 使用位运算进行标志位处理
def has_permission(user_permissions, permission):
    return user_permissions & permission != 0

# 使用算术运算符进行计算
def calculate_discount(price, discount_rate):
    return price * (1 - discount_rate)
```

## 注意事项

1. 比较浮点数时要注意精度问题
2. is 运算符用于身份比较，== 用于值比较
3. 位运算符通常用于整数
4. 逻辑运算符具有短路特性
5. 优先使用括号来明确运算优先级
6. 注意整数除法和浮点数除法的区别

## 常见错误处理

```python
# 除零错误
try:
    result = 10 / 0
except ZeroDivisionError:
    print("不能除以零")

# 类型错误
try:
    result = "123" + 456
except TypeError:
    print("不能将字符串和数字相加")
``` 