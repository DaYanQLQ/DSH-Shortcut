# DeepSeek Harness 调度器（以隐藏窗口运行，桌面上不会出现任何终端窗口）
# 项目: DeepSeek Harness 桌面快捷方式 | 许可证: MIT (见 LICENSE)
# 逻辑：
#   Harness 已在运行       -> 把已有的浏览器窗口带到前台，然后静默退出（不弹任何窗口）
#   端口被其他程序占用      -> 打开可见终端显示占用提示（交给 start-harness 处理）
#   端口空闲               -> 以可见终端启动 Harness，并在服务就绪前阻止重复启动
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 窗口操作（P/Invoke）
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class WinMinD {
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hWnd, StringBuilder sb, int max);
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    static string Needle = "";
    static IntPtr Found = IntPtr.Zero;
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
    public static bool Restore(IntPtr h) { return ShowWindow(h, 9); }
    public static bool Foreground(IntPtr h) { return SetForegroundWindow(h); }
    [DllImport("user32.dll")] static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    public static void ForceForeground(IntPtr h) {
        ShowWindow(h, 9);
        keybd_event(0x12, 0, 0, UIntPtr.Zero);            // 按下 ALT（借用前台权限）
        SetForegroundWindow(h);
        keybd_event(0x12, 0, 2, UIntPtr.Zero);            // 松开 ALT
    }
    public static bool Min(IntPtr h) { return ShowWindow(h, 6); }
    public static string ListConsoleWindows() {
        var sb = new StringBuilder();
        EnumWindows((h, l) => {
            var c = new StringBuilder(256);
            GetClassName(h, c, 256);
            string cls = c.ToString();
            if (cls != "ConsoleWindowClass" && cls != "CASCADIA_HOSTING_WINDOW_CLASS") return true;
            var t = new StringBuilder(256);
            GetWindowText(h, t, 256);
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            sb.Append(h + "|" + pid + "|" + t + "\n");
            return true;
        }, IntPtr.Zero);
        return sb.ToString();
    }
}
"@

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

# 判断某进程（或它的最近几代祖先）是否属于 Harness 启动器链：
# 沿进程树向上查找命令行含 start-harness / npx dsh 的进程
function Test-HarnessConsoleProcess {
    param([int]$Pid)
    $cur = $Pid
    for ($i = 0; $i -lt 4 -and $cur -gt 0; $i++) {
        $proc = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $cur) -ErrorAction SilentlyContinue
        if (-not $proc) { return $false }
        if ($proc.CommandLine -match 'start-harness\.ps1|npx -y @deepseek-ai/dsh') { return $true }
        $cur = $proc.ParentProcessId
    }
    return $false
}

$port = 3080   # DSH Web GUI 默认端口
$launcher = Join-Path $PSScriptRoot 'start-harness.ps1'

function Start-VisibleHarness {
    Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\conhost.exe') -ArgumentList @(
        (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'),
        '-NoExit', '-NoLogo', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $launcher + '"')
    ) | Out-Null
}

# 1. 端口已开
if (Test-PortOpen -P $port) {
    if (Test-HarnessOnPort -P $port) {
        # Harness 已在运行：优先把已有浏览器窗口带到前台；
        # 若浏览器已关闭（找不到窗口），则直接打开网页
        $bw = [WinMinD]::FindBrowserWindow('DeepSeek Harness')
        if ($bw -ne [IntPtr]::Zero) {
            [WinMinD]::ForceForeground($bw) | Out-Null
        } else {
            Start-Process 'http://127.0.0.1:3080'
            Start-Sleep -Milliseconds 800
        }
        # 把 Harness 的终端窗口收回任务栏（用户可能之前手动把它恢复到了桌面）
        $consoles = ([WinMinD]::ListConsoleWindows() -split "`n") | Where-Object { $_ -ne '' }
        foreach ($line in $consoles) {
            $parts = $line -split '\|', 3
            if ($parts.Count -lt 3) { continue }
            $hwnd  = [IntPtr][long]$parts[0]
            $wpid  = [int]$parts[1]
            $title = $parts[2]
            if (($title -match 'DeepSeek Harness') -or (Test-HarnessConsoleProcess -Pid $wpid)) {
                [WinMinD]::Min($hwnd) | Out-Null
            }
        }
        exit
    } else {
        # 端口被其他程序占用：打开可见终端显示占用提示
        Start-VisibleHarness
        exit
    }
}

# 2. 端口空闲：单实例保护后，以可见终端启动 Harness
$createdNew = $false
$bootMutex = [System.Threading.Mutex]::new($true, 'DeepSeekHarnessBoot', [ref]$createdNew)
if (-not $createdNew) {
    if (-not $bootMutex.WaitOne(0)) { exit }   # 已有一次启动正在进行，静默退出
}
Start-VisibleHarness

# 等服务就绪（或超时）后释放启动锁，防止启动期间重复双击导致重复启动
# 首次运行 npx 需要下载 dsh，可能较慢，预留 5 分钟
$deadline = (Get-Date).AddSeconds(300)
while ((Get-Date) -lt $deadline) {
    if (Test-PortOpen -P $port) { break }
    Start-Sleep -Milliseconds 500
}
try { $bootMutex.ReleaseMutex() } catch {}
