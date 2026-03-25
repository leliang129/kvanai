---
title: Python-网页解析(XPath和bs4)
---

# Python 网页解析工具使用

XPath 和 BeautifulSoup4 是 Python 中最常用的两个网页解析工具，分别适用于不同的解析场景。

## 安装

```bash
# 安装 lxml（用于 XPath）
pip install lxml

# 安装 BeautifulSoup4
pip install beautifulsoup4

# 安装解析器
pip install html5lib
```

## 1. XPath 使用方法

### 1.1 基本语法

```python
from lxml import etree

# 创建解析对象
html = etree.HTML(html_text)  # 从字符串创建
html = etree.parse('page.html')  # 从文件创建

# 常用路径表达式
'''
/  从根节点选取
// 从匹配选择的当前节点选择文档中的节点，而不考虑它们的位置
.  选取当前节点
.. 选取当前节点的父节点
@  选取属性
'''
```

### 1.2 常用查找方法

```python
# 1. 按标签查找
elements = html.xpath('//div')  # 查找所有 div 标签

# 2. 按属性查找
elements = html.xpath('//div[@class="content"]')  # 查找 class 为 content 的 div
elements = html.xpath('//a[@href]')  # 查找带 href 属性的 a 标签

# 3. 按文本查找
elements = html.xpath('//div[text()="标题"]')  # 完全匹配
elements = html.xpath('//div[contains(text(), "标题")]')  # 包含匹配

# 4. 组合查找
elements = html.xpath('//div[@class="content"]//a[@href]')

# 5. 获取属性和文本
href = html.xpath('//a/@href')  # 获取 href 属性值
text = html.xpath('//div/text()')  # 获取文本内容
```

### 1.3 实际示例

```python
import requests
from lxml import etree

# 获取网页内容
url = 'http://example.com'
response = requests.get(url)
html = etree.HTML(response.text)

# 提取信息
titles = html.xpath('//h2[@class="title"]/text()')
links = html.xpath('//a[@class="link"]/@href')
items = html.xpath('//div[@class="item"]')

for item in items:
    # 在当前节点下继续查找
    title = item.xpath('.//h2/text()')[0]
    link = item.xpath('.//a/@href')[0]
    print(f'标题: {title}, 链接: {link}')
```

## 2. BeautifulSoup4 使用方法

### 2.1 创建 BS4 对象

```python
from bs4 import BeautifulSoup

# 从字符串创建
soup = BeautifulSoup(html_text, 'html.parser')  # 使用内置解析器
soup = BeautifulSoup(html_text, 'lxml')         # 使用 lxml 解析器
soup = BeautifulSoup(html_text, 'html5lib')     # 使用 html5lib 解析器

# 从文件创建
with open('page.html', 'r', encoding='utf-8') as f:
    soup = BeautifulSoup(f, 'lxml')
```

### 2.2 常用查找方法

```python
# 1. find_all：查找所有匹配的标签
elements = soup.find_all('div')  # 查找所有 div 标签
elements = soup.find_all('div', class_='content')  # 按 class 查找
elements = soup.find_all('div', attrs={'data-id': '123'})  # 按属性查找
elements = soup.find_all(['div', 'p'])  # 查找多个标签

# 2. find：查找第一个匹配的标签
element = soup.find('div', class_='content')

# 3. select：使用 CSS 选择器查找
elements = soup.select('div.content')  # 查找 class 为 content 的 div
elements = soup.select('#main')        # 按 id 查找
elements = soup.select('div > p')      # 子元素查找

# 4. 获取属性和文本
element['href']      # 获取属性
element.get('href')  # 获取属性的另一种方式
element.text         # 获取文本内容
element.string       # 获取直接文本内容
```

### 2.3 导航文档树

```python
# 父节点
element.parent       # 获取父节点
element.parents      # 获取所有祖先节点

# 子节点
element.children     # 获取直接子节点
element.descendants  # 获取所有子孙节点

# 兄弟节点
element.next_sibling        # 下一个兄弟节点
element.previous_sibling    # 上一个兄弟节点
element.next_siblings      # 后面所有兄弟节点
element.previous_siblings  # 前面所有兄弟节点
```

### 2.4 实际示例

```python
import requests
from bs4 import BeautifulSoup

# 获取网页内容
url = 'http://example.com'
response = requests.get(url)
soup = BeautifulSoup(response.text, 'lxml')

# 提取信息
# 1. 提取所有文章标题和链接
articles = soup.find_all('div', class_='article')
for article in articles:
    title = article.find('h2').text.strip()
    link = article.find('a')['href']
    print(f'标题: {title}, 链接: {link}')

# 2. 提取表格数据
table = soup.find('table', id='data')
for row in table.find_all('tr'):
    cols = row.find_all('td')
    if cols:  # 跳过表头
        data = [col.text.strip() for col in cols]
        print(data)
```

## 3. 对比和选择

### XPath 优势
1. 路径表达式强大，可以精确定位元素
2. 性能较好，适合处理大型文档
3. 支持复杂的条件查询

### BeautifulSoup4 优势
1. API 更加友好，使用更简单
2. 容错能力强，可以处理不规范的 HTML
3. 提供方便的导航功能

## 注意事项

1. XPath：
   - 注意路径表达式的准确性
   - 使用 text() 获取文本时可能需要 strip() 处理
   - 建议使用相对路径避免结构变化影响

2. BeautifulSoup4：
   - 选择合适的解析器（推荐 lxml）
   - 注意内存使用，处理大文件时考虑分块处理
   - 使用 decompose() 及时释放不需要的元素

## 常见错误处理

```python
# XPath 错误处理
try:
    result = html.xpath('//div[@class="not-exist"]/text()')
    text = result[0] if result else ''
except IndexError:
    print("未找到匹配元素")

# BeautifulSoup 错误处理
try:
    element = soup.find('div', class_='not-exist')
    text = element.text if element else ''
except AttributeError:
    print("元素不存在或没有文本内容")
``` 