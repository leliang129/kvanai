---
title: MySQL 备份恢复
sidebar_position: 5
---

备份不是“有脚本就行”，要能恢复才算。建议至少做到：**定期备份 + 校验 + 恢复演练**。

## 1. 备份策略（最小集）

- 逻辑备份：`mysqldump`（适合小中规模/迁移）
- 物理备份：Percona XtraBackup（适合大规模/快速恢复）
- binlog：配合实现 PITR（按时间点恢复）

## 2. mysqldump 示例

```bash
mysqldump -uroot -p --single-transaction --routines --triggers \
  --databases appdb | gzip > appdb-$(date +%F).sql.gz
```

## 3. 恢复示例

```bash
gunzip -c appdb-2025-12-26.sql.gz | mysql -uroot -p
```

## 4. 建议的演练点

- 恢复耗时（RTO）
- 恢复到什么时间点（RPO）
- 权限、字符集、时区等一致性

