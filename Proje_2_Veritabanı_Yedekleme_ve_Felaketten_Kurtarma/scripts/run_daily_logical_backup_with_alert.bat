@echo off
setlocal enableextensions enabledelayedexpansion

REM Wrapper: logical backup + basic alert flag
set "SCRIPT_DIR=%~dp0"
set "LOG_ROOT=D:\BLM4522\backups\logs"

if not exist "%LOG_ROOT%" mkdir "%LOG_ROOT%"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set TS=%%i
set "WRAP_LOG=%LOG_ROOT%\daily_wrapper_%TS%.log"

call "%SCRIPT_DIR%backup_full_logical_pg_dump.bat" > "%WRAP_LOG%" 2>&1
if errorlevel 1 (
  echo [CRITICAL] Daily logical backup failed at %date% %time%>> "%LOG_ROOT%\alerts.log"
  echo [CRITICAL] Check wrapper log: %WRAP_LOG%
  exit /b 1
)

echo [INFO] Daily logical backup success at %date% %time%>> "%LOG_ROOT%\alerts.log"
echo [OK] Wrapper completed: %WRAP_LOG%
exit /b 0
