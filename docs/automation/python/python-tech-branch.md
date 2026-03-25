---
title: Python-分支结构
sidebar_position: 3
---

# Python 分支结构使用指南

分支结构是程序中进行判断和选择的重要控制结构，Python 提供了灵活的分支语句。

## 1. if 语句

### 1.1 基本 if 语句

```python
# 单分支结构
age = 18
if age >= 18:
    print("已成年")    # 条件为真时执行
    print("可以进入")  # 注意缩进对齐

# if-else 双分支结构
age = 16
if age >= 18:
    print("已成年")
else:
    print("未成年")    # 条件为假时执行

# if-elif-else 多分支结构
score = 85
if score >= 90:
    print("优秀")
elif score >= 80:
    print("良好")
elif score >= 60:
    print("及格")
else:
    print("不及格")
```

### 1.2 嵌套 if 语句

```python
# if 语句的嵌套
age = 20
has_id = True

if age >= 18:
    if has_id:
        print("可以进入")
    else:
        print("需要携带证件")
else:
    print("年龄不够")

# 使用 and 可以简化嵌套
if age >= 18 and has_id:
    print("可以进入")
else:
    print("不能进入")
```

## 2. 条件表达式

### 2.1 比较运算符

```python
# 常用比较运算符
x = 10
y = 5

print(x > y)    # 大于
print(x < y)    # 小于
print(x >= y)   # 大于等于
print(x <= y)   # 小于等于
print(x == y)   # 等于
print(x != y)   # 不等于

# 链式比较
age = 24
if 18 <= age <= 30:
    print("年龄在18-30之间")
```

### 2.2 逻辑运算符

```python
# and 运算符（与）
if age >= 18 and has_id:
    print("可以进入")

# or 运算符（或）
if age < 12 or age >= 65:
    print("票价优惠")

# not 运算符（非）
if not is_closed:
    print("商店开门")

# 组合使用
if (age >= 18 and has_id) or is_vip:
    print("可以进入")
```

## 3. 条件表达式（三元运算符）

```python
# 基本语法：value_if_true if condition else value_if_false
age = 20
status = "成年" if age >= 18 else "未成年"
print(status)  # 输出: 成年

# 嵌套使用（不推荐，可读性差）
score = 85
result = "优秀" if score >= 90 else ("及格" if score >= 60 else "不及格")

# 更好的写法
if score >= 90:
    result = "优秀"
elif score >= 60:
    result = "及格"
else:
    result = "不及格"
```

## 4. 特殊用法

### 4.1 pass 语句

```python
# 使用 pass 作为占位符
if age >= 18:
    pass    # 暂时不做任何处理
else:
    print("未成年")

# 在开发时用作临时占位
def check_age():
    pass    # 待实现的函数
```

### 4.2 条件表达式的高级用法

```python
# 使用 in 进行成员检查
fruits = ['apple', 'banana', 'orange']
if 'apple' in fruits:
    print("有苹果")

# 使用 is 进行身份检查
x = None
if x is None:
    print("x 是空值")

# 使用 any 和 all
numbers = [1, 2, 3, 4, 5]
if any(num > 4 for num in numbers):
    print("存在大于4的数")
if all(num < 10 for num in numbers):
    print("所有数都小于10")
```

## 5. 实用示例

### 5.1 输入验证

```python
def validate_input():
    age = input("请输入年龄：")
    if not age.isdigit():
        print("请输入数字")
        return False
    
    age = int(age)
    if age < 0 or age > 120:
        print("年龄超出合理范围")
        return False
    
    return True
```

### 5.2 状态处理

```python
def process_order(status):
    if status == 'pending':
        return "订单待处理"
    elif status == 'processing':
        return "订单处理中"
    elif status == 'completed':
        return "订单已完成"
    elif status == 'cancelled':
        return "订单已取消"
    else:
        return "未知状态"
```

## 6. 最佳实践

### 6.1 代码风格

```python
# 推荐的写法
if condition:
    do_something()

# 不推荐的写法
if condition: do_something()  # 不要把代码写在同一行

# 对于简单条件，使用三元运算符
status = "成年" if age >= 18 else "未成年"

# 对于复杂条件，使用常规 if 语句
if age >= 18:
    if has_id:
        status = "可以进入"
    else:
        status = "需要证件"
else:
    status = "年龄不够"
```

### 6.2 性能考虑

```python
# 将最可能的条件放在前面
if common_case:    # 最常见的情况
    handle_common_case()
elif special_case:  # 特殊情况
    handle_special_case()
else:              # 异常情况
    handle_exception()

# 对于大量条件，考虑使用字典
status_dict = {
    'pending': "订单待处理",
    'processing': "订单处理中",
    'completed': "订单已完成",
    'cancelled': "订单已取消"
}
status = status_dict.get(order_status, "未知状态")
```

## 注意事项

1. 注意代码缩进，Python 使用缩进来标识代码块
2. 避免过深的嵌套，可以使用提前返回或逻辑运算符简化
3. 条件表达式要清晰易读，必要时添加括号明确优先级
4. 对于复杂的条件判断，考虑拆分为多个简单的判断
5. 使用有意义的变量名和注释说明判断逻辑

## 常见错误处理

```python
# 类型错误处理
def check_age(age):
    try:
        age = int(age)
        return age >= 18
    except ValueError:
        print("请输入有效的年龄")
        return False

# 空值处理
def process_data(data):
    if data is None:
        return "数据为空"
    if not data:  # 空列表、空字符串等
        return "数据为空集合"
    return "数据有效"
``` 