---
sidebar_position: 5
title: 文本处理
---

# 04 文本处理

文本处理是 Linux 自动化的核心能力，很多问题都可以通过“过滤 + 提取 + 统计 + 重定向”快速定位。

## `grep`

常见用法：

```bash
grep "ERROR" app.log                    # 查找包含 ERROR 的行
grep -n "timeout" app.log               # 显示匹配行号
grep -E "ERROR|WARN" app.log            # 使用扩展正则匹配多个模式
grep -r "listen 80" /etc/nginx          # 递归目录查找配置
grep -i "denied" /var/log/auth.log      # 忽略大小写匹配
grep -C 2 "panic" app.log               # 同时显示上下文 2 行
```

高频参数：

- `-n`：显示行号。
- `-E`：使用扩展正则。
- `-r`：递归目录。
- `-v`：反向匹配。
- `-i`：忽略大小写。
- `-C`：显示上下文。

建议：

- 大日志先缩小时间范围，再做关键字匹配。
- 正则较复杂时先在小样本上验证，避免误判。

## `awk`

`awk` 擅长“按列处理”和“聚合统计”。

```bash
awk '{print $1, $5}' access.log # 打印第 1 和第 5 列
awk '{count[$9]++} END {for (code in count) print code, count[code]}' access.log # 统计状态码数量
awk -F ',' '{print $1, $3}' users.csv # 指定逗号为分隔符
awk '$9 >= 500 {print $1, $7, $9}' access.log # 过滤状态码大于等于 500 的请求
awk '{sum+=$10} END {print sum}' access.log # 汇总第 10 列数值
```

典型场景：

- 提取访问日志中的 IP、URL、状态码。
- 对监控数据做简单汇总。
- 对 CSV 或分隔文本快速取列。

## `sed`

`sed` 擅长“按规则替换、删除、打印文本流”。

```bash
sed 's/old/new/g' app.conf                   # 替换文本流中的内容
sed -n '1,20p' app.log                       # 打印第 1 到 20 行
sed -i 's/DEBUG/INFO/g' app.conf             # 原地修改文件
sed '/^#/d' app.conf                         # 删除注释行
sed -n '/BEGIN/,/END/p' app.log              # 打印两个标记之间的内容
```

注意：

- `sed -i` 会直接改文件，正式操作前建议备份。
- 对配置文件做批量替换前，要先确认替换范围不会误伤注释和路径。

## `sort/uniq`

```bash
sort names.txt                              # 按字典序排序
sort -n numbers.txt                         # 按数值排序
sort access.log | uniq                      # 去重相邻重复行
sort access.log | uniq -c | sort -nr        # 统计重复次数并倒序排序
cut -d ' ' -f 1 access.log | sort | uniq -c | sort -nr | head # 统计访问量最高的 IP
```

典型用途：

- 统计出现频次最高的 IP、URL、错误码。
- 找出重复配置项或重复数据。
- 做巡检结果对比。

## `cut` / `tr` / `xargs`

```bash
cut -d ':' -f 1 /etc/passwd                 # 取每行第 1 列
tr '[:lower:]' '[:upper:]' < app.txt        # 小写转大写
printf '%s\n' a b c | xargs -I {} echo "item={}" # 批量拼接参数
find /tmp -type f | xargs rm -f             # 批量删除结果列表中的文件
```

注意：

- `xargs` 遇到带空格文件名时容易出错，优先配合 `find -print0` 和 `xargs -0`。
- 批量删除前先把 `rm -f` 改成 `echo` 验证结果。

## 管道与重定向

管道 `|`：把前一个命令输出作为后一个命令输入。

```bash
grep " 500 " access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head # 统计产生 500 的来源 IP
```

重定向：

- `>`：覆盖写入。
- `>>`：追加写入。
- `2>`：错误输出。
- `2>&1`：合并标准输出和错误输出。

```bash
./deploy.sh > deploy.log 2>&1 # 把标准输出和错误输出都写入日志
tee result.txt < input.txt    # 同时输出到终端和文件
```

实战建议：

- 先用小样本验证表达式，再跑全量。
- 对生产日志优先只读操作，避免误改原始数据。
- 管道过长时，拆成多步调试更容易定位是哪一环出错。
