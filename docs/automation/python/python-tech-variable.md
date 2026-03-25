---
title: Python-变量基础
sidebar_position: 1
---

# Python 变量使用

变量是编程中用于存储数据的基本单位，Python 中的变量使用非常灵活，无需提前声明类型。

## 1. 变量的基本概念

### 1.1 变量定义和赋值

```python
# 基本赋值
name = "张三"      # 字符串
age = 25          # 整数
height = 1.75     # 浮点数
is_student = True # 布尔值

# 多重赋值
a = b = c = 1     # 多个变量赋相同的值
x, y, z = 1, 2, 3 # 多个变量同时赋不同的值

# 交换变量值
a, b = b, a       # Python特有的交换方式
```

### 1.2 变量命名规则

```python
# 正确的命名方式
name = "张三"          # 字母开头
_name = "张三"         # 下划线开头
first_name = "张"     # 下划线连接
firstName = "张"      # 驼峰命名
NAME = "张三"         # 全大写（通常用于常量）
name2 = "张三"        # 可以包含数字

# 错误的命名方式
# 2name = "张三"      # 不能数字开头
# first-name = "张"   # 不能包含连字符
# first name = "张"   # 不能包含空格
# class = "一班"      # 不能使用关键字
```

## 2. 变量类型

### 2.1 基本数据类型

```python
# 数字类型
integer = 100             # 整数
float_num = 3.14         # 浮点数
complex_num = 1 + 2j     # 复数

# 字符串类型
string = "Hello World"    # 字符串
multi_line = """
多行
字符串
"""                      # 多行字符串

# 布尔类型
is_valid = True          # 布尔值
is_empty = False

# 空值
none_value = None        # 空值
```

### 2.2 类型转换

```python
# 字符串转数字
str_num = "123"
num1 = int(str_num)      # 转换为整数
num2 = float(str_num)    # 转换为浮点数

# 数字转字符串
num = 123
str_num = str(num)       # 转换为字符串

# 其他类型转布尔值
bool(0)      # False
bool("")     # False
bool(None)   # False
bool([])     # False
bool(1)      # True
bool("text") # True
```

## 3. 变量作用域

### 3.1 作用域类型

```python
# 全局变量
global_var = "全局变量"

def function():
    # 局部变量
    local_var = "局部变量"
    print(global_var)    # 可以访问全局变量
    print(local_var)     # 可以访问局部变量

# print(local_var)      # 错误：不能访问局部变量

# 使用全局变量
def modify_global():
    global global_var    # 声明使用全局变量
    global_var = "修改后的全局变量"
```

### 3.2 变量生命周期

```python
def function():
    # 局部变量在函数调用时创建，函数结束时销毁
    x = 100
    print(x)

# 每次调用函数都会创建新的局部变量
function()  # x 创建并打印
# 此时 x 已经销毁
```

## 4. 变量的内存管理

### 4.1 变量引用

```python
# 变量引用相同对象
a = [1, 2, 3]
b = a           # b 引用同一个列表
b.append(4)     # 修改会影响 a
print(a)        # 输出: [1, 2, 3, 4]

# 创建新的副本
c = a.copy()    # c 是新的列表
c.append(5)     # 修改不会影响 a
print(a)        # 输出: [1, 2, 3, 4]
```

### 4.2 可变与不可变类型

```python
# 不可变类型（数字、字符串、元组）
x = 1
y = x       # y 获得 x 的值的副本
y = 2       # 不会影响 x
print(x)    # 输出: 1

# 可变类型（列表、字典、集合）
list1 = [1, 2]
list2 = list1  # list2 引用同一个列表
list2.append(3) # 会影响 list1
print(list1)   # 输出: [1, 2, 3]
```

## 5. 最佳实践

### 5.1 命名约定

```python
# 变量命名约定
user_name = "张三"        # 普通变量使用小写加下划线
PI = 3.14159             # 常量使用全大写
_internal_var = "内部"    # 内部变量使用下划线开头
```

### 5.2 代码风格

```python
# 推荐的赋值方式
name = "张三"             # 等号两边各留一个空格
age, height = 25, 1.75   # 逗号后面加空格

# 不推荐的方式
name="张三"               # 等号两边没有空格
age,height=25,1.75       # 逗号后面没有空格
```

## 注意事项

1. 变量名区分大小写（name 和 Name 是不同的变量）
2. 避免使用 Python 关键字作为变量名
3. 变量名应该有描述性，避免使用单字母（除非是临时变量）
4. 常量通常使用全大写命名，但 Python 中没有真正的常量
5. 注意可变类型和不可变类型的区别
6. 谨慎使用全局变量

## 常见错误处理

```python
# 未定义变量
try:
    print(undefined_var)
except NameError as e:
    print("变量未定义")

# 类型错误
try:
    num = "123" + 456
except TypeError as e:
    print("类型不匹配")
``` 