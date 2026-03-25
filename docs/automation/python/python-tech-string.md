---
title: Python-字符串
sidebar_position: 6
---

# Python 字符串使用指南

字符串是 Python 中最常用的数据类型之一，用于处理文本数据。

## 1. 字符串创建

```python
# 基本创建方式
str1 = 'Hello'
str2 = "World"
str3 = '''这是一个
多行字符串'''

# 转义字符
str4 = 'Hello\nWorld'    # \n 换行
str5 = 'Tab\t分隔'      # \t 制表符

# 原始字符串（raw string）
path = r'C:\Users\name'  # 不处理转义字符

# 字符串拼接
name = "张" + "三"       # 使用 + 号
full_name = "张" "三"    # 直接连接
```

## 2. 字符串操作

### 2.1 基本操作

```python
text = "Hello, Python!"

# 长度
print(len(text))         # 输出: 13

# 索引访问
print(text[0])          # 输出: H
print(text[-1])         # 输出: ! (从后往前)

# 切片
print(text[0:5])        # 输出: Hello
print(text[7:])         # 输出: Python!
print(text[:5])         # 输出: Hello
print(text[::2])        # 输出: Hlo yhn! (步长为2)
```

### 2.2 常用方法

```python
text = "  Hello, Python!  "

# 大小写转换
print(text.upper())      # 转大写
print(text.lower())      # 转小写
print(text.title())      # 首字母大写
print(text.capitalize()) # 句首大写

# 空白处理
print(text.strip())      # 删除两端空白
print(text.lstrip())     # 删除左侧空白
print(text.rstrip())     # 删除右侧空白

# 查找和替换
print(text.find('Python'))    # 返回位置，找不到返回-1
print(text.index('Python'))   # 返回位置，找不到抛出异常
print(text.replace('Python', 'Java'))  # 替换字符串

# 分割和连接
text = "a,b,c,d"
parts = text.split(',')       # 分割字符串
print(','.join(parts))        # 连接字符串
```

### 2.3 判断方法

```python
# 内容检查
text = "Hello123"
print(text.isalpha())    # 是否全是字母
print(text.isdigit())    # 是否全是数字
print(text.isalnum())    # 是否是字母或数字
print(text.isspace())    # 是否全是空白字符

# 开头和结尾
text = "Hello, World!"
print(text.startswith('Hello'))  # 是否以指定字符串开头
print(text.endswith('!'))        # 是否以指定字符串结尾
```

## 3. 格式化字符串

### 3.1 f-string（推荐）

```python
name = "张三"
age = 25

# 基本用法
print(f"我叫{name}，今年{age}岁")

# 表达式
print(f"明年我{age + 1}岁")

# 格式化说明符
price = 123.456
print(f"价格: {price:.2f}")  # 保留两位小数
print(f"编号: {age:03d}")    # 补零对齐
```

### 3.2 format() 方法

```python
# 位置参数
print("我叫{}，今年{}岁".format(name, age))

# 索引参数
print("{1}今年{0}岁".format(age, name))

# 命名参数
print("{name}今年{age}岁".format(name=name, age=age))

# 格式化
print("价格: {:.2f}".format(123.456))
```

### 3.3 % 运算符（旧式）

```python
# 基本用法
print("我叫%s，今年%d岁" % (name, age))

# 常用格式化符号
print("名字: %-10s" % name)     # 左对齐，占10个字符
print("价格: %.2f" % 123.456)   # 保留两位小数
print("编号: %03d" % 5)         # 数字补零
```

## 4. 实用示例

### 4.1 文本处理

```python
# 单词统计
text = "hello world hello python"
word_count = {}
for word in text.split():
    word_count[word] = word_count.get(word, 0) + 1
print(word_count)

# 清理文本
text = "  Hello,   World!  "
clean_text = " ".join(text.split())  # 删除多余空白
print(clean_text)

# 提取数字
text = "价格是123.45元"
import re
numbers = re.findall(r'\d+\.?\d*', text)
print(numbers)
```

### 4.2 字符串验证

```python
# 检查密码强度
def check_password(password):
    if len(password) < 8:
        return "密码太短"
    if not any(c.isupper() for c in password):
        return "需要包含大写字母"
    if not any(c.islower() for c in password):
        return "需要包含小写字母"
    if not any(c.isdigit() for c in password):
        return "需要包含数字"
    return "密码强度合格"

# 验证邮箱格式
def is_valid_email(email):
    import re
    pattern = r'^[\w\.-]+@[\w\.-]+\.\w+$'
    return bool(re.match(pattern, email))
```

## 注意事项

1. 字符串是不可变类型，修改操作都会创建新字符串
2. 使用 f-string 进行字符串格式化更清晰直观
3. 处理大量字符串拼接时，用 join() 而不是 +
4. 注意编码问题，特别是处理中文时
5. 字符串比较区分大小写

## 常见错误处理

```python
# 索引错误
try:
    text = "Hello"
    print(text[10])
except IndexError:
    print("索引超出范围")

# 编码错误
try:
    text = "你好".encode('ascii')
except UnicodeEncodeError:
    print("编码错误")
``` 