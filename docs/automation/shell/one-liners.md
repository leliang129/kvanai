---
sidebar_position: 2
---

# 常用 One-liners

## 日志切片

```bash
# 统计 5xx top N
rg " 5\\d\\d " access.log | awk '{print $7}' | sort | uniq -c | sort -nr | head
```

## Kubernetes

```bash
# 按重启次数排序找“最闹”的 pod
kubectl get po -A --sort-by=.status.containerStatuses[0].restartCount | tail
```

```bash
# 批量查看某标签 deployment 的镜像
kubectl get deploy -A -l app=myapp -o jsonpath='{range .items[*]}{.metadata.namespace}{"\\t"}{.metadata.name}{"\\t"}{.spec.template.spec.containers[0].image}{"\\n"}{end}'
```

## 网络排障

```bash
# 10 秒内每秒探测一次，记录 HTTP 状态码与耗时
for i in {1..10}; do curl -s -o /dev/null -w "%{http_code} %{time_total}\n" https://example.com; sleep 1; done
```

