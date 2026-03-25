---
title: Python-SSH模块使用
---

# Python SSH 模块使用指南

Python 中主要使用 paramiko 和 fabric 模块来实现 SSH 连接和操作。本文主要介绍这两个模块的使用方法。

## 1. paramiko 模块

### 1.1 安装

```bash
pip install paramiko
```

### 1.2 基本连接

```python
import paramiko

# 创建 SSH 客户端
ssh = paramiko.SSHClient()

# 自动添加主机密钥
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

# 连接服务器
try:
    ssh.connect(
        hostname='192.168.1.100',
        port=22,
        username='root',
        password='your_password'
    )
    print("连接成功！")
except Exception as e:
    print(f"连接失败: {e}")
finally:
    ssh.close()
```

### 1.3 使用密钥认证

```python
# 使用密钥文件连接
try:
    private_key = paramiko.RSAKey.from_private_key_file('/path/to/private_key')
    ssh.connect(
        hostname='192.168.1.100',
        port=22,
        username='root',
        pkey=private_key
    )
except Exception as e:
    print(f"连接失败: {e}")
```

### 1.4 执行命令

```python
def execute_command(ssh, command):
    """执行远程命令并返回结果"""
    try:
        stdin, stdout, stderr = ssh.exec_command(command)
        
        # 获取命令输出
        output = stdout.read().decode()
        error = stderr.read().decode()
        
        # 获取返回码
        exit_code = stdout.channel.recv_exit_status()
        
        return {
            'output': output,
            'error': error,
            'exit_code': exit_code
        }
    except Exception as e:
        return {
            'output': '',
            'error': str(e),
            'exit_code': -1
        }

# 使用示例
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.1.100', username='root', password='password')

# 执行单个命令
result = execute_command(ssh, 'ls -l')
print(result['output'])

# 执行多个命令
commands = [
    'cd /tmp',
    'mkdir test',
    'ls -l'
]
for cmd in commands:
    result = execute_command(ssh, cmd)
    print(f"执行命令 '{cmd}':")
    print(result['output'])
```

### 1.5 文件传输

```python
def sftp_upload(ssh, local_path, remote_path):
    """上传文件到远程服务器"""
    try:
        sftp = ssh.open_sftp()
        sftp.put(local_path, remote_path)
        sftp.close()
        return True
    except Exception as e:
        print(f"上传失败: {e}")
        return False

def sftp_download(ssh, remote_path, local_path):
    """从远程服务器下载文件"""
    try:
        sftp = ssh.open_sftp()
        sftp.get(remote_path, local_path)
        sftp.close()
        return True
    except Exception as e:
        print(f"下载失败: {e}")
        return False

# 使用示例
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.1.100', username='root', password='password')

# 上传文件
sftp_upload(ssh, 'local_file.txt', '/tmp/remote_file.txt')

# 下载文件
sftp_download(ssh, '/tmp/remote_file.txt', 'downloaded_file.txt')
```

### 1.4 密码登录

```python
import paramiko

def ssh_login_with_password(hostname, username, password, port=22):
    """
    使用密码登录远程服务器
    
    参数:
        hostname: 主机地址
        username: 用户名
        password: 密码
        port: SSH端口，默认22
    """
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        # 连接服务器
        ssh.connect(
            hostname=hostname,
            port=port,
            username=username,
            password=password,
            timeout=10  # 设置超时时间
        )
        print(f"成功连接到 {hostname}")
        
        # 执行命令示例
        stdin, stdout, stderr = ssh.exec_command('ls -l')
        print("命令输出:")
        print(stdout.read().decode())
        
        return ssh
        
    except paramiko.AuthenticationException:
        print("认证失败：用户名或密码错误")
    except paramiko.SSHException as ssh_exception:
        print(f"SSH 错误：{ssh_exception}")
    except paramiko.BadHostKeyException as hostkey_exception:
        print(f"主机密钥错误：{hostkey_exception}")
    except Exception as e:
        print(f"连接错误：{str(e)}")
    
    return None

# 使用示例
def main():
    # 连接参数
    hostname = '192.168.1.100'
    username = 'root'
    password = 'your_password'
    
    # 建立连接
    ssh = ssh_login_with_password(hostname, username, password)
    
    if ssh:
        try:
            # 执行多个命令
            commands = [
                'pwd',
                'whoami',
                'df -h'
            ]
            
            for cmd in commands:
                print(f"\n执行命令: {cmd}")
                stdin, stdout, stderr = ssh.exec_command(cmd)
                
                # 获取输出
                output = stdout.read().decode()
                error = stderr.read().decode()
                
                if output:
                    print("输出:")
                    print(output)
                if error:
                    print("错误:")
                    print(error)
                
        finally:
            # 关闭连接
            ssh.close()
            print("\n已关闭 SSH 连接")

if __name__ == '__main__':
    main()
```

