---
title: Python-分支循环综合案例
sidebar_position: 5
---

# Python 分支循环综合案例

本文档提供了一些简单的编程案例，展示分支结构和循环结构的综合应用。

## 1. 猜数字游戏

```python
import random

# 生成1-100的随机数
target = random.randint(1, 100)
attempts = 0
max_attempts = 7

print("欢迎玩猜数字游戏！")
print(f"我已经想好了一个1-100之间的数字，你有{max_attempts}次机会猜对它。")

while attempts < max_attempts:
    try:
        # 获取用户输入
        guess = int(input(f"\n请输入你的猜测（还剩{max_attempts - attempts}次）："))
        attempts += 1

        # 判断大小
        if guess < target:
            print("太小了！")
        elif guess > target:
            print("太大了！")
        else:
            print(f"\n恭喜你猜对了！答案就是{target}")
            print(f"你用了{attempts}次就猜到了！")
            break
            
        # 提供额外提示
        if attempts == max_attempts - 2:
            print(f"提示：这个数字是{target//10*10}到{target//10*10+9}之间的数")
            
    except ValueError:
        print("请输入有效的数字！")
        continue

if attempts >= max_attempts:
    print(f"\n游戏结束！正确答案是{target}")
```

## 2. 学生成绩管理

```python
# 初始化学生成绩字典
students = {}

# 主循环
while True:
    print("\n=== 学生成绩管理系统 ===")
    print("1. 添加学生成绩")
    print("2. 查询学生成绩")
    print("3. 显示所有学生")
    print("4. 计算平均分")
    print("5. 退出系统")
    
    choice = input("\n请选择操作（1-5）：")
    
    if choice == '1':
        name = input("请输入学生姓名：")
        try:
            score = float(input("请输入学生成绩："))
            if 0 <= score <= 100:
                students[name] = score
                print(f"已添加 {name} 的成绩：{score}")
            else:
                print("成绩必须在0-100之间！")
        except ValueError:
            print("请输入有效的成绩！")
            
    elif choice == '2':
        name = input("请输入要查询的学生姓名：")
        if name in students:
            print(f"{name} 的成绩是：{students[name]}")
        else:
            print("未找到该学生！")
            
    elif choice == '3':
        if students:
            print("\n所有学生成绩：")
            for name, score in sorted(students.items()):
                print(f"{name}: {score}")
        else:
            print("暂无学生记录！")
            
    elif choice == '4':
        if students:
            avg = sum(students.values()) / len(students)
            print(f"\n全班平均分：{avg:.2f}")
            print("高于平均分的学生：")
            for name, score in students.items():
                if score > avg:
                    print(f"{name}: {score}")
        else:
            print("暂无学生记录！")
            
    elif choice == '5':
        print("感谢使用！再见！")
        break
        
    else:
        print("无效的选择，请重新输入！")
```

## 3. 简单计算器

```python
# 初始化变量
result = 0
running = True

print("简单计算器（输入'q'退出）")
print("支持的运算：+、-、*、/")

while running:
    # 显示当前结果
    print(f"\n当前结果：{result}")
    
    # 获取用户输入
    operation = input("请输入运算符：")
    
    # 检查是否退出
    if operation.lower() == 'q':
        print("计算结束！")
        break
        
    # 检查运算符是否有效
    if operation not in ['+', '-', '*', '/']:
        print("无效的运算符！")
        continue
        
    # 获取操作数
    try:
        number = float(input("请输入数字："))
    except ValueError:
        print("请输入有效的数字！")
        continue
        
    # 执行计算
    if operation == '+':
        result += number
    elif operation == '-':
        result -= number
    elif operation == '*':
        result *= number
    elif operation == '/':
        if number == 0:
            print("错误：除数不能为零！")
            continue
        result /= number
        
    # 显示计算结果
    print(f"计算结果：{result}")
```

## 4. 购物清单管理

```python
# 初始化购物清单
shopping_list = []
total_price = 0

print("购物清单管理系统")

while True:
    print("\n1. 添加商品")
    print("2. 查看清单")
    print("3. 计算总价")
    print("4. 删除商品")
    print("5. 退出")
    
    choice = input("\n请选择操作（1-5）：")
    
    if choice == '1':
        item = input("请输入商品名称：")
        try:
            price = float(input("请输入商品价格："))
            if price > 0:
                shopping_list.append((item, price))
                print(f"已添加商品：{item}，价格：{price}")
            else:
                print("价格必须大于0！")
        except ValueError:
            print("请输入有效的价格！")
            
    elif choice == '2':
        if shopping_list:
            print("\n当前购物清单：")
            for i, (item, price) in enumerate(shopping_list, 1):
                print(f"{i}. {item}: ￥{price:.2f}")
        else:
            print("购物清单为空！")
            
    elif choice == '3':
        if shopping_list:
            total = sum(price for _, price in shopping_list)
            print(f"\n总价：￥{total:.2f}")
            
            # 计算折扣
            if total > 500:
                discount = total * 0.1
                print(f"满500减10%优惠：-￥{discount:.2f}")
                print(f"实付金额：￥{total-discount:.2f}")
        else:
            print("购物清单为空！")
            
    elif choice == '4':
        if shopping_list:
            print("\n当前购物清单：")
            for i, (item, price) in enumerate(shopping_list, 1):
                print(f"{i}. {item}: ￥{price:.2f}")
                
            try:
                index = int(input("请输入要删除的商品编号：")) - 1
                if 0 <= index < len(shopping_list):
                    removed_item = shopping_list.pop(index)
                    print(f"已删除商品：{removed_item[0]}")
                else:
                    print("无效的商品编号！")
            except ValueError:
                print("请输入有效的编号！")
        else:
            print("购物清单为空！")
            
    elif choice == '5':
        print("感谢使用！再见！")
        break
        
    else:
        print("无效的选择，请重新输入！")
```

## 注意事项

1. 输入验证：始终验证用户输入的有效性
2. 异常处理：使用 try-except 处理可能的错误
3. 数据验证：确保数据在有效范围内
4. 用户体验：提供清晰的提示和反馈
5. 程序健壮性：处理各种可能的异常情况

## 扩展思考

1. 如何添加数据持久化功能？
2. 如何改进用户界面？
3. 如何添加更多的功能？
4. 如何优化程序性能？
5. 如何提高代码的可维护性？ 