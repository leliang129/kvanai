---
title: Python-集合
sidebar_position: 9
---

# Python 集合使用指南

集合是 Python 中的一种无序、不重复的数据类型，主要用于成员检测和去重操作。

## 1. 集合创建

```python
# 使用花括号创建
set1 = {1, 2, 3, 4, 5}
set2 = {'apple', 'banana', 'orange'}

# 使用 set() 函数创建
set3 = set([1, 2, 2, 3, 3, 4])  # 自动去重
print(set3)  # 输出: {1, 2, 3, 4}

# 从字符串创建
set4 = set('hello')  # 自动去重
print(set4)  # 输出: {'h', 'e', 'l', 'o'}

# 创建空集合
empty_set = set()  # 注意：{} 创建的是空字典
```

## 2. 集合操作

### 2.1 添加和删除元素

```python
numbers = {1, 2, 3}

# 添加元素
numbers.add(4)        # 添加单个元素
numbers.update([5, 6])  # 添加多个元素

# 删除元素
numbers.remove(2)     # 删除指定元素（元素不存在会报错）
numbers.discard(10)   # 删除指定元素（元素不存在不会报错）
numbers.pop()         # 随机删除并返回一个元素
numbers.clear()       # 清空集合
```

### 2.2 集合运算

```python
set1 = {1, 2, 3, 4}
set2 = {3, 4, 5, 6}

# 并集
union1 = set1 | set2
union2 = set1.union(set2)
print(union1)  # 输出: {1, 2, 3, 4, 5, 6}

# 交集
intersection1 = set1 & set2
intersection2 = set1.intersection(set2)
print(intersection1)  # 输出: {3, 4}

# 差集
difference1 = set1 - set2
difference2 = set1.difference(set2)
print(difference1)  # 输出: {1, 2}

# 对称差集（并集减去交集）
sym_diff1 = set1 ^ set2
sym_diff2 = set1.symmetric_difference(set2)
print(sym_diff1)  # 输出: {1, 2, 5, 6}
```

## 3. 集合关系判断

```python
set1 = {1, 2, 3}
set2 = {1, 2, 3, 4, 5}
set3 = {1, 2, 6}

# 子集判断
print(set1 <= set2)  # True: set1 是 set2 的子集
print(set1.issubset(set2))  # 同上

# 超集判断
print(set2 >= set1)  # True: set2 是 set1 的超集
print(set2.issuperset(set1))  # 同上

# 相等判断
print(set1 == {3, 2, 1})  # True: 集合相等与顺序无关

# 不相交判断
print(set1.isdisjoint(set3))  # False: 有共同元素
```

## 4. 集合推导式

```python
# 基本集合推导式
squares = {x**2 for x in range(5)}
print(squares)  # 输出: {0, 1, 4, 9, 16}

# 带条件的集合推导式
even_squares = {x**2 for x in range(10) if x % 2 == 0}
print(even_squares)  # 输出: {0, 4, 16, 36, 64}

# 多重条件
numbers = {x for x in range(20) if x % 2 == 0 if x % 3 == 0}
print(numbers)  # 输出: {0, 6, 12, 18}
```

## 5. 实用示例

### 5.1 去重操作

```python
# 列表去重
numbers = [1, 2, 2, 3, 3, 3, 4, 4, 5]
unique_numbers = list(set(numbers))
print(unique_numbers)  # 输出: [1, 2, 3, 4, 5]

# 字符串去重
text = "hello world"
unique_chars = ''.join(set(text))
print(unique_chars)  # 输出: "helo wrd"

# 保持原顺序的去重
from dict.fromkeys import dict
numbers = [1, 2, 2, 3, 3, 3, 4, 4, 5]
unique_ordered = list(dict.fromkeys(numbers))
```

### 5.2 集合运算应用

```python
# 共同好友查找
user1_friends = {'Alice', 'Bob', 'Charlie'}
user2_friends = {'Bob', 'Charlie', 'David'}

# 共同好友
common_friends = user1_friends & user2_friends
print(common_friends)  # 输出: {'Bob', 'Charlie'}

# 推荐好友（user2的好友中不是user1的好友）
recommended = user2_friends - user1_friends
print(recommended)  # 输出: {'David'}
```

## 6. 性能考虑

```python
# 成员检测性能比较
large_list = list(range(10000))
large_set = set(range(10000))

# 列表查找（较慢）
%timeit 9999 in large_list

# 集合查找（较快）
%timeit 9999 in large_set

# 集合运算性能
set1 = set(range(1000))
set2 = set(range(500, 1500))

# 快速判断是否有交集
has_common = not set1.isdisjoint(set2)
```

## 注意事项

1. 集合元��必须是可哈希的（不可变类型）
2. 集合是无序的，不支持索引访问
3. 集合元素不能重复
4. 空集合必须用 set() 创建，{} 创建的是空字典
5. 集合运算比循环判断更高效

## 常见错误处理

```python
# 添加不可哈希类型
try:
    s = {1, [2, 3]}  # 列表不可哈希
except TypeError:
    print("集合元素必须是可哈希的")

# 删除不存在的元素
try:
    s = {1, 2, 3}
    s.remove(4)
except KeyError:
    print("元素不存在")
    s.discard(4)  # 使用 discard 代替 remove
``` 