# WARP Usque Windows 完全指南：构建稳定的 SOCKS5 代理服务

> 基于开源项目 [usque](https://github.com/Diniboy1123/usque) 的 Windows
> 实战部署指南

## 前言

Cloudflare WARP 是一款优秀的 VPN
服务，但官方客户端在某些场景下并不够灵活。`usque` 是一个开源的 WARP MASQUE
协议重实现，提供了多种工作模式，包括 SOCKS5 代理、HTTP 代理和原生隧道模式。

本指南将详细介绍如何在 Windows 上部署
`usque`，并实现**自动保活**、**连接监控**和**归属地检测**等功能，确保代理服务的稳定运行。

---

## 目录

1. [什么是 Usque](#什么是-usque)
2. [准备工作](#准备工作)
3. [快速开始](#快速开始)
4. [Windows 服务安装](#windows-服务安装)
5. [连接监控与保活](#连接监控与保活)
6. [常见问题排查](#常见问题排查)
7. [性能优化建议](#性能优化建议)
8. [进阶配置](#进阶配置)

---

## 什么是 Usque

**Usque** 是 Cloudflare WARP 客户端 MASQUE 模式的开源重实现，它基于
[RFC 9484 Connect-IP](https://datatracker.ietf.org/doc/rfc9484/)
协议，提供了以下优势：

### 核心特性

- **跨平台支持**：Windows、Linux、macOS、Android、iOS
- **多种代理模式**：SOCKS5、HTTP Proxy、原生 TUN 隧道、端口转发
- **无 root 权限要求**：用户态网络栈模拟
- **开源透明**：完全开源，可审查代码
- **轻量高效**：相比官方客户端占用资源更少

### 为什么选择 Usque

| 特性       | Cloudflare WARP 官方客户端 | Usque           |
| ---------- | -------------------------- | --------------- |
| 开源       | ❌ 闭源                    | ✅ 完全开源     |
| 资源占用   | 高 (Android 260MB+)        | 低 (Go 二进制)  |
| 自定义能力 | 受限                       | 完全可控        |
| 服务端运行 | 困难                       | 支持            |
| 代理模式   | 仅 VPN                     | SOCKS5/HTTP/TUN |

---

## 准备工作

### 系统要求

- **操作系统**：Windows 10/11 (推荐 Windows 11)
- **PowerShell**：5.1 或更高版本
- **网络**：稳定的互联网连接
- **其他**：NSSM (Non-Sucking Service Manager)

### 下载 Usque

访问 [GitHub Releases](https://github.com/Diniboy1123/usque/releases)
下载最新版本的 Windows amd64 二进制文件。

```powershell
# 创建项目目录
New-Item -ItemType Directory -Path "C:\WARP-Usque" -Force
Set-Location "C:\WARP-Usque"

# 下载并解压 (以 v1.4.2 为例)
# 从 GitHub 下载 usque-1.4.2-windows-amd64.zip
# 解压到当前目录
```

### 安装 NSSM

NSSM 用于将 PowerShell 脚本注册为 Windows 服务。

```powershell
# 下载 NSSM
# https://nssm.cc/download
# 解压到 C:\Tools\nssm

# 或使用 Chocolatey 安装
choco install nssm
```

---

## 快速开始

### 1. 注册 Cloudflare WARP 账户

```powershell
# 创建新账户并注册设备
.\usque.exe register -a

# 为设备指定名称
.\usque.exe register -a -n "MyWindowsPC"

# 如果使用 Zero Trust，提供 JWT token
.\usque.exe register --jwt "your-jwt-token"
```

执行成功后会生成 `config.json` 文件，包含：

```json
{
  "private_key": "ECDSA P-256 私钥",
  "endpoint_v4": "162.159.199.2",
  "endpoint_v6": "2606:4700:103::",
  "endpoint_pub_key": "服务器公钥",
  "license": "账户许可证",
  "id": "设备 UUID",
  "access_token": "访问令牌",
  "ipv4": "172.16.0.2",
  "ipv6": "2606:xxxx:xxxx"
}
```

### 2. 启动 SOCKS5 代理

```powershell
# 基础启动（无认证）
.\usque.exe socks

# 带认证的启动（推荐）
.\usque.exe socks -b 0.0.0.0 -p 1080 `
    --username "your-username" `
    --password "your-password" `
    -d 1.1.1.1 -d 8.8.8.8 -d 9.9.9.9 -d 94.140.14.14 `
    -s www.cloudflare-gateway.com
```

**参数说明：**

| 参数         | 说明                          |
| ------------ | ----------------------------- |
| `-b`         | 绑定地址 (0.0.0.0 = 所有接口) |
| `-p`         | 监听端口 (默认 1080)          |
| `--username` | SOCKS5 用户名                 |
| `--password` | SOCKS5 密码                   |
| `-d`         | DNS 服务器 (可多次指定)       |
| `-s`         | SNI (用于 Zero Trust)         |

### 3. 测试代理连接

```powershell
# 测试基本连接
curl -x socks5://username:password@127.0.0.1:1080 https://api.ip.sb/geoip

# 测试详细信息
curl -x socks5://username:password@127.0.0.1:1080 `
    https://api.ip.sb/geoip -v `
    --doh-url https://pngwczx94z.cloudflare-gateway.com/dns-query `
    -H "user-agent:Mozilla/5.0 (Windows NT 10.0; Win64; x64)" `
    -U username:password
```

---

## Windows 服务安装

为了实现开机自启动和自动重启，我们将 usque 注册为 Windows 服务。

### 创建启动脚本

创建 [start.ps1](start.ps1)：

```powershell
# WARP Usque SOCKS5 Proxy Startup Script
$ErrorActionPreference = "Continue"

# 配置参数
$BIND_ADDRESS = "0.0.0.0"
$PORT = "1080"
$USERNAME = "biiacuuruavimks9d4cn"
$PASSWORD = "biiacuuruavimks9d4cn"
$SNI = "cloudflare-gateway.com"

# DNS 服务器
$DNS_SERVERS = @("1.1.1.1", "8.8.8.8", "9.9.9.9", "94.140.14.14")

# 构建 DNS 参数
$dnsParams = $DNS_SERVERS | ForEach-Object { "-d", $_ }

# 启动 usque
& ".\usque.exe" socks `
    -b $BIND_ADDRESS `
    -p $PORT `
    --username $USERNAME `
    --password $PASSWORD `
    -s $SNI `
    @dnsParams
```

### 安装服务

使用 [install.ps1](install.ps1) 安装服务：

```powershell
# 配置路径
$NSSM_PATH = "C:\迅雷下载\nssm-2.24-101-g897c7ad\win64\nssm.exe"
$PROJECT_PATH = "C:\迅雷下载\warp-usque-windows-guide"

# 安装主服务
& $NSSM_PATH install usque "pwsh.exe"
& $NSSM_PATH set usque AppParameters "-f start.ps1"
& $NSSM_PATH set usque AppDirectory $PROJECT_PATH
& $NSSM_PATH set usque AppExit Default Restart
& $NSSM_PATH set usque AppStdout "$PROJECT_PATH\out.log"
& $NSSM_PATH set usque AppStderr "$PROJECT_PATH\err.log"
& $NSSM_PATH set usque AppTimestampLog 1
& $NSSM_PATH set usque Description "WARP Usque SOCKS5 Proxy Service"
& $NSSM_PATH set usque DisplayName "WARP Usque Proxy"
& $NSSM_PATH set usque ObjectName LocalSystem
& $NSSM_PATH set usque Start SERVICE_AUTO_START
& $NSSM_PATH set usque Type SERVICE_WIN32_OWN_PROCESS

# 启动服务
& $NSSM_PATH start usque
```

### 服务管理命令

```powershell
# 查看服务状态
& $NSSM_PATH status usque

# 停止服务
& $NSSM_PATH stop usque

# 重启服务
& $NSSM_PATH restart usque

# 卸载服务
& $NSSM_PATH stop usque
& $NSSM_PATH remove usque confirm
```

---

## 连接监控与保活

### 问题背景

从实际运行日志来看，usque 存在以下问题：

1. **无活动自动断开**：长时间无数据传输时，连接会断开
   ```
   timeout: no recent network activity
   ```

2. **网络波动导致重连**：网络不稳定时频繁重连
   ```
   Failed to connect tunnel: handshake did not complete in time
   ```

3. **需要定期测试**：确保代理正常工作并检测归属地

### 解决方案

#### 1. 创建监控脚本

创建 [keepalive-monitor.ps1](keepalive-monitor.ps1)：

```powershell
<#
.SYNOPSIS
    WARP Usque 连接监控与保活脚本

.DESCRIPTION
    定期测试代理连接，检测网络归属地，并在连接失败时重启服务
#>

param(
    [int]$IntervalSeconds = 300,  # 测试间隔：5分钟
    [string]$ProxyHost = "127.0.0.1",
    [int]$ProxyPort = 1080,
    [string]$Username = "biiacuuruavimks9d4cn",
    [string]$Password = "biiacuuruavimks9d4cn",
    [string]$LogDir = ".\logs"
)

# 创建日志目录
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path $LogDir "monitor-$(Get-Date -Format 'yyyy-MM-dd').log"
    "[$timestamp] [$Level] $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host "[$timestamp] [$Level] $Message"
}

function Test-ProxyConnection {
    Write-Log "开始测试代理连接..."

    $testUrls = @(
        "https://api.ip.sb/geoip",
        "https://www.cloudflare.com/cdn-cgi/trace",
        "https://ipv6.ipleak.net/?mode=json"
    )

    $results = @()

    foreach ($url in $testUrls) {
        try {
            Write-Log "测试: $url"

            $proxyUrl = "socks5://${Username}:${Password}@${ProxyHost}:${ProxyPort}"
            $response = curl -x $proxyUrl $url -s --max-time 30 --connect-timeout 10

            if ($response) {
                # 解析响应
                if ($url -match "ip.sb") {
                    $data = $response | ConvertFrom-Json
                    $country = $data.country
                    $isp = $data.isp
                    $ip = $data.ip

                    Write-Log "✓ 连接成功 - IP: $ip, 国家: $country, ISP: $isp"

                    return @{
                        Success = $true
                        IP = $ip
                        Country = $country
                        ISP = $isp
                        Timestamp = Get-Date
                    }
                } elseif ($url -match "cloudflare") {
                    if ($response -match "ip=([0-9.]+)") {
                        $ip = $matches[1]
                        Write-Log "✓ Cloudflare 检测成功 - IP: $ip"
                    }
                } elseif ($url -match "ipleak") {
                    $data = $response | ConvertFrom-Json
                    if ($data.ip) {
                        Write-Log "✓ IP Leak 检测成功 - IP: $($data.ip)"
                    }
                }
            } else {
                Write-Log "✗ 无响应: $url" -Level "WARN"
            }
        } catch {
            Write-Log "✗ 测试失败: $url - $($_.Exception.Message)" -Level "ERROR"
        }
    }

    return $null
}

function Restart-UsqueService {
    Write-Log "正在重启 Usque 服务..." -Level "WARN"

    $nssmPath = "C:\迅雷下载\nssm-2.24-101-g897c7ad\win64\nssm.exe"

    try {
        & $nssmPath stop usque
        Start-Sleep -Seconds 5
        & $nssmPath start usque
        Write-Log "服务重启成功" -Level "INFO"
    } catch {
        Write-Log "服务重启失败: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Send-KeepAliveTraffic {
    # 发送保活流量，防止连接因无活动而断开
    Write-Log "发送保活流量..."

    try {
        $proxyUrl = "socks5://${Username}:${Password}@${ProxyHost}:${ProxyPort}"
        $null = curl -x $proxyUrl https://www.cloudflare.com/cdn-cgi/trace -s --max-time 10
        Write-Log "保活流量发送成功"
    } catch {
        Write-Log "保活流量发送失败: $($_.Exception.Message)" -Level "WARN"
    }
}

# 主循环
Write-Log "=== Usque 监控服务启动 ==="
Write-Log "测试间隔: $IntervalSeconds 秒"

$failureCount = 0
$maxFailures = 3

while ($true) {
    try {
        # 发送保活流量
        Send-KeepAliveTraffic

        # 测试连接
        $result = Test-ProxyConnection

        if ($result) {
            $failureCount = 0

            # 保存检测结果
            $statusFile = Join-Path $LogDir "status.json"
            @{
                LastCheck = Get-Date -Format "o"
                IP = $result.IP
                Country = $result.Country
                ISP = $result.ISP
                Status = "Connected"
            } | ConvertTo-Json -Depth 10 | Out-File -FilePath $statusFile -Encoding UTF8
        } else {
            $failureCount++
            Write-Log "连接测试失败 ($failureCount/$maxFailures)" -Level "WARN"

            if ($failureCount -ge $maxFailures) {
                Write-Log "连续失败次数达到阈值，重启服务" -Level "ERROR"
                Restart-UsqueService
                $failureCount = 0
                Start-Sleep -Seconds 30  # 重启后等待
            }
        }

    } catch {
        Write-Log "监控循环异常: $($_.Exception.Message)" -Level "ERROR"
    }

    # 等待下一次测试
    Start-Sleep -Seconds $IntervalSeconds
}
```

#### 2. 安装监控服务

创建 [install-monitor.ps1](install-monitor.ps1)：

```powershell
$NSSM_PATH = "C:\迅雷下载\nssm-2.24-101-g897c7ad\win64\nssm.exe"
$PROJECT_PATH = "C:\迅雷下载\warp-usque-windows-guide"

# 安装监控服务
& $NSSM_PATH install usque-monitor "pwsh.exe"
& $NSSM_PATH set usque-monitor AppParameters "-f keepalive-monitor.ps1"
& $NSSM_PATH set usque-monitor AppDirectory $PROJECT_PATH
& $NSSM_PATH set usque-monitor AppExit Default Restart
& $NSSM_PATH set usque-monitor AppStdout "$PROJECT_PATH\monitor-out.log"
& $NSSM_PATH set usque-monitor AppStderr "$PROJECT_PATH\monitor-err.log"
& $NSSM_PATH set usque-monitor AppTimestampLog 1
& $NSSM_PATH set usque-monitor Description "WARP Usque 监控与保活服务"
& $NSSM_PATH set usque-monitor DisplayName "WARP Usque Monitor"
& $NSSM_PATH set usque-monitor ObjectName LocalSystem
& $NSSM_PATH set usque-monitor Start SERVICE_AUTO_START
& $NSSM_PATH set usque-monitor Type SERVICE_WIN32_OWN_PROCESS

# 启动监控服务
& $NSSM_PATH start usque-monitor
```

#### 3. 监控日志分析

监控脚本会生成以下文件：

```
logs/
├── monitor-2026-02-28.log      # 每日监控日志
└── status.json                 # 当前连接状态
```

**status.json 示例：**

```json
{
  "LastCheck": "2026-02-28T14:30:00.0000000+08:00",
  "IP": "172.16.0.2",
  "Country": "United States",
  "ISP": "Cloudflare Inc.",
  "Status": "Connected"
}
```

---

## 常见问题排查

### 1. 连接超时

**症状：**

```
Failed to connect tunnel: timeout: handshake did not complete in time
```

**解决方案：**

1. 检查网络连接
2. 尝试切换 DNS 服务器
3. 检查防火墙设置
4. 切换 IPv4/IPv6 端点

### 2. 无活动断开

**症状：**

```
timeout: no recent network activity
```

**解决方案：**

- 部署监控脚本发送保活流量
- 降低测试间隔时间
- 设置客户端 keep-alive

### 3. 网络不可达

**症状：**

```
A socket operation was attempted to an unreachable network
```

**解决方案：**

- 检查网络适配器状态
- 重启网络服务
- 检查路由表配置

### 4. Martian Packet 警告

**症状：**

```
Martian packet dropped with loopback source address
```

**说明：** 这是正常现象，可以忽略。usque
的网络栈会丢弃某些回环地址的数据包作为安全措施。

### 5. 服务无法启动

**检查清单：**

```powershell
# 1. 检查 PowerShell 路径
where.exe pwsh.exe

# 2. 检查脚本路径
Test-Path "C:\迅雷下载\warp-usque-windows-guide\start.ps1"

# 3. 检查执行策略
Get-ExecutionPolicy

# 4. 如需要，修改执行策略
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 性能优化建议

### 1. DNS 优化

使用快速的 DNS 服务器可以显著提升响应速度：

```powershell
# 推荐的 DNS 组合
-d 1.1.1.1          # Cloudflare (最快)
-d 8.8.8.8          # Google
-d 9.9.9.9          # Quad9 (注重隐私)
-d 94.140.14.14     # AdGuard (广告拦截)
```

### 2. UDP 缓冲区调整

虽然 Windows 不像 Linux 需要手动调整，但可以通过注册表优化：

```powershell
# 以管理员身份运行
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Afd\Parameters" `
    -Name "DefaultSendWindow" `
    -Value 65536 `
    -PropertyType DWord `
    -Force

New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Afd\Parameters" `
    -Name "DefaultReceiveWindow" `
    -Value 65536 `
    -PropertyType DWord `
    -Force
```

### 3. 网络适配器设置

1. 关闭不必要的网络功能
   - Large Send Offload (LSO)
   - TCP Chimney Offload

2. 启用高级功能
   - Jumbo Frames (如果网络支持)

---

## 进阶配置

### 1. Zero Trust 集成

对于企业用户，可以集成 Cloudflare Zero Trust：

```powershell
# 获取 Zero Trust JWT
# 访问: https://<your-team-domain>.cloudflareaccess.com/warp

# 注册设备
.\usque.exe register --jwt "your-zero-trust-jwt"

# 启动时使用 Zero Trust SNI
.\usque.exe socks -s zt-masque.cloudflareclient.com
```

### 2. 端口转发模式

实现 WARP to WARP 设备间通信：

```powershell
# 转发本地端口到 WARP 网络
.\usque.exe portfw -R 100.96.0.3:8080:localhost:8080

# 转发 WARP 网络端口到本地
.\usque.exe portfw -L localhost:8081:100.96.0.2:8081
```

### 3. HTTP 代理模式

对于不支持 SOCKS5 的应用：

```powershell
.\usque.exe http-proxy -b 0.0.0.0 -p 8000 `
    --username "user" --password "pass"
```

### 4. 多实例部署

运行多个 usque 实例，使用不同的配置文件：

```powershell
# 实例 1
.\usque.exe -c config1.json socks -p 1080

# 实例 2
.\usque.exe -c config2.json socks -p 1081
```

---

## 监控面板 (可选)

创建一个简单的监控 Web 面板 [dashboard.ps1](dashboard.ps1)：

```powershell
<#
.SYNOPSIS
    Usque 监控 Web 面板
#>

$StatusFile = ".\logs\status.json"
$LogFile = Get-ChildItem ".\logs\monitor-*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>WARP Usque 监控面板</title>
    <meta http-equiv="refresh" content="30">
    <style>
        body { font-family: 'Microsoft YaHei', sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #f38020; padding-bottom: 10px; }
        .status { padding: 15px; margin: 10px 0; border-radius: 4px; }
        .status.connected { background: #d4edda; color: #155724; }
        .status.disconnected { background: #f8d7da; color: #721c24; }
        .info { margin: 10px 0; }
        .label { font-weight: bold; color: #666; }
        .value { margin-left: 10px; }
        .logs { background: #f8f9fa; padding: 15px; border-radius: 4px; max-height: 400px; overflow-y: auto; font-family: monospace; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 WARP Usque 监控面板</h1>
        <div id="status"></div>
        <div id="logs"></div>
    </div>
    <script>
        // 加载状态
        fetch('logs/status.json')
            .then(r => r.json())
            .then(data => {
                const statusDiv = document.getElementById('status');
                const isConnected = data.Status === 'Connected';
                statusDiv.innerHTML = `
                    <div class="status ${isConnected ? 'connected' : 'disconnected'}">
                        <div class="info"><span class="label">状态:</span><span class="value">${data.Status}</span></div>
                        <div class="info"><span class="label">IP:</span><span class="value">${data.IP || 'N/A'}</span></div>
                        <div class="info"><span class="label">国家:</span><span class="value">${data.Country || 'N/A'}</span></div>
                        <div class="info"><span class="label">ISP:</span><span class="value">${data.ISP || 'N/A'}</span></div>
                        <div class="info"><span class="label">最后检查:</span><span class="value">${data.LastCheck}</span></div>
                    </div>
                `;
            });

        // 加载日志
        fetch('logs/$(Split-Path $LogFile.Name -Leaf)')
            .then(r => r.text())
            .then(data => {
                document.getElementById('logs').innerHTML = '<h3>最近日志</h3><div class="logs">' + data + '</div>';
            });
    </script>
</body>
</html>
"@

$html | Out-File -FilePath ".\dashboard.html" -Encoding UTF8
Start-Process ".\dashboard.html"
```

---

## 总结

通过本指南，您应该能够：

✅ 在 Windows 上成功部署 usque ✅ 实现开机自启动和自动重启 ✅
配置连接监控和保活机制 ✅ 定期检测网络归属地 ✅ 排查和解决常见问题

### 关键要点

1. **使用 NSSM 管理服务**：确保服务稳定运行和自动重启
2. **部署监控脚本**：定期测试连接并发送保活流量
3. **查看日志文件**：及时发现问题并进行排查
4. **优化 DNS 和网络设置**：提升性能和稳定性

### 相关资源

- [Usque GitHub 仓库](https://github.com/Diniboy1123/usque)
- [Cloudflare WARP](https://1.1.1.1/)
- [RFC 9484 - Connect-IP](https://datatracker.ietf.org/doc/rfc9484/)
- [NSSM 文档](https://nssm.cc/)

---

**许可证：** 本指南基于 usque 项目，遵循相同的开源许可证。

**免责声明：**
本工具仅供学习和研究使用。请遵守当地法律法规和服务条款。作者不对任何滥用或后果负责。

---

_最后更新：2026-02-28_
