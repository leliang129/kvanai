---
title: 实现基于LAMP架构的开源网站
sidebar_position: 7
---

# 7 实现基于 LAMP 架构的开源网站

LAMP = **Linux + Apache + MySQL/MariaDB + PHP**，是经典的开源网站
运行环境。本节以 Rocky Linux 为例，演示如何在一套 LAMP 架构上部署
常见开源应用：WordPress 博客、Discuz 论坛和 ShopXO 电商系统。

---

## 7.1 架构说明

示例环境角色：

| 服务器 IP   | 角色                | 主要服务            |
|-------------|---------------------|---------------------|
| 10.0.0.12   | Web + PHP 应用服务器| Apache、PHP         |
| 10.0.0.13   | 数据库服务器        | MySQL / MariaDB     |

- Web 服务器负责处理 HTTP 请求和 PHP 代码；
- 数据库服务器负责存储业务数据；
- 客户端通过浏览器访问域名，如 `wordpress.example.com`。

---

## 7.2 部署 WordPress 博客

### 7.2.1 安装 LAMP 基础环境（Web 主机）

```bash
# 安装 Apache 与 PHP
yum install -y httpd php php-mysqlnd php-cli

# 启动并设置开机自启
systemctl enable --now httpd
```

确认 PHP 是否工作：

```bash
cat > /var/www/html/test.php << 'EOF'
<?php
phpinfo();
EOF
```

浏览器访问 `http://10.0.0.12/test.php`，如果能看到 PHP 信息页面，
说明 Apache + PHP 正常。

### 7.2.2 准备数据库环境（DB 主机）

在数据库服务器 `10.0.0.13` 上：

```bash
yum install -y mariadb-server
systemctl enable --now mariadb
```

创建 WordPress 数据库与用户：

```sql
CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8mb4;
CREATE USER 'wordpresser'@'10.0.0.%' IDENTIFIED BY 'StrongPass123!';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpresser'@'10.0.0.%';
FLUSH PRIVILEGES;
```

### 7.2.3 下载并部署 WordPress（Web 主机）

```bash
cd /var/www/html
wget https://cn.wordpress.org/latest-zh_CN.zip
yum install -y unzip
unzip latest-zh_CN.zip
chown -R apache:apache wordpress
```

配置虚拟主机：

```apache
<VirtualHost *:80>
  ServerName wordpress.example.com
  DocumentRoot "/var/www/html/wordpress"
  <Directory "/var/www/html/wordpress">
    AllowOverride all
    Require all granted
  </Directory>
</VirtualHost>
```

保存为 `/etc/httpd/conf.d/wordpress.example.com.conf`，然后：

```bash
systemctl restart httpd
```

在本地电脑 `hosts` 文件中添加：

```text
10.0.0.12 wordpress.example.com
```

浏览器访问 `http://wordpress.example.com`，按向导填写数据库信息：

- 数据库名：`wordpress`
- 用户名：`wordpresser`
- 密码：`StrongPass123!`
- 数据库主机：`10.0.0.13`

完成安装后即可进入后台进行主题和插件管理。

---

## 7.3 部署 Discuz 论坛

Discuz! 是常见的社区论坛程序，部署步骤与 WordPress 类似。

### 7.3.1 准备代码与目录（Web 主机）

```bash
cd /var/www/html
wget https://foruda.gitee.com/attach_file/1716183924840081332/discuz_x3.5_sc_utf8_20240520.zip
unzip discuz_x3.5_sc_utf8_20240520.zip -d discuz
chown -R apache:apache discuz
```

配置虚拟主机：

```apache
<VirtualHost *:80>
  ServerName discuz.example.com
  DocumentRoot "/var/www/html/discuz/upload"
  <Directory "/var/www/html/discuz/upload">
    AllowOverride all
    Require all granted
  </Directory>
</VirtualHost>
```

重启 Apache：

```bash
systemctl restart httpd
```

### 7.3.2 数据库准备（DB 主机）

```sql
CREATE DATABASE discuz DEFAULT CHARACTER SET utf8mb4;
CREATE USER 'discuz'@'10.0.0.%' IDENTIFIED BY 'DiscuzPass123!';
GRANT ALL PRIVILEGES ON discuz.* TO 'discuz'@'10.0.0.%';
FLUSH PRIVILEGES;
```

浏览器访问 `http://discuz.example.com`，按安装向导完成初始化。

---

## 7.4 部署 ShopXO 电商系统

### 7.4.1 代码与网站配置

```bash
cd /var/www/html
# 假设已获取 shopxo 安装包，并解压到 shopxo 目录
chown -R apache:apache shopxo
```

配置虚拟主机：

```apache
<VirtualHost *:80>
  ServerName shopxo.example.com
  DocumentRoot "/var/www/html/shopxo/public"
  <Directory "/var/www/html/shopxo/public">
    AllowOverride all
    Require all granted
  </Directory>
</VirtualHost>
```

### 7.4.2 数据库准备

```sql
CREATE DATABASE shopxo DEFAULT CHARACTER SET utf8mb4;
CREATE USER 'shopxo'@'10.0.0.%' IDENTIFIED BY 'ShopxoPass123!';
GRANT ALL PRIVILEGES ON shopxo.* TO 'shopxo'@'10.0.0.%';
FLUSH PRIVILEGES;
```

浏览器访问 `http://shopxo.example.com`，根据向导完成安装与初始化。

---

## 7.5 综合架构与流量路径

在典型的 LAMP 多机架构中，请求路径大致如下：

1. 客户端浏览器访问域名（如 `wordpress.example.com`）；
2. DNS 将域名解析到 Web 服务器 IP（如 192.168.8.16 或 10.0.0.12）；
3. Web 服务器上的 Apache 根据虚拟主机配置将请求分发到对应站点目录；
4. PHP 代码通过 `mysqli` / PDO 等扩展连接后端 MySQL / MariaDB；
5. 数据库执行 SQL 语句，返回结果给 PHP；
6. PHP 渲染出 HTML 返回给浏览器。

通过在这一套架构上部署多个站点（博客、论坛、电商），可以充分体验
LAMP 组合在中小型网站中的典型用法，也为后续学习负载均衡、高可用、
监控与备份等内容打下基础。
