---
sidebar_position: 6
title: 05 Shell 编程
---

# 05 Shell 编程

## 基础语法

建议脚本头部使用：

```bash
#!/usr/bin/env bash
set -euo pipefail
```

解释：

- `-e` 命令失败即退出
- `-u` 未定义变量报错
- `-o pipefail` 管道任一环节失败即失败

## 变量

```bash
name="ops"
echo "$name"

readonly ENV=prod
```

注意变量引用建议加双引号，避免空格分割与通配符扩展。

## 条件判断

```bash
if [[ -f /etc/os-release ]]; then
  echo "ok"
else
  echo "missing"
fi

if [[ "$ENV" == "prod" ]]; then
  echo "production"
fi
```

## 循环

```bash
for host in host1 host2 host3; do
  echo "check $host"
done

i=0
while [[ $i -lt 3 ]]; do
  echo "$i"
  ((i++))
done
```

## 函数

```bash
log_info() {
  local msg="$1"
  echo "[$(date +'%F %T')] INFO: $msg"
}

log_info "deploy start"
```

## 参数处理

```bash
#!/usr/bin/env bash
set -euo pipefail

show_help() {
  echo "Usage: $0 -e <env> -v <version>"
}

env=""
version=""

while getopts ":e:v:h" opt; do
  case "$opt" in
    e) env="$OPTARG" ;;
    v) version="$OPTARG" ;;
    h) show_help; exit 0 ;;
    *) show_help; exit 1 ;;
  esac
done

[[ -z "$env" || -z "$version" ]] && { show_help; exit 1; }

echo "env=$env version=$version"
```

## 实战脚本

示例：批量检查 URL 健康状态。

```bash
#!/usr/bin/env bash
set -euo pipefail

urls=(
  "https://www.baidu.com"
  "https://www.kubernetes.io"
)

for u in "${urls[@]}"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$u" || true)
  if [[ "$code" == "200" ]]; then
    echo "[OK] $u"
  else
    echo "[FAIL] $u code=$code"
  fi
done
```

建议：

- 脚本要有明确退出码。
- 关键动作加日志和时间戳。
- 可重复执行（幂等）。
