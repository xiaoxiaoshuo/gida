# DNS Fix Script - 解决VPN DNS污染/超时问题
# 运行方式: 以管理员身份运行此脚本

param(
    [string[]]$DnsServers = @("8.8.8.8", "1.1.1.1"),
    [string]$InterfaceAlias = "WLAN"
)

$ErrorActionPreference = "Stop"

Write-Host "=== DNS修复脚本 ===" -ForegroundColor Cyan
Write-Host "当前DNS配置:" -ForegroundColor Yellow

# 获取当前DNS配置
$adapter = Get-NetAdapter -InterfaceAlias $InterfaceAlias -ErrorAction SilentlyContinue
if (-not $adapter) {
    Write-Host "错误: 找不到接口 '$InterfaceAlias'" -ForegroundColor Red
    Write-Host "可用接口:" -ForegroundColor Yellow
    Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object Name, Status | Format-Table -AutoSize
    exit 1
}

$currentDns = Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses
Write-Host "  接口: $InterfaceAlias" -ForegroundColor White
Write-Host "  当前DNS: $($currentDns -join ', ')" -ForegroundColor White

# 备份当前配置
$backupFile = "$env:TEMP\dns_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$currentDns | Out-File -FilePath $backupFile -Encoding UTF8
Write-Host "  备份已保存: $backupFile" -ForegroundColor Green

# 设置新DNS
Write-Host ""
Write-Host "正在设置DNS为: $($DnsServers -join ', ')" -ForegroundColor Yellow
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DnsServers

# 验证
$newDns = Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses
Write-Host ""
Write-Host "=== 验证结果 ===" -ForegroundColor Cyan
Write-Host "  新DNS: $($newDns -join ', ')" -ForegroundColor White

# 测试连通性
Write-Host ""
Write-Host "=== 连通性测试 ===" -ForegroundColor Cyan
$testHosts = @("google.com", "api.binance.com", "www.bing.com")
foreach ($host in $testHosts) {
    try {
        $resolve = Resolve-DnsName -Name $host -Server $DnsServers[0] -Type A -QuickTimeout -ErrorAction Stop
        $ip = $resolve | Where-Object { $_.Type -eq "A" } | Select-Object -First 1 -ExpandProperty IPAddress
        Write-Host "  [OK] $host -> $ip" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] $host - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "如需恢复备份，请运行:" -ForegroundColor Yellow
Write-Host "  Set-DnsClientServerAddress -InterfaceAlias '$InterfaceAlias' -ServerAddresses (Get-Content '$backupFile')" -ForegroundColor White
