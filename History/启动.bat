@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "compare.ps1"
pause