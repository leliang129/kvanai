---
title: Linux 一键换源
sidebar_position: 8
---

# Linux 一键换源

## 当前可用

### LinuxMirrors 通用换源脚本

```bash
bash <(curl -sSL https://linuxmirrors.cn/main.sh)
```

### LinuxMirrors 无人值守模式

```bash
bash <(curl -sSL https://linuxmirrors.cn/main.sh) \
  --source mirrors.aliyun.com \
  --protocol https \
  --use-intranet-source false \
  --install-epel false \
  --backup true \
  --upgrade-software false \
  --clean-cache true \
  --ignore-backup-tips
```

其中 `--source` 可以替换为你要使用的镜像站域名。
