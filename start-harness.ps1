# DeepSeek Harness 启动器 v5
# 项目: DeepSeek Harness 桌面快捷方式 | 许可证: MIT (见 LICENSE)
# 流程：控制台窗口正常显示在桌面 -> 运行 npx @deepseek-ai/dsh web（输出直通控制台）
#       -> 主线程轮询端口 3080，服务就绪（浏览器打开之前）自动把窗口缩回任务栏
# 已在运行时的再次双击：切换到已有浏览器窗口（不新开任何窗口/标签页）
# 兼容两种控制台宿主：
#   经典 conhost：GetConsoleWindow() 即真实窗口，直接最小化
#   Windows Terminal(ConPTY)：GetConsoleWindow() 返回伪窗口(PseudoConsoleWindow)，
#     必须隐藏伪窗口、按类名+标题找到真实 CASCADIA 窗口再最小化，否则会出现左下角白块
# 防护：若启动前端口已被占用（已有 Harness 在运行），不做自动最小化，保留窗口显示报错
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 窗口操作（P/Invoke）
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class WinMin3 {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hWnd, StringBuilder sb, int max);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    public static string ClassOf(IntPtr h) {
        var c = new StringBuilder(256);
        GetClassName(h, c, 256);
        return c.ToString();
    }
    static string Needle = "";
    static IntPtr Found = IntPtr.Zero;
    public static IntPtr FindHostWindow(string needle) {
        Needle = needle; Found = IntPtr.Zero;
        EnumWindows((h, l) => {
            var c = new StringBuilder(256);
            GetClassName(h, c, 256);
            string cls = c.ToString();
            if (cls != "CASCADIA_HOSTING_WINDOW_CLASS" && cls != "ConsoleWindowClass") return true;
            var t = new StringBuilder(256);
            GetWindowText(h, t, 256);
            if (t.ToString().Contains(Needle)) {
                RECT r; GetWindowRect(h, out r);
                if ((r.Right - r.Left) > 100 && (r.Bottom - r.Top) > 60) { Found = h; return false; }
            }
            return true;
        }, IntPtr.Zero);
        return Found;
    }
    public static bool Hide(IntPtr h) { return ShowWindow(h, 0); }
    public static bool Min(IntPtr h) { return ShowWindow(h, 6); }
    public static bool Restore(IntPtr h) { return ShowWindow(h, 9); }
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);
    public static bool Foreground(IntPtr h) { return SetForegroundWindow(h); }
    public static IntPtr FindBrowserWindow(string needle) {
        Needle = needle; Found = IntPtr.Zero;
        EnumWindows((h, l) => {
            var c = new StringBuilder(256);
            GetClassName(h, c, 256);
            string cls = c.ToString();
            if (cls != "Chrome_WidgetWin_1" && cls != "MozillaWindowClass") return true;
            var t = new StringBuilder(256);
            GetWindowText(h, t, 256);
            if (t.ToString().Contains(Needle)) { Found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return Found;
    }
}
"@

# 设置窗口标题（也用于按标题定位真实终端窗口）
try { $Host.UI.RawUI.WindowTitle = 'DeepSeek Harness' } catch {}

function Minimize-HarnessWindow {
    $own = [WinMin3]::GetConsoleWindow()
    $cls = [WinMin3]::ClassOf($own)
    if ($cls -eq 'PseudoConsoleWindow') {
        # ConPTY（Windows Terminal 等）：先隐藏伪窗口，防止出现左下角白块
        [WinMin3]::Hide($own) | Out-Null
        $real = [WinMin3]::FindHostWindow('DeepSeek Harness')
        if ($real -ne [IntPtr]::Zero) {
            [WinMin3]::Min($real) | Out-Null
        }
    } elseif ($own -ne [IntPtr]::Zero) {
        # 经典 conhost：直接最小化真实控制台窗口
        [WinMin3]::Min($own) | Out-Null
    }
}

function Test-PortOpen {
    param([int]$P)
    $c = [System.Net.Sockets.TcpClient]::new()
    try {
        $c.Connect('127.0.0.1', $P)
        return $true
    } catch {
        return $false
    } finally {
        $c.Close()
    }
}

# 判断端口上运行的是否为 Harness（返回的网页含 DSH_BOOT / DeepSeek 标记）
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

$port = 3080   # DSH Web GUI 默认端口（dsh-web-app: port ?? 3080）

# 定位 npx（优先 npx.cmd）
$npx = $null
try { $npx = (Get-Command npx.cmd -ErrorAction Stop).Source } catch {
    try { $npx = (Get-Command npx -ErrorAction Stop).Source } catch {}
}
if (-not $npx) {
    Write-Host '错误：找不到 npx，请确认 Node.js 已安装并加入 PATH。' -ForegroundColor Red
    # 弹窗引导下载 Node.js
    try {
        $wsPopup = New-Object -ComObject WScript.Shell
        $r = $wsPopup.Popup('检测到电脑没有安装 Node.js，DeepSeek Harness 需要它才能运行。' + "`r`n`r`n" + '是否现在打开下载页面？', 0, '缺少 Node.js', 4 + 48)
        if ($r -eq 6) { Start-Process 'https://nodejs.org' }
    } catch {}
    return
}

# 启动前检查：端口已被占用时，先确认是否已有 Harness 在运行
$portAlreadyOpen = Test-PortOpen -P $port
if ($portAlreadyOpen) {
    # 防止连续点击堆叠多个控制台窗口（短互斥，处理完即释放）
    $createdNew = $false
    $reclickMutex = [System.Threading.Mutex]::new($true, 'DeepSeekHarnessReclick', [ref]$createdNew)
    if (-not $createdNew) {
        if (-not $reclickMutex.WaitOne(0)) { exit }   # 已有一次点击正在处理中，直接退出
    }
    Write-Host ''
    Write-Host '检测到端口 3080 已被占用，正在确认是否已有 Harness 在运行...' -ForegroundColor Yellow
    if (Test-HarnessOnPort -P $port) {
        $bw = [WinMin3]::FindBrowserWindow('DeepSeek Harness')
        if ($bw -ne [IntPtr]::Zero) {
            Write-Host 'Harness 已在运行，正在切换到浏览器窗口（不新开窗口）...' -ForegroundColor Green
            if ([WinMin3]::IsIconic($bw)) { [WinMin3]::Restore($bw) | Out-Null }   # 仅最小化时恢复，避免把最大化窗口缩小
            [WinMin3]::Foreground($bw) | Out-Null
            Start-Sleep -Seconds 1
        } else {
            Write-Host 'Harness 已在运行，正在为你打开网页 http://127.0.0.1:3080 ...' -ForegroundColor Green
            Start-Process 'http://127.0.0.1:3080'
            Start-Sleep -Seconds 2
        }
        exit
    } else {
        Write-Host '端口 3080 被其他程序占用，Harness 无法启动。' -ForegroundColor Red
        Write-Host '请关闭占用该端口的程序后，重新双击快捷方式。' -ForegroundColor Red
        Write-Host ''
        try {
            Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop | ForEach-Object {
                $p = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
                if ($p) { Write-Host ('  占用端口的进程: ' + $p.ProcessName + ' (PID ' + $p.Id + ')') }
            }
        } catch {}
        return   # 保持窗口打开，方便查看
    }
}

# 单实例保护由隐藏调度器 dispatcher.ps1 负责（本脚本由它启动）

Write-Host ''
Write-Host 'DeepSeek Harness 启动中...（浏览器打开前窗口会自动缩回任务栏）' -ForegroundColor Cyan
Write-Host ''

# 在同一个控制台里运行 npx（-NoNewWindow，输出直通显示），主线程轮询端口
$proc = Start-Process -FilePath $env:ComSpec -ArgumentList '/c', 'echo ^> npx -y @deepseek-ai/dsh web & npx -y @deepseek-ai/dsh web' -NoNewWindow -PassThru

$minimized = $false
while (-not $proc.HasExited) {
    if (-not $minimized -and -not $portAlreadyOpen -and (Test-PortOpen -P $port)) {
        Minimize-HarnessWindow
        $minimized = $true
    }
    Start-Sleep -Milliseconds 300
}

if (-not $minimized) {
    Write-Host ''
    Write-Host 'Harness 进程已退出（端口未就绪）。窗口保持打开，便于查看上方日志。' -ForegroundColor Yellow
}
