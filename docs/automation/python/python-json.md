---
title: Python-json模块
---

# Python json 模块使用

json 模块是 Python 中用于处理 JSON 数据的标准库，提供了 JSON 数据的编码（encoding）和解码（decoding）功能。

## 1. 基本操作

### 1.1 JSON 编码（Python 对象转 JSON）

```python
import json

# Python 字典
data = {
    "name": "张三",
    "age": 25,
    "cities": ["北京", "上海"],
    "has_car": False,
    "height": 1.75
}

# 转换为 JSON 字符串
json_str = json.dumps(data, ensure_ascii=False, indent=4)
print(json_str)

# 写入 JSON 文件
with open('data.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=4)
```

### 1.2 JSON 解码（JSON 转 Python 对象）

```python
# 从字符串解析
json_str = '{"name": "张三", "age": 25}'
data = json.loads(json_str)
print(data['name'])  # 输出: 张三

# 从文件读取
with open('data.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
print(data)
```

## 2. 高级用法

### 2.1 自定义编码

```python
from datetime import datetime

class DateTimeEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.strftime('%Y-%m-%d %H:%M:%S')
        return super().default(obj)

data = {
    "name": "张三",
    "created_at": datetime.now()
}

# 使用自定义编码器
json_str = json.dumps(data, cls=DateTimeEncoder, ensure_ascii=False)
print(json_str)
```

### 2.2 自定义解码

```python
def datetime_decoder(dict_):
    for key, value in dict_.items():
        try:
            dict_[key] = datetime.strptime(value, '%Y-%m-%d %H:%M:%S')
        except (TypeError, ValueError):
            pass
    return dict_

# 使用自定义解码器
json_str = '{"name": "张三", "created_at": "2024-03-20 10:30:00"}'
data = json.loads(json_str, object_hook=datetime_decoder)
print(type(data['created_at']))  # 输出: <class 'datetime.datetime'>
```

## 3. 常用参数说明

### 3.1 dumps/dump 参数

```python
data = {"name": "张三", "scores": [95, 87, 98]}

# indent: 缩进格式化
# 作用：设置 JSON 字符串的缩进空格数，使输出更易读
# None 表示无缩进，正整数表示缩进空格数
print(json.dumps(data, indent=2))

# ensure_ascii: 是否使用ASCII编码
# 作用：控制中文等非ASCII字符的编码方式
# False 则直接输出中文，True 则将中文转为 \uXXXX 格式
print(json.dumps(data, ensure_ascii=False))

# sort_keys: 是否对字典键排序
# 作用：按字母顺序对字典的键进行排序
# 在需要固定输出顺序时很有用
print(json.dumps(data, sort_keys=True))

# separators: 自定义分隔符
# 作用：自定义项目分隔符和键值对分隔符
# 默认为 (', ', ': ')，常用 (',',':') 来压缩 JSON
print(json.dumps(data, separators=(',', ':')))  # 压缩格式

# default: 自定义序列化函数
# 作用：处理默认 JSON 编码器无法处理的 Python 对象
def datetime_handler(obj):
    if isinstance(obj, datetime):
        return obj.isoformat()
    return obj

data_with_date = {"time": datetime.now()}
print(json.dumps(data_with_date, default=datetime_handler))
```

dumps 和 dump 的主要区别：
1. `dumps`：将 Python 对象转换为 JSON 字符串
2. `dump`：将 Python 对象转换为 JSON 字符串并写入文件

使用示例：
```python
# dumps：返回 JSON 字符串
json_str = json.dumps(data, ensure_ascii=False)
print(type(json_str))  # 输出: <class 'str'>

# dump：直接写入文件
with open('output.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
```

### 3.2 loads/load 参数

```python
# parse_float: 自定义浮点数解析方式
# 作用：将 JSON 中的浮点数转换为指定的类型，比如 Decimal 用于高精度计算
json_str = '{"value": 3.14}'
data = json.loads(json_str, parse_float=decimal.Decimal)
print(type(data['value']))  # 输出: <class 'decimal.Decimal'>

# parse_int: 自定义整数解析方式
# 作用：自定义 JSON 中整数的解析方式，可以在解析时进行数值转换
json_str = '{"count": 100}'
data = json.loads(json_str, parse_int=lambda x: x * 2)
print(data['count'])  # 输出: 200

# object_hook: 自定义对象解析方式
# 作用：在解析 JSON 对象时进行自定义处理，常用于将特定格式的数据转换为 Python 对象
def custom_decoder(dct):
    if 'date' in dct:
        dct['date'] = datetime.strptime(dct['date'], '%Y-%m-%d')
    return dct

json_str = '{"date": "2024-03-20", "name": "张三"}'
data = json.loads(json_str, object_hook=custom_decoder)
print(type(data['date']))  # 输出: <class 'datetime.datetime'>
```

## 4. 实用示例

### 4.1 合并 JSON 文件

```python
def merge_json_files(file_list, output_file):
    result = []
    for file_name in file_list:
        with open(file_name, 'r', encoding='utf-8') as f:
            data = json.load(f)
            result.extend(data if isinstance(data, list) else [data])
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=4)

# 使用示例
files = ['data1.json', 'data2.json', 'data3.json']
merge_json_files(files, 'merged.json')
```

### 4.2 JSON 数据验证

```python
def validate_json(json_str, required_fields):
    try:
        data = json.loads(json_str)
        for field in required_fields:
            if field not in data:
                return False, f"缺少必需字段: {field}"
        return True, "验证通过"
    except json.JSONDecodeError as e:
        return False, f"JSON 格式错误: {str(e)}"

# 使用示例
json_str = '{"name": "张三", "age": 25}'
required = ['name', 'age', 'email']
is_valid, message = validate_json(json_str, required)
print(message)  # 输出: 缺少必需字段: email
```

## 注意事项

1. `dumps` 和 `loads` 用于字符串操作，`dump` 和 `load` 用于文件操作
2. 处理中文时建议设置 `ensure_ascii=False`
3. JSON 中的数据类型有限，复杂的 Python 对象需要自定义编码器
4. 处理大型 JSON 文件时要注意内存使用
5. 文件操作时要注意指定正确的字符编码

## 常见错误处理

```python
try:
    data = json.loads('{"name": "张三", age: 25}')  # 格式错误的 JSON
except json.JSONDecodeError as e:
    print(f"JSON 解析错误: {e}")

try:
    with open('non_existent.json', 'r') as f:
        data = json.load(f)
except FileNotFoundError:
    print("文件不存在")
``` 