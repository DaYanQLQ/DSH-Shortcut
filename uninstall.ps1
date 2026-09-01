# 卸载 DeepSeek Harness 桌面快捷方式
# 项目: DeepSeek Harness 桌面快捷方式 | 许可证: MIT (见 LICENSE)
# 用法：powershell -ExecutionPolicy Bypass -File uninstall.ps1 [-Path "D:\DeepSeek"]
# 参数：-Path 与安装时相同的目录（默认 %LOCALAPPDATA%\DeepSeek）
param(
    [string]$Path = ''
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop 'DeepSeek Harness.lnk'
if (Test-Path -LiteralPath $lnkPath) {
    Remove-Item -LiteralPath $lnkPath -Force
    Write-Host ('已删除快捷方式: ' + $lnkPath)
} else {
    Write-Host '未找到快捷方式，可能已经卸载。'
}

$iconDir = if ($Path -ne '') { [System.IO.Path]::GetFullPath($Path.TrimEnd('\')) } else { Join-Path $env:LOCALAPPDATA 'DeepSeek' }
if (Test-Path -LiteralPath $iconDir) {
    Remove-Item -LiteralPath $iconDir -Recurse -Force
    Write-Host ('已删除安装目录: ' + $iconDir)
}
