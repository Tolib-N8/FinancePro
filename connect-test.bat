@echo off
REM ============================================================
REM  FinancePro LAN connectivity test for Windows
REM
REM  How to use:
REM    1. Скопируй этот файл на Windows ноут (любая папка)
REM    2. Двойной клик ИЛИ открой cmd и запусти:  connect-test.bat
REM    3. Покажи мне всё, что вывелось
REM ============================================================

setlocal
set SERVER=192.168.1.42
set PORT=8000

echo.
echo === FinancePro LAN connectivity test ===
echo Server: %SERVER%:%PORT%
echo.

echo --- [1/4] Network reachability (ping) ---
ping -n 2 %SERVER%
echo.

echo --- [2/4] HTTP root endpoint ---
curl -s -o "%TEMP%\fp_root.txt" -w "HTTP status: %%{http_code}  (time: %%{time_total}s)" --max-time 5 http://%SERVER%:%PORT%/
echo.
type "%TEMP%\fp_root.txt" 2>NUL
echo.
echo.

echo --- [3/4] Health endpoint ---
curl -s -o "%TEMP%\fp_health.txt" -w "HTTP status: %%{http_code}" --max-time 5 http://%SERVER%:%PORT%/healthz
echo.
type "%TEMP%\fp_health.txt" 2>NUL
echo.
echo.

echo --- [4/4] What network is this Windows machine on ---
ipconfig | findstr /R /C:"IPv4" /C:"SSID"

echo.
echo === Done. Скинь весь этот вывод обратно ===
echo.
pause
