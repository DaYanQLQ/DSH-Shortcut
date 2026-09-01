@echo off
REM DeepSeek Harness desktop shortcut - one-click installer (ASCII stub)
REM MIT License. See LICENSE. This batch only unblocks and launches install.ps1.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -Recurse -Include *.ps1,*.vbs | Unblock-File" >nul 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
