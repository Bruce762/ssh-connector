@echo off
REM Windows 雙擊啟動器 → 用 Git Bash 的 bash.exe 執行 ssh_client.sh
REM 需先安裝 Git for Windows: https://git-scm.com/download/win
set SCRIPT=ssh_client.sh

REM 切到根目錄（本檔在 windows\ 子資料夾內）
cd /d "%~dp0.."

where bash >nul 2>nul
if %errorlevel%==0 (
    bash "%SCRIPT%"
    goto end
)
if exist "%ProgramFiles%\Git\bin\bash.exe" (
    "%ProgramFiles%\Git\bin\bash.exe" "%SCRIPT%"
    goto end
)
if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (
    "%ProgramFiles(x86)%\Git\bin\bash.exe" "%SCRIPT%"
    goto end
)
echo.
echo [X] 找不到 bash，請先安裝 Git for Windows: https://git-scm.com/download/win

:end
echo.
echo （按任意鍵關閉視窗）
pause >nul
