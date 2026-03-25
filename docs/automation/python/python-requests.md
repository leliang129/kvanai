---
title: Python-requests模块
---

# Python requests 模块使用

requests 是 Python 中最常用的 HTTP 请求库，提供了简单而优雅的接口来发送 HTTP/1.1 请求。

## 1. 基本请求方法

### 1.1 GET 请求

```python
import requests

# 简单的 GET 请求
response = requests.get('https://api.example.com/items')
print(response.status_code)  # 输出: 200
print(response.text)        # 输出: 响应内容

# 带参数的 GET 请求
params = {
    'key1': 'value1',
    'key2': 'value2'
}
response = requests.get('https://api.example.com/items', params=params)
print(response.url)  # 输出: https://api.example.com/items?key1=value1&key2=value2
```

### 1.2 POST 请求

```python
# 发送表单数据
data = {
    'username': 'user1',
    'password': '123456'
}
response = requests.post('https://api.example.com/login', data=data)

# 发送 JSON 数据
json_data = {
    'name': '张三',
    'age': 25
}
response = requests.post('https://api.example.com/users', json=json_data)
```

## 2. 请求定制

### 2.1 请求头设置

```python
# 自定义请求头
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Authorization': 'Bearer your-token-here',
    'Content-Type': 'application/json'
}
response = requests.get('https://api.example.com/data', headers=headers)
```

### 2.2 Cookie 处理

```python
# 使用 Cookie
cookies = {
    'session_id': 'abc123',
    'user_id': '12345'
}
response = requests.get('https://api.example.com/profile', cookies=cookies)

# 获取响应中的 Cookie
for cookie in response.cookies:
    print(f'{cookie.name}: {cookie.value}')
```

## 3. 响应处理

### 3.1 响应内容

```python
response = requests.get('https://api.example.com/data')

# 文本响应
print(response.text)        # 文本形式的响应内容
print(response.encoding)    # 响应的编码方式

# JSON 响应
json_data = response.json()
print(json_data['name'])

# 二进制响应
print(response.content)     # 二进制形式的响应内容
```

### 3.2 响应信息

```python
# 状态码和响应头
print(response.status_code)  # HTTP 状态码
print(response.headers)      # 响应头
print(response.url)          # 最终的 URL（考虑重定向后）
print(response.elapsed)      # 请求耗时
```

## 4. 高级特性

### 4.1 会话对象

```python
# 创建会话对象
session = requests.Session()

# 设置会话级别的属性
session.headers.update({'User-Agent': 'Custom User Agent'})
session.auth = ('user', 'pass')

# 使用会话发送请求
response = session.get('https://api.example.com/data')
response = session.post('https://api.example.com/update')

# 关闭会话
session.close()
```

### 4.2 超时和重试

```python
# 设置超时
try:
    response = requests.get('https://api.example.com', timeout=5)
except requests.Timeout:
    print("请求超时")

# 带重试的请求
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

retry_strategy = Retry(
    total=3,               # 总重试次数
    backoff_factor=1,      # 重试间隔
    status_forcelist=[500, 502, 503, 504]  # 需要重试的状态码
)
adapter = HTTPAdapter(max_retries=retry_strategy)
session = requests.Session()
session.mount("http://", adapter)
session.mount("https://", adapter)
```

## 5. 文件操作

### 5.1 上传文件

```python
# 上传单个文件
files = {'file': open('report.pdf', 'rb')}
response = requests.post('https://api.example.com/upload', files=files)

# 上传多个文件
files = {
    'file1': ('report.pdf', open('report.pdf', 'rb'), 'application/pdf'),
    'file2': ('image.jpg', open('image.jpg', 'rb'), 'image/jpeg')
}
response = requests.post('https://api.example.com/upload', files=files)
```

### 5.2 下载文件

```python
# 下载文件
response = requests.get('https://example.com/file.pdf', stream=True)
with open('downloaded_file.pdf', 'wb') as f:
    for chunk in response.iter_content(chunk_size=8192):
        f.write(chunk)
```

## 注意事项

1. 始终检查响应状态码，确保请求成功
2. 使用 `with` 语句处理文件操作，确保资源正确关闭
3. 对于大文件下载，使用 `stream=True` 参数
4. 设置适当的超时时间，避免请求挂起
5. 在处理敏感信息时使用 HTTPS
6. 注意处理异常，特别是网络相关的异常

## 常见错误处理

```python
try:
    response = requests.get('https://api.example.com/data')
    response.raise_for_status()  # 抛出非 2xx 响应的 HTTPError 异常
except requests.exceptions.RequestException as e:
    print(f"请求错误: {e}")
except requests.exceptions.HTTPError as e:
    print(f"HTTP 错误: {e}")
except requests.exceptions.ConnectionError as e:
    print(f"连接错误: {e}")
except requests.exceptions.Timeout as e:
    print(f"超时错误: {e}")
``` 