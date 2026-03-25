---
title: Python-re模块
---

# Python re 模块使用

re 模块是 Python 中用于处理正则表达式的标准库，提供了字符串模式匹配、搜索和替换等功能。

## 1. 基本语法

### 1.1 常用元字符

```python
'''
.  匹配任意字符（除了换行符）
^  匹配字符串开头
$  匹配字符串结尾
*  匹配前一个字符 0 次或多次
+  匹配前一个字符 1 次或多次
?  匹配前一个字符 0 次或 1 次
\d 匹配数字
\D 匹配非数字
\w 匹配字母数字下划线
\W 匹配非字母数字下划线
\s 匹配空白字符
\S 匹配非空白字符
'''
```

### 1.2 常用函数

```python
import re

text = "我的电话是：13912345678，邮箱是：example@gmail.com"

# match：从字符串开头匹配
result = re.match(r'我的', text)
print(result.group())  # 输出: 我的

# search：搜索整个字符串，返回第一个匹配
result = re.search(r'\d{11}', text)
print(result.group())  # 输出: 13912345678

# findall：查找所有匹配，返回列表
results = re.findall(r'[\w.]+@[\w.]+', text)
print(results)  # 输出: ['example@gmail.com']

# finditer：查找所有匹配，返回迭代器
for match in re.finditer(r'\d+', text):
    print(f'找到数字 {match.group()} 在位置 {match.span()}')
```

## 2. 高级用法

### 2.1 分组和捕获

```python
# 使用括号进行分组
pattern = r'(\d{3})-(\d{4})-(\d{4})'
text = "电话号码：021-5555-6666"
match = re.search(pattern, text)
if match:
    print(match.group(0))  # 完整匹配: 021-5555-6666
    print(match.group(1))  # 第一组: 021
    print(match.group(2))  # 第二组: 5555
    print(match.groups())  # 所有组: ('021', '5555', '6666')

# 命名分组
pattern = r'(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})'
text = "日期：2024-03-20"
match = re.search(pattern, text)
if match:
    print(match.group('year'))   # 输出: 2024
    print(match.groupdict())     # 输出: {'year': '2024', 'month': '03', 'day': '20'}
```

### 2.2 替换和分割

```python
# sub：替换字符串
text = "我的密码是123456"
result = re.sub(r'\d+', '******', text)
print(result)  # 输出: 我的密码是******

# 使用函数进行替换
def convert_date(match):
    month = int(match.group('month'))
    return f"{match.group('year')}年{month}月{match.group('day')}日"

text = "日期: 2024-03-20"
pattern = r'(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})'
result = re.sub(pattern, convert_date, text)
print(result)  # 输出: 日期: 2024年3月20日

# split：分割字符串
text = "python,java;c++|javascript"
result = re.split(r'[,;|]', text)
print(result)  # 输出: ['python', 'java', 'c++', 'javascript']
```

## 3. 常用正则表达式示例

### 3.1 数据验证

```python
# 手机号码验证
def is_valid_phone(phone):
    pattern = r'^1[3-9]\d{9}$'
    return bool(re.match(pattern, phone))

# 邮箱验证
def is_valid_email(email):
    pattern = r'^[\w\.-]+@[\w\.-]+\.\w+$'
    return bool(re.match(pattern, email))

# 密码强度验证（至少8位，包含大小写字母和数字）
def is_strong_password(password):
    pattern = r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$'
    return bool(re.match(pattern, password))

# 中国身份证号验证
def is_valid_id_card(id_card):
    pattern = r'^\d{17}[\dXx]$'
    return bool(re.match(pattern, id_card))
```

### 3.2 文本提取

```python
# 提取网页链接
def extract_urls(text):
    pattern = r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+'
    return re.findall(pattern, text)

# 提取中文内容
def extract_chinese(text):
    pattern = r'[\u4e00-\u9fa5]+'
    return re.findall(pattern, text)

# 提取 HTML 标签
def extract_tags(html):
    pattern = r'<([a-z]+).*?>'
    return re.findall(pattern, html, re.I)
```

## 4. 性能优化

### 4.1 编译正则表达式

```python
# 编译正则表达式以提高性能
phone_pattern = re.compile(r'^1[3-9]\d{9}$')

# 多次使用同一个正则表达式
def validate_phones(phone_list):
    return [phone_pattern.match(phone) is not None for phone in phone_list]
```

### 4.2 非捕获组

```python
# 使用非捕获组 (?:) 提高性能
pattern = r'(?:\d{3})-\d{8}'  # 不需要捕获区号部分
```

## 注意事项

1. 使用原始字符串（r''）避免转义字符的问题
2. 正则表达式过于复杂时考虑分拆或添加注释
3. 对于大文本处理，考虑使用 finditer 而不是 findall
4. 注意贪婪匹配和非贪婪匹配的区别（*? +? ??）
5. 编译频繁使用的正则表达式以提高性能

## 常见错误处理

```python
try:
    re.compile('[')  # 错误的正则表达式
except re.error as e:
    print(f"正则表达式错误: {e}")

# 处理可能的匹配失败
match = re.search(pattern, text)
if match:
    result = match.group()
else:
    print("未找到匹配")
``` 