## 2. fabric 模块

### 2.1 安装

```bash
pip install fabric
```

### 2.2 基本使用

```python
from fabric import Connection

# 创建连接
conn = Connection(
    host='192.168.1.100',
    user='root',
    port=22,
    connect_kwargs={
        "password": "your_password"
    }
)

# 执行命令
result = conn.run('ls -l', hide=True)
print(result.stdout)

# 使用 sudo
result = conn.sudo('apt update', hide=True)
print(result.stdout)
```

### 2.3 文件操作

```python
# 上传文件
conn.put('local_file.txt', '/tmp/remote_file.txt')

# 下载文件
conn.get('/tmp/remote_file.txt', 'downloaded_file.txt')
```

## 3. 实用示例

### 3.1 批量服务器操作

```python
def batch_execute(servers, command):
    """在多台服务器上执行命令"""
    results = {}
    for server in servers:
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(
                hostname=server['host'],
                port=server.get('port', 22),
                username=server['username'],
                password=server['password']
            )
            
            result = execute_command(ssh, command)
            results[server['host']] = result
            
            ssh.close()
        except Exception as e:
            results[server['host']] = {
                'output': '',
                'error': str(e),
                'exit_code': -1
            }
    
    return results

# 使用示例
servers = [
    {
        'host': '192.168.1.100',
        'username': 'root',
        'password': 'password1'
    },
    {
        'host': '192.168.1.101',
        'username': 'root',
        'password': 'password2'
    }
]

results = batch_execute(servers, 'df -h')
for host, result in results.items():
    print(f"\n服务器: {host}")
    print(result['output'])
```

### 3.2 自动化部署示例

```python
def deploy_application(conn):
    """自动化部署应用程序"""
    try:
        # 更新系统
        conn.sudo('apt update && apt upgrade -y')
        
        # 安装依赖
        conn.sudo('apt install -y python3 python3-pip')
        
        # 上传应用文件
        conn.put('app.py', '/opt/myapp/app.py')
        conn.put('requirements.txt', '/opt/myapp/requirements.txt')
        
        # 安装 Python 依赖
        with conn.cd('/opt/myapp'):
            conn.run('pip3 install -r requirements.txt')
        
        # 重启服务
        conn.sudo('systemctl restart myapp')
        
        return True
    except Exception as e:
        print(f"部署失败: {e}")
        return False

# 使用示例
conn = Connection(
    host='192.168.1.100',
    user='root',
    connect_kwargs={"password": "password"}
)

if deploy_application(conn):
    print("部署成功！")
else:
    print("部署失败！")
```

## 注意事项

1. 安全性考虑：
   - 避免在代码中硬编码密码
   - 优先使用密钥认证而不是密码认证
   - 及时关闭不再使用的连接

2. 错误处理：
   - 总是使用 try-except 处理可能的异常
   - 设置适当的连接超时时间
   - 实现重试机制

3. 性能优化：
   - 对于多台服务器操作，考虑使用多线程或异步
   - 复用 SSH 连接而不是频繁建立新连接
   - 使用会话保持（keep-alive）机制

4. 最佳实践：
   - 使用配置文件管理服务器信息
   - 实现日志记录机制
   - 做好异常情况的回滚处理 