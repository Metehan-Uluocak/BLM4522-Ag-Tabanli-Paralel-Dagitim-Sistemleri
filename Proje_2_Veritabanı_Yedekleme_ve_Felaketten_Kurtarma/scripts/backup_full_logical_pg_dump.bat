@echo off
setlocal enableextensions enabledelayedexpansion

REM ==== User config ====
set PG_BIN=C:\Program Files\PostgreSQL\18\bin
set PGHOST=127.0.0.1
set PGPORT=5432
set PGUSER=postgres
set PGDATABASE=blm4522_dr
set BACKUP_ROOT=D:\BLM4522\backups\logical
set LOG_ROOT=D:\BLM4522\backups\logs

REM Optional: set PGPASSWORD before running this script if required.

if not exist "%BACKUP_ROOT%" mkdir "%BACKUP_ROOT%"
if not exist "%LOG_ROOT%" mkdir "%LOG_ROOT%"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set TS=%%i

set OUT_FILE=%BACKUP_ROOT%\%PGDATABASE%_%TS%.dump
set LOG_FILE=%LOG_ROOT%\pg_dump_%TS%.log

"%PG_BIN%\pg_dump.exe" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d %PGDATABASE% -F c -Z 9 -f "%OUT_FILE%" > "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo [ERROR] Logical backup failed. Check log: %LOG_FILE%
  exit /b 1
)

echo [OK] Logical backup created: %OUT_FILE%
echo [OK] Log file: %LOG_FILE%
exit /b 0
