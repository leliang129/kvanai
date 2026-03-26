---
sidebar_position: 10
title: 存储与文件系统
---

# 09 存储与文件系统

## 挂载（`mount`）

查看当前挂载：

```bash
mount | column -t             # 查看当前挂载列表
lsblk -f                      # 查看块设备、文件系统和挂载点
blkid                         # 查看块设备 UUID 和文件系统类型
```

临时挂载：

```bash
sudo mount /dev/sdb1 /mnt/data # 挂载分区到指定目录
sudo umount /mnt/data          # 卸载挂载点
```

永久挂载通过 `/etc/fstab`：

```fstab
UUID=xxxx-xxxx  /data  ext4  defaults,nofail  0  2
```

修改后建议验证：

```bash
sudo mount -a                  # 验证 fstab 配置是否可正常挂载
```

建议：

- 生产环境优先使用 UUID 挂载，避免设备名变化导致挂载失败。
- 改 `fstab` 后立刻执行 `mount -a` 验证，避免重启后起不来。

## 分区

常用工具：`fdisk`、`parted`。

```bash
lsblk                         # 查看磁盘和分区
sudo fdisk -l                 # 查看磁盘分区信息
sudo parted -l                # 查看分区表和磁盘大小
```

基础流程：

1. 识别新磁盘，例如 `lsblk`。
2. 创建分区，例如 `fdisk /dev/sdb`。
3. 格式化文件系统。
4. 挂载并写入 `fstab`。

注意：

- 动生产磁盘前先确认设备名，避免误格式化。
- 云主机扩容后常见流程是先扩盘，再扩分区，再扩文件系统。

## 文件系统类型（ext4/xfs）

- ext4：通用、兼容性好、工具成熟。
- xfs：大文件和并发性能较好，企业场景常见。

创建文件系统：

```bash
sudo mkfs.ext4 /dev/sdb1      # 格式化为 ext4
sudo mkfs.xfs /dev/sdc1       # 格式化为 xfs
lsblk -f                      # 查看文件系统类型
df -Th                        # 查看挂载点和文件系统类型
```

扩容常见命令：

```bash
sudo resize2fs /dev/sdb1      # 扩展 ext4 文件系统
sudo xfs_growfs /data         # 扩展 xfs 挂载点
```

补充说明：

- ext4 通常对块设备执行 `resize2fs`。
- xfs 通常对挂载点执行 `xfs_growfs`。
- 缩容比扩容风险更高，生产环境务必先备份。

## LVM（进阶）

LVM 适合需要动态扩容的场景。

核心概念：

- PV（Physical Volume）
- VG（Volume Group）
- LV（Logical Volume）

常用命令：

```bash
sudo pvcreate /dev/sdb /dev/sdc              # 初始化物理卷
sudo vgcreate vg_data /dev/sdb /dev/sdc      # 创建卷组
sudo lvcreate -L 100G -n lv_logs vg_data     # 创建逻辑卷
sudo mkfs.ext4 /dev/vg_data/lv_logs          # 创建文件系统
sudo pvs                                     # 查看物理卷
sudo vgs                                     # 查看卷组
sudo lvs                                     # 查看逻辑卷
```

扩容示例：

```bash
sudo lvextend -L +50G /dev/vg_data/lv_logs   # 扩展逻辑卷容量
sudo resize2fs /dev/vg_data/lv_logs          # 扩展 ext4 文件系统
```

实战建议：

- 生产扩容前先快照或备份。
- 先确认卷组是否还有空闲空间。
- 关注 IO 等待和文件系统健康，例如 `iostat`、`dmesg`。

## 文件系统检查与配额

常见检查：

```bash
sudo fsck -f /dev/sdb1             # 强制检查文件系统一致性
sudo xfs_repair /dev/sdc1          # 修复 xfs 文件系统
sudo tune2fs -l /dev/sdb1 | head   # 查看 ext4 文件系统参数
```

注意：

- 文件系统修复通常应在卸载状态下进行。
- 修复命令具有破坏性时，要先确认备份和业务影响窗口。
