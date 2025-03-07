@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Remove-Module *; $ErrorActionPreference = 'Stop'; & '%~dp0newpc.ps1'"
