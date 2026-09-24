@echo off
powershell.exe -NoProfile -File "%~dp0Open-Godot.ps1" -Run
if errorlevel 1 pause
