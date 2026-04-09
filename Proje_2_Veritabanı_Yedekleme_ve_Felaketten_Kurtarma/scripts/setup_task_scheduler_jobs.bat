@echo off
setlocal enableextensions

REM Run this file once as Administrator to create daily backup tasks.
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"

schtasks /Create /TN "BLM4522_Daily_Logical_Backup" /TR "\"%PROJECT_ROOT%\scripts\run_daily_logical_backup_with_alert.bat\"" /SC DAILY /ST 01:00 /F
schtasks /Create /TN "BLM4522_Weekly_Physical_Backup" /TR "\"%PROJECT_ROOT%\scripts\backup_full_physical_pg_basebackup.bat\"" /SC WEEKLY /D SUN /ST 02:00 /F

if errorlevel 1 (
  echo [ERROR] Task creation failed. Run as Administrator.
  exit /b 1
)

echo [OK] Task Scheduler jobs created.
schtasks /Query /TN "BLM4522_Daily_Logical_Backup"
schtasks /Query /TN "BLM4522_Weekly_Physical_Backup"
exit /b 0
