# 渲染 DeepSeek 官方图标：品牌蓝(#4D6BFE)圆角方块 + 白色官方鲸鱼，四角透明圆角
# 矢量数据来源：@deepseek-ai/dsh 官方 Web 前端自带的 favicon.svg（Logo 版权归 DeepSeek 所有）
# 项目: DeepSeek Harness 桌面快捷方式 | 许可证: MIT (见 LICENSE)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing

$assetDir = Join-Path $PSScriptRoot 'assets'
$svgPath  = Join-Path $assetDir 'deepseek-logo.svg'
$pngPath  = Join-Path $assetDir 'deepseek-logo-256.png'
$icoPath  = Join-Path $assetDir 'deepseek.ico'

$svg = [System.IO.File]::ReadAllText($svgPath)
$d = ([regex]::Match($svg, '<path\b[^>]*\bd="([^"]*)"', 'Singleline')).Groups[1].Value
if (-not $d) { throw '无法从 SVG 提取路径数据' }

# 令牌化：命令字母 M/Z 与数字（支持负号、小数）
$tokens = @([regex]::Matches($d, '[MZ]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?') | ForEach-Object { $_.Value })

# 解析鲸鱼路径：M 后跟起点；每个 C 提供 3 个点（控制点1、控制点2、终点）
$gp  = New-Object System.Drawing.Drawing2D.GraphicsPath
$cur = [System.Drawing.PointF]::new(0, 0)
$cmd = ''
$i   = 0
while ($i -lt $tokens.Count) {
    $t = $tokens[$i]
    if ($t -eq 'M' -or $t -eq 'Z') {
        $cmd = $t; $i++
        if ($t -eq 'Z') { $gp.CloseFigure() }
        continue
    }
    $x = [float]$tokens[$i]; $y = [float]$tokens[$i+1]; $i += 2
    if ($cmd -eq 'M') {
        $cur = [System.Drawing.PointF]::new($x, $y)
        $cmd = 'C'   # 本路径 M 仅出现一次，后续均为 C 段
    }
    elseif ($cmd -eq 'C') {
        $x2 = [float]$tokens[$i];   $y2 = [float]$tokens[$i+1]; $i += 2
        $x3 = [float]$tokens[$i];   $y3 = [float]$tokens[$i+1]; $i += 2
        $gp.AddBezier($cur,
            [System.Drawing.PointF]::new($x, $y),
            [System.Drawing.PointF]::new($x2, $y2),
            [System.Drawing.PointF]::new($x3, $y3))
        $cur = [System.Drawing.PointF]::new($x3, $y3)
    }
}
if ($gp.PointCount -lt 4) { throw '鲸鱼路径为空，渲染失败' }

# 缩放鲸鱼：宽度为画布 62%，水平垂直居中
$size  = 256
$bb    = $gp.GetBounds()
$scale = ($size * 0.62) / $bb.Width
$offX  = ($size - $bb.Width  * $scale) / 2 - $bb.X * $scale
$offY  = ($size - $bb.Height * $scale) / 2 - $bb.Y * $scale
$m = [System.Drawing.Drawing2D.Matrix]::new([float]$scale, 0, 0, [float]$scale, [float]$offX, [float]$offY)
$gp.Transform($m)

# 圆角方块路径（圆角半径 57 ≈ 22%，iOS App 图标风格）
$rect = New-Object System.Drawing.Drawing2D.GraphicsPath
$r = 57
$rect.AddArc(0, 0, 2*$r, 2*$r, 180, 90)
$rect.AddArc($size - 2*$r, 0, 2*$r, 2*$r, 270, 90)
$rect.AddArc($size - 2*$r, $size - 2*$r, 2*$r, 2*$r, 0, 90)
$rect.AddArc(0, $size - 2*$r, 2*$r, 2*$r, 90, 90)
$rect.CloseFigure()

# 绘制：默认透明画布 -> 蓝色圆角底 -> 白色鲸鱼
$bmp = New-Object System.Drawing.Bitmap($size, $size)   # 32bpp ARGB，四角保持透明
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$blueBrush  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0x4D, 0x6B, 0xFE))
$whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$g.FillPath($blueBrush, $rect)     # 品牌蓝圆角底
$g.FillPath($whiteBrush, $gp)      # 官方白色鲸鱼
$g.Dispose(); $blueBrush.Dispose(); $whiteBrush.Dispose()

$tmpPng = Join-Path $assetDir '_tmp.png'
$bmp.Save($tmpPng, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = [System.IO.File]::ReadAllBytes($tmpPng)
Remove-Item $tmpPng -Force
[System.IO.File]::WriteAllBytes($pngPath, $pngBytes)
$bmp.Dispose(); $gp.Dispose(); $rect.Dispose()

# 组装 ICO：22 字节头 + PNG 数据（保留透明通道，圆角生效）
$ico = [byte[]]::new(22 + $pngBytes.Length)
$ico[2] = 1; $ico[4] = 1      # type=1 (icon), count=1
$ico[10] = 1; $ico[12] = 32   # planes=1, bitcount=32
$sizeBytes = [BitConverter]::GetBytes([int]$pngBytes.Length)
$offBytes  = [BitConverter]::GetBytes([int]22)
[Array]::Copy($sizeBytes, 0, $ico, 14, 4)
[Array]::Copy($offBytes,  0, $ico, 18, 4)
[Array]::Copy($pngBytes,  0, $ico, 22, $pngBytes.Length)
[System.IO.File]::WriteAllBytes($icoPath, $ico)

Write-Host ("PNG 已生成: " + $pngPath)
Write-Host ("ICO 已生成: " + $icoPath)
