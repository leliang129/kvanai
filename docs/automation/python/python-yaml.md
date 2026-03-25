---
title: Python-yaml模块
---

# Python yaml 模块使用

yaml 模块是 Python 中用于处理 YAML 数据的库，提供了 YAML 格式数据的读写功能。YAML 是一种人类友好的数据序列化格式。

## 安装

```bash
# 使用 pip 安装
pip install pyyaml
```

## 1. 基本操作

### 1.1 读取 YAML

```python
import yaml

# 从字符串读取
yaml_str = """
name: 张三
age: 25
skills:
  - Python
  - Java
  - Docker
address:
  city: 北京
  street: 朝阳区
"""

# 解析 YAML 字符串
data = yaml.safe_load(yaml_str)
print(data['name'])      # 输出: 张三
print(data['skills'])    # 输出: ['Python', 'Java', 'Docker']

# 从文件读取
with open('config.yaml', 'r', encoding='utf-8') as f:
    data = yaml.safe_load(f)
```

### 1.2 写入 YAML

```python
# Python 数据
data = {
    'name': '张三',
    'age': 25,
    'skills': ['Python', 'Java', 'Docker'],
    'address': {
        'city': '北京',
        'street': '朝阳区'
    }
}

# 转换为 YAML 字符串
yaml_str = yaml.dump(data, allow_unicode=True)
print(yaml_str)

# 写入文件
with open('output.yaml', 'w', encoding='utf-8') as f:
    yaml.dump(data, f, allow_unicode=True)
```

## 2. 高级特性

### 2.1 多文档处理

```python
# 多个 YAML 文档（用 --- 分隔）
yaml_str = """
---
name: 文档1
value: 100
---
name: 文档2
value: 200
"""

# 读取多个文档
documents = yaml.safe_load_all(yaml_str)
for doc in documents:
    print(doc['name'], doc['value'])

# 写入多个文档
docs = [
    {'name': '文档1', 'value': 100},
    {'name': '文档2', 'value': 200}
]
with open('multi_docs.yaml', 'w', encoding='utf-8') as f:
    yaml.dump_all(docs, f, allow_unicode=True)
```

### 2.2 自定义标签

```python
# 定义自定义标签处理器
class DateTimeLoader(yaml.SafeLoader):
    pass

def datetime_constructor(loader, node):
    value = loader.construct_scalar(node)
    return datetime.strptime(value, '%Y-%m-%d %H:%M:%S')

DateTimeLoader.add_constructor('!datetime', datetime_constructor)

# 使用自定义标签
yaml_str = """
meeting_time: !datetime 2024-03-20 14:30:00
"""

data = yaml.load(yaml_str, Loader=DateTimeLoader)
print(type(data['meeting_time']))  # 输出: <class 'datetime.datetime'>
```

## 3. 常用参数

### 3.1 dump 参数

```python
data = {'name': '张三', 'age': 25}

# default_flow_style: 控制集合的显示风格
print(yaml.dump(data, default_flow_style=False))  # 块状风格
print(yaml.dump(data, default_flow_style=True))   # 流式风格

# allow_unicode: 允许 Unicode 字符
print(yaml.dump(data, allow_unicode=True))  # 直接输出中文

# indent: 设置缩进
print(yaml.dump(data, indent=4))  # 4空格缩进

# sort_keys: 排序键
print(yaml.dump(data, sort_keys=True))  # 按字母顺序排序键
```

### 3.2 load 参数

```python
# Loader 选择
# safe_load: 安全加载，推荐使用
data = yaml.safe_load(yaml_str)  

# full_load: 完整加载，支持所有标签
data = yaml.full_load(yaml_str)  

# 使用指定的 Loader
data = yaml.load(yaml_str, Loader=yaml.SafeLoader)
```

## 4. 实用示例

### 4.1 配置文件处理

```python
# config.yaml
"""
database:
  host: localhost
  port: 5432
  user: admin
  password: secret

logging:
  level: INFO
  file: app.log

features:
  cache: true
  debug: false
"""

def load_config(config_file):
    with open(config_file, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

# 使用配置
config = load_config('config.yaml')
db_host = config['database']['host']
log_level = config['logging']['level']
```

### 4.2 数据导出

```python
def export_data(data, output_file):
    """将数据导出为 YAML 格式"""
    with open(output_file, 'w', encoding='utf-8') as f:
        yaml.dump(data, f, 
                 allow_unicode=True,    # ��持中文
                 default_flow_style=False,  # 使用块状风格
                 sort_keys=False,       # 保持键的顺序
                 indent=2)             # 2空格缩进

# 使用示例
data = {
    'users': [
        {'name': '张三', 'age': 25},
        {'name': '李四', 'age': 30}
    ],
    'settings': {
        'theme': 'dark',
        'language': 'zh-CN'
    }
}
export_data(data, 'output.yaml')
```

## 注意事项

1. 优先使用 `safe_load` 而不是 `load`，避免安全问题
2. 处理中文时记得设置 `allow_unicode=True`
3. YAML 对缩进敏感，需要保持一致的缩进风格
4. 大文件处理时注意内存使用
5. 避免在 YAML 中存储敏感信息

## 常见错误处理

```python
try:
    data = yaml.safe_load(yaml_str)
except yaml.YAMLError as e:
    print(f"YAML 解析错误: {e}")

try:
    with open('config.yaml', 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)
except FileNotFoundError:
    print("配置文件不存在")
except yaml.YAMLError as e:
    print(f"配置文件格式错误: {e}")
``` 