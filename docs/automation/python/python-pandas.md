---
title: Python-pandas模块
---

# Python pandas 模块使用

pandas 是 Python 中用于数据分析和处理的核心库，提供了高性能、易用的数据结构和数据分析工具。

## 安装

```bash
# 使用 pip 安装
pip install pandas

# 使用 conda 安装
conda install pandas
```

## 1. 基本数据结构

### 1.1 Series（一维数据）

```python
import pandas as pd
import numpy as np

# 创建 Series
s = pd.Series([1, 3, 5, np.nan, 6, 8])
print(s)

# 带索引的 Series
s = pd.Series([1, 3, 5, 6], index=['a', 'b', 'c', 'd'])
print(s['a'])  # 输出: 1
```

### 1.2 DataFrame（二维数据）

```python
# 从字典创建 DataFrame
data = {
    'name': ['张三', '李四', '王五'],
    'age': [25, 30, 35],
    'city': ['北京', '上海', '广州']
}
df = pd.DataFrame(data)
print(df)

# 从列表创建 DataFrame
df = pd.DataFrame([
    ['张三', 25, '北京'],
    ['李四', 30, '上海'],
    ['王五', 35, '广州']
], columns=['name', 'age', 'city'])
```

## 2. 数据导入导出

### 2.1 读取数据

```python
# 读取 CSV 文件
df = pd.read_csv('data.csv', encoding='utf-8')

# 读取 Excel 文件
df = pd.read_excel('data.xlsx', sheet_name='Sheet1')

# 读取 JSON 文件
df = pd.read_json('data.json')

# 读取 SQL 查询
import sqlite3
conn = sqlite3.connect('database.db')
df = pd.read_sql('SELECT * FROM table', conn)
```

### 2.2 保存数据

```python
# 保存为 CSV
df.to_csv('output.csv', index=False, encoding='utf-8')

# 保存为 Excel
df.to_excel('output.xlsx', sheet_name='Sheet1', index=False)

# 保存为 JSON
df.to_json('output.json', orient='records', force_ascii=False)
```

## 3. 数据处理

### 3.1 基本操作

```python
# 查看数据基本信息
print(df.info())        # 数据类型和缺失值信息
print(df.describe())    # 数值列的统计摘要
print(df.head())        # 查看前几行
print(df.shape)         # 数据维度

# 选择数据
print(df['name'])                  # 选择单列
print(df[['name', 'age']])        # 选择多列
print(df.loc[0])                   # 按标签选择行
print(df.iloc[0:2])               # 按位置选择行
```

### 3.2 数据清洗

```python
# 处理缺失值
df.dropna()                    # 删除包含缺失值的行
df.fillna(value=0)            # 填充缺失值
df['age'].fillna(df['age'].mean())  # 用平均值填充

# 删除重复行
df.drop_duplicates()

# 重��名列
df.rename(columns={'name': '姓名', 'age': '年龄'})

# 数据类型转换
df['age'] = df['age'].astype('int64')
```

### 3.3 数据转换

```python
# 排序
df.sort_values('age', ascending=False)  # 按年龄降序排序
df.sort_index()                         # 按索引排序

# 分组统计
df.groupby('city')['age'].mean()        # 按城市分组计算平均年龄
df.groupby('city').agg({
    'age': 'mean',
    'name': 'count'
})

# 数据透视表
pd.pivot_table(df, values='age', index='city', 
              columns='gender', aggfunc='mean')
```

## 4. 数据分析

### 4.1 统计分析

```python
# 基本统计
print(df['age'].mean())    # 平均值
print(df['age'].median())  # 中位数
print(df['age'].mode())    # 众数
print(df['age'].std())     # 标准差
print(df['age'].var())     # 方差

# 相关性分析
print(df.corr())           # 相关系数矩阵
```

### 4.2 时间序列

```python
# 创建时间索引
dates = pd.date_range('20240101', periods=6)
df = pd.DataFrame(np.random.randn(6,4), index=dates)

# 重采样
df.resample('M').mean()    # 按月重采样
df.rolling(window=3).mean()  # 移动平均
```

## 5. 数据可视化

```python
import matplotlib.pyplot as plt

# 折线图
df['age'].plot(kind='line')

# 柱状图
df['city'].value_counts().plot(kind='bar')

# 散点图
df.plot.scatter(x='age', y='salary')

# 箱线图
df.boxplot(column='age', by='city')

plt.show()
```

## 注意事项

1. 大数据集处理时注意内存使用
2. 链式操作时注意使用 `inplace=True` 参数
3. 处理文本数据时注意编码问题
4. 数据类型转换时注意精度损失
5. 使用 `copy()` 避免视图修改原始数据

## 性能优化技巧

```python
# 使用适当的数据类型
df['id'] = df['id'].astype('int32')  # 降低内存使用

# 使用 query 进行高效过滤
df.query('age > 25 & city == "北京"')

# 使用 apply 进行批量操作
df['name'].apply(lambda x: x.upper())

# 使用 categorical 类型处理分类数据
df['city'] = df['city'].astype('category')
``` 