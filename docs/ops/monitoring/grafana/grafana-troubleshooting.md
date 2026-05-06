---
title: Grafana 故障排查
sidebar_position: 6
---

# Grafana 故障排查


## 6.1 排查思路

Grafana 故障建议按链路排查：

1. Grafana 服务是否正常启动。
2. Web 页面和 API 是否可访问。
3. 数据源是否正常。
4. Dashboard 查询是否有结果。
5. Provisioning 是否成功加载。
6. 用户权限是否正确。

## 6.2 页面打不开

排查：

```bash
systemctl status grafana-server  # 查看 Grafana 服务状态
ss -lntp | grep 3000  # 检查 3000 端口监听状态
curl http://localhost:3000/api/health  # 检查 Grafana 健康状态
journalctl -u grafana-server -n 200 --no-pager  # 查看最近服务日志
```

常见原因：

- Grafana 服务未启动。
- 3000 端口被占用。
- 防火墙或安全组未放行。
- 反向代理配置错误。

## 6.3 登录失败

常见原因：

- 用户名或密码错误。
- 管理员密码已被修改。
- 认证方式变更。
- 组织切换导致误判。

重置管理员密码：

```bash
grafana-cli admin reset-admin-password NewPass_123  # 重置 Grafana 管理员密码
```

## 6.4 数据源连不上

排查：

```bash
curl http://localhost:3000/api/health  # 检查 Grafana 自身状态
curl http://prometheus:9090/-/ready  # 检查 Prometheus 是否可访问
journalctl -u grafana-server -n 200 --no-pager  # 查看 Grafana 日志
```

常见原因：

- 数据源 URL 写错。
- Grafana 到 Prometheus 网络不通。
- `access` 模式不匹配。
- 反向代理或 DNS 问题。

## 6.5 Dashboard 无数据

排查方向：

- 数据源是否连接成功。
- PromQL 在 Explore 中是否有结果。
- 变量是否为空。
- 面板时间范围是否正确。
- 标签名是否与查询一致。

常见原因：

- Prometheus 本身没有这条指标。
- Dashboard 使用了错误的数据源。
- 环境变量筛选过窄。
- 社区 Dashboard 指标名和当前环境不一致。

## 6.6 查询很慢

常见原因：

- Dashboard 时间范围太大。
- 变量查询扫全量高基数指标。
- Dashboard 中面板过多。
- PromQL 表达式过重。
- Prometheus 本身查询性能不足。

处理建议：

- 缩小时间范围。
- 用 recording rules 替代复杂表达式。
- 减少变量联动扫描。
- 控制单页面板数量。

## 6.7 Provisioning 不生效

排查：

```bash
docker exec -it grafana ls -R /etc/grafana/provisioning  # 检查容器内 provisioning 文件
docker exec -it grafana ls -R /var/lib/grafana/dashboards  # 检查 Dashboard JSON 挂载
docker compose logs -f grafana  # 查看 Provisioning 加载日志
```

常见原因：

- 挂载路径错误。
- YAML 配置文件语法错误。
- JSON 文件格式错误。
- provider 的 `options.path` 写错。
- 修改文件后没有重启 Grafana。

## 6.8 权限异常

现象：

- 用户能看不该看的 Dashboard。
- 用户不能编辑自己负责的面板。
- 用户看不到某些数据源。

排查方向：

- 用户当前所属 Organization。
- 用户所属 Team。
- Folder 权限。
- Dashboard 单独权限。
- Data source 权限。

## 6.9 反向代理或子路径访问异常

常见现象：

- 登录后跳转到错误地址。
- 页面静态资源 404。
- Nginx 代理后循环跳转。

重点检查：

- `domain`
- `root_url`
- 反向代理 `Host` 和 `X-Forwarded-*` 头

## 6.10 插件异常

常见原因：

- 插件版本和 Grafana 版本不兼容。
- 未签名插件被拒绝加载。
- 离线安装包不完整。

排查：

```bash
grafana-cli plugins ls  # 查看已安装插件
journalctl -u grafana-server -n 200 --no-pager  # 查看插件加载日志
```

## 6.11 常用诊断命令

```bash
systemctl status grafana-server  # 查看 Grafana 服务状态
journalctl -u grafana-server -n 300 --no-pager  # 查看 Grafana 日志
ss -lntp | grep 3000  # 检查 3000 端口监听状态
curl http://localhost:3000/api/health  # 检查 Grafana 健康状态
grafana-cli -v  # 查看 Grafana CLI 版本
grafana-cli plugins ls  # 查看已安装插件
grep -n '^[^;]' /etc/grafana/grafana.ini  # 查看主配置中实际启用的配置项
```

## 6.12 参考资料

- [Grafana Troubleshooting](https://grafana.com/docs/grafana/latest/troubleshooting/)
- [Grafana Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
- [Grafana CLI](https://grafana.com/docs/grafana/latest/cli/)
