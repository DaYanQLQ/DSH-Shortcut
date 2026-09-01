# dsh-shortcut

DeepSeek Harness（dsh web）的 Windows 桌面快捷方式工具：双击智能启动 / 唤起，浏览器打开前终端自动最小化到任务栏，圆角官方鲸鱼图标。纯 PowerShell 实现，零依赖、零收集。

> 作者：**DaYanQAQ** · License: MIT

## 功能

- 🖱️ **一键安装**：双击 `install.bat`，中文交互菜单（选盘、路径校验、缺 Node.js 弹窗引导下载）
- 🚀 **智能启动**：Harness 未运行 → 弹出终端自动启动；已在运行 → **零窗口**把浏览器页面带到前台（浏览器关了则自动重开网页）
- 🪟 **窗口自动管理**：服务就绪、浏览器打开前，终端自动最小化到任务栏；连续双击不会堆叠窗口
- 🎨 **圆角图标**：品牌蓝（#4D6BFE）圆角方块 + 官方白色鲸鱼，纯 .NET 渲染官方 SVG 为 ICO，零外部依赖
- 🛡️ **隐私干净**：全明文脚本，零上传、零日志、零收集
- 🗑️ **干净卸载**：一条命令删除快捷方式与安装目录

## 安装

环境要求：**Windows 10 / 11** + **Node.js**（`npx` 可用）。未安装 Node.js 时，安装器会弹窗引导下载。

1. **下载本项目**：仓库页点绿色 **Code** 按钮 → **Download ZIP**，解压到任意文件夹（或 `git clone https://github.com/DaYanQAQ/DSH-Shortcut.git`）
   > GitHub 网页上的文件列表只是源代码展示，不能在网页上直接运行
2. **双击解压出来的 `install.bat`** → 自动解除下载锁定并启动中文安装器
3. 按提示选择安装位置（C 盘 / D 盘 / 自定义），完成 ✅

**高级用法（手动 / 指定目录）**：

```powershell
powershell -ExecutionPolicy Bypass -File ".\install.ps1"                     # 交互式，同 install.bat
powershell -ExecutionPolicy Bypass -File ".\install.ps1" -Path "D:\DeepSeek" # 指定目录，跳过交互
```

卸载：

```powershell
powershell -ExecutionPolicy Bypass -File ".\uninstall.ps1" [-Path "D:\DeepSeek"]
```

## 使用

双击桌面的「DeepSeek Harness」快捷方式：

| 双击时 | 表现 |
| --- | --- |
| Harness 未运行 | 终端显示 → 运行 `npx -y @deepseek-ai/dsh web` → 浏览器打开前自动最小化 |
| Harness 已运行 | 不弹任何窗口，唤起已有浏览器页面（浏览器已关则重开网页） |
| 端口 3080 被占用 | 终端显示占用提示与进程名 |

首次运行 `npx` 会自动下载 `@deepseek-ai/dsh`（稍慢，之后很快）。

> 本工具只负责"启动与窗口体验"，不含 AI 能力。与 AI 聊天需自行在
> [platform.deepseek.com](https://platform.deepseek.com) 申请 API Key 并在 Harness 中配置；
> 没有 Key 时程序照常启动，只是 AI 不回复。

## 项目结构

```
├── install.bat / install.ps1     # 一键安装（中文交互、路径校验、图标缓存刷新）
├── uninstall.ps1                 # 卸载
├── dispatcher.ps1                # 隐藏调度器：已在运行零窗口唤起；未运行拉起可见终端
├── start-harness.ps1             # 可见启动器：运行 npx、轮询端口、浏览器打开前自动最小化
├── render-logo.ps1               # 图标渲染：官方 SVG → 圆角 PNG / ICO
├── assets/                       # 官方 Logo 矢量源与生成的圆角图标
├── LICENSE
└── README.md
```

## 常见问题

| 问题 | 处理 |
| --- | --- |
| 双击脚本被 Windows 拦截 | `install.bat` 已自动解除锁定（Unblock-File） |
| 提示缺少 Node.js | 弹窗点"是"打开官网下载，装完重试 |
| 桌面图标未变圆角 | 右键桌面 → 刷新；仍无效则重启资源管理器 |
| 双击快捷方式无反应 | 确认 Node.js 已装、Harness 终端在运行；端口占用时终端会给出提示 |

## 致谢

- 图标矢量取自 [@deepseek-ai/dsh](https://www.npmjs.com/package/@deepseek-ai/dsh) 官方 Web 前端（favicon.svg），版权归 DeepSeek 所有，仅本地非商业使用

## 相关项目

- [dsh-balance-mini](https://github.com/DaYanQAQ/dsh-balance-mini)：作者的另一款 dsh 插件——极简余额监视器

## License

[MIT](LICENSE) © 2026 DaYanQAQ
