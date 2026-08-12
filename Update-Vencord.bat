@echo off
setlocal

title Vencord Updater

echo.
echo ============================================================
echo                 VENCORD AUTO UPDATER
echo ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Vencord.ps1"

if errorlevel 1 (
    echo.
    echo ============================================================
    echo                       ERROR
    echo ============================================================
    echo.
    echo Vencord updater failed with an error.
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo                       DONE
echo ============================================================
echo.

pause
