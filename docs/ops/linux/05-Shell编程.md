---
sidebar_position: 6
title: Shell 编程
---

# 05 Shell 编程

## 基础语法

建议脚本头部使用：

```bash
#!/usr/bin/env bash
set -euo pipefail
```

解释：

- `-e`：命令失败即退出。
- `-u`：未定义变量报错。
- `-o pipefail`：管道任一环节失败即失败。

补充建议：

- 统一使用 `bash`，不要混写 `sh` 语法和 Bash 语法。
- 复杂脚本中把公共函数放到单独文件，减少重复。

## 变量

```bash
name="ops"             # 定义字符串变量
echo "$name"           # 引用变量

readonly ENV=prod      # 只读变量
count=3                # 数值也以字符串形式保存
```

注意：

- 变量引用建议加双引号，避免空格分割与通配符扩展。
- Shell 没有严格类型系统，数值比较和字符串比较要区分写法。

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

if [[ -z "${TOKEN:-}" ]]; then
  echo "TOKEN missing"
  exit 1
fi
```

常用判断：

- `-f`：普通文件存在。
- `-d`：目录存在。
- `-n`：字符串非空。
- `-z`：字符串为空。
- `==`：字符串相等。
- `-eq`：整数相等。

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

建议：

- 处理文件列表时优先使用数组，避免空格路径被拆断。
- 循环中如果执行远程命令或网络请求，要考虑超时和失败重试。

## 函数

```bash
log_info() {
  local msg="$1"
  echo "[$(date +'%F %T')] INFO: $msg"
}

die() {
  local msg="$1"
  echo "[$(date +'%F %T')] ERROR: $msg" >&2
  exit 1
}

log_info "deploy start"
```

建议：

- 函数内部变量优先用 `local`，避免污染全局。
- 公共日志函数和错误退出函数值得复用。

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

实战建议：

- 必填参数必须校验。
- 帮助信息要说明用途、参数、示例。
- 对环境和版本等关键参数，不要给模糊默认值。

## 数组与输入输出

```bash
hosts=("web-01" "web-02" "web-03") # 定义数组
echo "${hosts[0]}"                 # 读取数组第一个元素
printf '%s\n' "${hosts[@]}"        # 按行输出数组

read -r answer                     # 读取一行输入
cat <<'EOF'
deploy start
check config
reload service
EOF
```

说明：

- `read -r` 可避免反斜杠被转义。
- Here Document 适合生成配置片段或多行输出。

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

## 调试与规范

调试技巧：

```bash
bash -n deploy.sh      # 只检查语法
bash -x deploy.sh      # 打印执行过程
shellcheck deploy.sh   # 静态检查脚本问题
```

建议：

- 脚本要有明确退出码。
- 关键动作加日志和时间戳。
- 脚本要可重复执行，也就是尽量做到幂等。
- 对删除、覆盖、重启服务等动作，加前置校验。
