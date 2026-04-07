# Usque 服务重启脚本
# 功能: 停止服务 -> 删除日志 -> 启动服务

# 服务列表（按启动顺序）
$services = @("usque-3", "usque-2", "usque-1", "usque", "warp-monitor")

# NSSM 路径
$nssmPath = "C:\迅雷下载\nssm-2.24-101-g897c7ad\win64\nssm.exe"

# 检查 NSSM 是否存在
if (-not (Test-Path $nssmPath)) {
    Write-Error "NSSM 未找到，请检查路径: $nssmPath"
    exit 1
}

Write-Host "=== Usque 服务重启 ===" -ForegroundColor Cyan

# 第一步：停止服务（按相反顺序）
Write-Host "`n步骤 1/3: 停止服务..." -ForegroundColor Yellow
[array]::Reverse($services)
foreach ($service in $services) {
    Write-Host "  停止 $service..." -NoNewline
    & $nssmPath stop $service 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " 成功" -ForegroundColor Green
    } else {
        Write-Host " 未运行或失败" -ForegroundColor Gray
    }
}
[array]::Reverse($services)  # 恢复原始顺序

# 第二步：删除日志文件
Write-Host "`n步骤 2/3: 清理日志文件..." -ForegroundColor Yellow
$logFiles = Get-ChildItem -Path "." -Filter "*.log" -File
if ($logFiles.Count -gt 0) {
    foreach ($logFile in $logFiles) {
        Write-Host "  删除 $($logFile.Name)..." -NoNewline
        try {
            Remove-Item $logFile.FullName -Force
            Write-Host " 成功" -ForegroundColor Green
        } catch {
            Write-Host " 失败: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  没有找到日志文件" -ForegroundColor Gray
}

# 第三步：启动服务
Write-Host "`n步骤 3/3: 启动服务..." -ForegroundColor Yellow
foreach ($service in $services) {
    Write-Host "  启动 $service..." -NoNewline
    & $nssmPath start $service 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " 成功" -ForegroundColor Green
    } else {
        Write-Host " 失败 (退出码: $LASTEXITCODE)" -ForegroundColor Red
    }
}

Write-Host "`n=== 重启完成 ===" -ForegroundColor Cyan
