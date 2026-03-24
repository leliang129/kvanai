---
sidebar_position: 2
---

# 巡检脚本片段

## MySQL 复制状态

```python
import mysql.connector

conn = mysql.connector.connect(
    host="db",
    user="ops",
    password="***",
    database="app",
)
cur = conn.cursor()
cur.execute("SHOW SLAVE STATUS")
print(cur.fetchone())
```

## HTTP 探测 + 超时

```python
import requests

resp = requests.get("https://example.com/healthz", timeout=3)
resp.raise_for_status()
print(resp.status_code, resp.text[:200])
```

