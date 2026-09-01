# DeepSeek Harness 一键重装脚本（崩溃 / 启动异常救援用）
# 项目: DeepSeek Harness 桌面快捷方式 | 许可证: MIT (见 LICENSE)
# 流程：停止运行中的 Harness -> 清空 npx 程序缓存 -> 自动重新启动
# 参数：-Full 连整个 npx 缓存一起清空（更彻底的清理）
param(
    [switch]$Full
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$port = 3080
$installDir = $PSScriptRoot

function Test-PortOpen {
    param([int]$P)
    $c = [System.Net.Sockets.TcpClient]::new()
    try { $c.Connect('127.0.0.1', $P); return $true } catch { return $false } finally { $c.Close() }
}

function Test-HarnessOnPort {
    param([int]$P)
    try {
        $req = [System.Net.HttpWebRequest]::Create("http://127.0.0.1:$P/")
        $req.Timeout = 3000
        $resp = $req.GetResponse()
        $sr = [System.IO.StreamReader]::new($resp.GetResponseStream())
        $html = $sr.ReadToEnd()
        $sr.Close(); $resp.Close()
        return ($html -match 'DSH_BOOT' -or $html -match 'DeepSeek')
    } catch {
        return $false
    }
}

Write-Host ''
Write-Host '============================================' -ForegroundColor Cyan
Write-Host '  DeepSeek Harness 一键重装' -ForegroundColor Cyan
Write-Host '  （用于崩溃、启动异常等情况）' -ForegroundColor DarkGray
Write-Host '============================================' -ForegroundColor Cyan
Write-Host ''

# ① 停止运行中的 Harness
if (Test-PortOpen -P $port) {
    if (Test-HarnessOnPort -P $port) {
        try {
            $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop | Select-Object -First 1
            $owner = [int]$conn.OwningProcess
            Write-Host ('[1/3] 正在停止 Harness（PID ' + $owner + '）...') -ForegroundColor Yellow
            taskkill /PID $owner /T /F | Out-Null
            Start-Sleep -Seconds 2
            if (-not (Test-PortOpen -P $port)) { Write-Host '      已停止 ✓' -ForegroundColor Green }
            else { Write-Host '      端口仍被占用，请手动结束后重试' -ForegroundColor Red }
        } catch {
            Write-Host ('      停止失败: ' + $_.Exception.Message) -ForegroundColor Red
        }
    } else {
        Write-Host '[1/3] 端口 3080 被其他程序占用，为安全起见不停止它。' -ForegroundColor Red
        Write-Host '      请先关闭占用程序，再重新运行本脚本。'
        return
    }
} else {
    Write-Host '[1/3] Harness 未在运行，跳过停止。' -ForegroundColor DarkGray
}

# ② 清空程序缓存
Write-Host '[2/3] 清空程序缓存...' -ForegroundColor Yellow
$npxRoot = Join-Path $env:LOCALAPPDATA 'npm-cache\_npx'
if (Test-Path -LiteralPath $npxRoot) {
    if ($Full) {
        Remove-Item -LiteralPath $npxRoot -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host '      已清空整个 npx 缓存 ✓' -ForegroundColor Green
    } else {
        $targets = Get-ChildItem -LiteralPath $npxRoot -Recurse -Directory -Filter '@deepseek-ai' -ErrorAction SilentlyContinue
        $count = 0
        foreach ($t in $targets) {
            Remove-Item -LiteralPath $t.FullName -Recurse -Force -ErrorAction SilentlyContinue
            $count++
        }
        if ($count -gt 0) { Write-Host ('      已清除 ' + $count + ' 处 @deepseek-ai 程序缓存，下次启动自动下载最新版 ✓') -ForegroundColor Green }
        else { Write-Host '      未发现缓存（无需清理）' -ForegroundColor DarkGray }
    }
} else {
    Write-Host '      未找到 npx 缓存目录' -ForegroundColor DarkGray
}

# ③ 重新启动
Write-Host '[3/3] 重新启动 Harness...' -ForegroundColor Yellow
$vbs = Join-Path $installDir 'dispatcher.vbs'
if (Test-Path -LiteralPath $vbs) {
    Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\wscript.exe') -ArgumentList ('"' + $vbs + '"')
    Write-Host '      已启动（与双击快捷方式同款流程，窗口会自动缩回任务栏）✓' -ForegroundColor Green
} else {
    Write-Host '      未找到启动入口，请双击桌面 "DeepSeek Harness" 快捷方式启动。' -ForegroundColor Yellow
}

Write-Host ''
Write-Host '重装完成。首次启动需重新下载 dsh，可能需要一两分钟。' -ForegroundColor Cyan
